import { randomUUID } from "node:crypto";
import WebSocket from "ws";
import {
  ErrorCodes,
  GodotMcpError,
} from "./errors.js";
import {
  type GodotRequest,
  type GodotResponse,
  isGodotErrorResponse,
} from "./protocol.js";
import { getGodotPort, getRequestTimeoutMs } from "./schemas.js";

export interface ConnectionStatus {
  connected: boolean;
  port: number;
  host: string;
  reconnectAttempts: number;
  lastConnectedAt: string | null;
  lastError: string | null;
  pendingRequests: number;
}

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

const DEFAULT_HOST = "127.0.0.1";
const MAX_RECONNECT_DELAY_MS = 30_000;

/**
 * Persistent WebSocket client for the Godot editor plugin bridge.
 * Assumption (Godot 4.4+): Godot plugin speaks plain JSON text frames over ws://.
 */
export class GodotClient {
  private ws: WebSocket | null = null;
  private readonly pending = new Map<string, PendingRequest>();
  private reconnectTimer: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private intentionallyClosed = false;
  private lastConnectedAt: Date | null = null;
  private lastError: string | null = null;
  private connectPromise: Promise<void> | null = null;

  readonly port: number;
  readonly host: string;
  readonly timeoutMs: number;

  constructor(options?: { port?: number; host?: string; timeoutMs?: number }) {
    this.port = options?.port ?? getGodotPort();
    this.host = options?.host ?? DEFAULT_HOST;
    this.timeoutMs = options?.timeoutMs ?? getRequestTimeoutMs();
  }

  get url(): string {
    return `ws://${this.host}:${this.port}`;
  }

  isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  getConnectionStatus(): ConnectionStatus {
    return {
      connected: this.isConnected(),
      port: this.port,
      host: this.host,
      reconnectAttempts: this.reconnectAttempts,
      lastConnectedAt: this.lastConnectedAt?.toISOString() ?? null,
      lastError: this.lastError,
      pendingRequests: this.pending.size,
    };
  }

  async start(): Promise<void> {
    this.intentionallyClosed = false;
    await this.ensureConnected();
  }

  async stop(): Promise<void> {
    this.intentionallyClosed = true;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.rejectAllPending(
      new GodotMcpError(ErrorCodes.GODOT_NOT_CONNECTED, "Godot client stopped."),
    );
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  async callTool(
    method: string,
    params: Record<string, unknown> = {},
  ): Promise<unknown> {
    await this.ensureConnected();

    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new GodotMcpError(
        ErrorCodes.GODOT_NOT_CONNECTED,
        "Godot editor plugin is not connected.",
        {
          suggestion:
            "Open Godot 4.4+, enable Project → Project Settings → Plugins → Godot MCP Personal, and confirm the editor Output shows the WebSocket server started.",
          details: this.getConnectionStatus() as unknown as Record<string, unknown>,
        },
      );
    }

    const id = randomUUID();
    const request: GodotRequest = { id, method, params };

    return new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(
          new GodotMcpError(
            ErrorCodes.TIMEOUT,
            `Timed out waiting for Godot response to '${method}' after ${this.timeoutMs}ms.`,
            {
              suggestion:
                "Check Godot editor is responsive and the plugin Output for errors.",
              details: { method, timeoutMs: this.timeoutMs },
            },
          ),
        );
      }, this.timeoutMs);

      this.pending.set(id, { resolve, reject, timer });

      try {
        this.ws!.send(JSON.stringify(request));
      } catch (error) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(
          new GodotMcpError(
            ErrorCodes.GODOT_NOT_CONNECTED,
            `Failed to send request to Godot: ${error instanceof Error ? error.message : String(error)}`,
            {
              suggestion: "Restart Godot and the MCP server.",
            },
          ),
        );
      }
    });
  }

  private async ensureConnected(): Promise<void> {
    if (this.isConnected()) {
      return;
    }
    if (this.connectPromise) {
      return this.connectPromise;
    }
    this.connectPromise = this.connectInternal().finally(() => {
      this.connectPromise = null;
    });
    return this.connectPromise;
  }

  private async connectInternal(): Promise<void> {
    if (this.intentionallyClosed) {
      throw new GodotMcpError(
        ErrorCodes.GODOT_NOT_CONNECTED,
        "Godot client is stopped.",
      );
    }

    if (this.isConnected()) {
      return;
    }

    await new Promise<void>((resolve, reject) => {
      console.error(`[godot-mcp] Connecting to ${this.url} ...`);
      const ws = new WebSocket(this.url);

      const cleanup = () => {
        ws.removeAllListeners();
      };

      ws.once("open", () => {
        cleanup();
        this.ws = ws;
        this.attachSocketHandlers(ws);
        this.reconnectAttempts = 0;
        this.lastConnectedAt = new Date();
        this.lastError = null;
        console.error(`[godot-mcp] Connected to Godot at ${this.url}`);
        resolve();
      });

      ws.once("error", (error) => {
        cleanup();
        this.lastError = error.message;
        reject(
          new GodotMcpError(
            ErrorCodes.GODOT_NOT_CONNECTED,
            `Unable to connect to Godot at ${this.url}: ${error.message}`,
            {
              suggestion:
                "Start Godot with the MCP plugin enabled. Default port is 6505 (override with GODOT_MCP_PORT).",
              details: { url: this.url },
            },
          ),
        );
      });

      ws.once("close", () => {
        cleanup();
        if (!this.isConnected()) {
          reject(
            new GodotMcpError(
              ErrorCodes.GODOT_NOT_CONNECTED,
              `Connection to Godot closed before opening (${this.url}).`,
              {
                suggestion: "Ensure the Godot MCP plugin is enabled in the editor.",
              },
            ),
          );
        }
      });
    });
  }

  private attachSocketHandlers(ws: WebSocket): void {
    ws.on("message", (data) => {
      this.handleMessage(String(data));
    });

    ws.on("close", () => {
      console.error("[godot-mcp] Disconnected from Godot.");
      if (this.ws === ws) {
        this.ws = null;
      }
      this.rejectAllPending(
        new GodotMcpError(
          ErrorCodes.GODOT_NOT_CONNECTED,
          "Lost connection to Godot editor plugin.",
          {
            suggestion: "The MCP server will reconnect on the next tool call.",
          },
        ),
      );
      this.scheduleReconnect();
    });

    ws.on("error", (error) => {
      this.lastError = error.message;
      console.error(`[godot-mcp] WebSocket error: ${error.message}`);
    });
  }

  private handleMessage(raw: string): void {
    let parsed: GodotResponse;
    try {
      parsed = JSON.parse(raw) as GodotResponse;
    } catch {
      console.error(`[godot-mcp] Invalid JSON from Godot: ${raw.slice(0, 200)}`);
      return;
    }

    const pending = this.pending.get(parsed.id);
    if (!pending) {
      console.error(`[godot-mcp] Unexpected response id: ${parsed.id}`);
      return;
    }

    clearTimeout(pending.timer);
    this.pending.delete(parsed.id);

    if (isGodotErrorResponse(parsed)) {
      pending.reject(
        new GodotMcpError(parsed.error.code as typeof ErrorCodes[keyof typeof ErrorCodes], parsed.error.message, {
          suggestion: parsed.error.suggestion,
          details: parsed.error.details,
        }),
      );
      return;
    }

    pending.resolve(parsed.result);
  }

  private rejectAllPending(error: Error): void {
    for (const [id, pending] of this.pending.entries()) {
      clearTimeout(pending.timer);
      pending.reject(error);
      this.pending.delete(id);
    }
  }

  private scheduleReconnect(): void {
    if (this.intentionallyClosed || this.reconnectTimer) {
      return;
    }

    this.reconnectAttempts += 1;
    const delay = Math.min(
      1000 * this.reconnectAttempts,
      MAX_RECONNECT_DELAY_MS,
    );

    console.error(
      `[godot-mcp] Scheduling reconnect attempt ${this.reconnectAttempts} in ${delay}ms`,
    );

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connectInternal().catch((error) => {
        this.lastError =
          error instanceof Error ? error.message : String(error);
        console.error(
          `[godot-mcp] Reconnect failed: ${this.lastError}`,
        );
        this.scheduleReconnect();
      });
    }, delay);
  }
}
