import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import { WebSocketServer, type WebSocket } from "ws";
import type { JsonRpcRequest, JsonRpcResponse } from "./types.js";
import {
  GodotCommandError,
  GodotConnectionError,
} from "./types.js";

const BASE_PORT = 6505;
const MAX_PORT = 6509;
const PING_INTERVAL_MS = 10_000;
const PONG_TIMEOUT_MS = 5_000;
const INBOUND_TIMEOUT_MS = 30_000;
const COMMAND_TIMEOUT_MS = 30_000;

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (reason: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

export class GodotClient extends EventEmitter {
  private wss: WebSocketServer | null = null;
  private peer: WebSocket | null = null;
  private boundPort: number | null = null;
  private readonly pending = new Map<string, PendingRequest>();
  private pingTimer: ReturnType<typeof setInterval> | null = null;
  private healthTimer: ReturnType<typeof setInterval> | null = null;
  private lastPongAt = 0;
  private lastInboundAt = 0;
  private lastPingSentAt = 0;
  private readonly fixedPort: number | null;

  constructor(defaultPort = BASE_PORT) {
    super();
    const envPort = process.env.GODOT_MCP_PORT;
    if (envPort) {
      const parsed = parseInt(envPort, 10);
      this.fixedPort = Number.isFinite(parsed) ? parsed : defaultPort;
    } else {
      this.fixedPort = null;
    }
  }

  get port(): number | null {
    return this.boundPort;
  }

  isConnected(): boolean {
    return this.peer !== null && this.peer.readyState === this.peer.OPEN;
  }

  async start(): Promise<number> {
    if (this.wss) {
      return this.boundPort!;
    }

    const ports = this.fixedPort !== null
      ? [this.fixedPort]
      : Array.from({ length: MAX_PORT - BASE_PORT + 1 }, (_, i) => BASE_PORT + i);

    let lastError: Error | null = null;

    for (const port of ports) {
      try {
        await this.bindPort(port);
        this.boundPort = port;
        console.error(`[godot-mcp-local] WebSocket listening on ws://127.0.0.1:${port}`);
        this.startHealthChecks();
        return port;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
        if (this.fixedPort !== null) {
          throw new Error(
            `Port ${port} is in use (GODOT_MCP_PORT). Close the other process or choose another port. ${lastError.message}`,
          );
        }
      }
    }

    throw new Error(
      `No available port in range ${BASE_PORT}-${MAX_PORT}. ${lastError?.message ?? ""}`,
    );
  }

  private bindPort(port: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const wss = new WebSocketServer({ host: "127.0.0.1", port });

      wss.on("listening", () => {
        this.wss = wss;
        resolve();
      });

      wss.on("error", (err: NodeJS.ErrnoException) => {
        wss.close();
        if (err.code === "EADDRINUSE") {
          reject(err);
        } else {
          reject(err);
        }
      });

      wss.on("connection", (ws) => {
        this.attachPeer(ws);
      });
    });
  }

  private attachPeer(ws: WebSocket): void {
    if (this.peer && this.peer !== ws) {
      this.peer.close(1000, "Replaced by new connection");
    }

    this.peer = ws;
    this.lastPongAt = Date.now();
    this.lastInboundAt = Date.now();

    this.enableTcpKeepalive(ws);

    ws.on("message", (data) => {
      const now = Date.now();
      this.lastInboundAt = now;
      // Any inbound traffic means the peer is alive (Godot pings every 5s too).
      this.lastPongAt = now;
      const text = typeof data === "string" ? data : data.toString("utf8");
      this.handleMessage(text);
    });

    ws.on("close", () => {
      if (this.peer === ws) {
        this.peer = null;
        this.rejectAllPending(
          new GodotConnectionError(
            "Godot disconnected. Ensure the Godot editor is open with the MCP plugin enabled.",
          ),
        );
        this.emit("disconnected");
      }
    });

    ws.on("error", () => {
      // close handler cleans up
    });

    console.error("[godot-mcp-local] Godot editor connected");
    this.emit("connected");
  }

  private enableTcpKeepalive(ws: WebSocket): void {
    const socket = (
      ws as WebSocket & { _socket?: import("node:net").Socket }
    )._socket;
    if (socket && typeof socket.setKeepAlive === "function") {
      socket.setKeepAlive(true, 5000);
    }
  }

  private startHealthChecks(): void {
    this.pingTimer = setInterval(() => {
      if (!this.isConnected()) return;
      this.lastPingSentAt = Date.now();
      this.peer!.send(
        JSON.stringify({ jsonrpc: "2.0", method: "ping", params: {} }),
      );
    }, PING_INTERVAL_MS);

    this.healthTimer = setInterval(() => {
      if (!this.isConnected()) return;

      if (
        this.lastPingSentAt > 0 &&
        this.lastPongAt < this.lastPingSentAt &&
        Date.now() - this.lastPingSentAt > PONG_TIMEOUT_MS
      ) {
        console.error("[godot-mcp-local] Pong timeout — forcing reconnect");
        this.forceClosePeer();
        return;
      }

      if (Date.now() - this.lastInboundAt > INBOUND_TIMEOUT_MS) {
        console.error("[godot-mcp-local] Inbound silence timeout — forcing reconnect");
        this.forceClosePeer();
      }
    }, 1000);
  }

  private forceClosePeer(): void {
    if (!this.peer) return;
    const ws = this.peer;
    this.peer = null;
    ws.terminate();
    this.rejectAllPending(
      new GodotConnectionError(
        "Connection stale. Godot will reconnect automatically; retry the command.",
      ),
    );
    this.emit("disconnected");
  }

  private handleMessage(text: string): void {
    let msg: JsonRpcResponse;
    try {
      msg = JSON.parse(text) as JsonRpcResponse;
    } catch {
      return;
    }

    if (msg.method === "ping") {
      this.sendRaw({ jsonrpc: "2.0", method: "pong", params: {} });
      return;
    }

    if (msg.method === "pong") {
      this.lastPongAt = Date.now();
      return;
    }

    if (msg.id !== undefined && msg.id !== null) {
      const key = String(msg.id);
      const pending = this.pending.get(key);
      if (!pending) return;

      clearTimeout(pending.timer);
      this.pending.delete(key);

      if (msg.error) {
        pending.reject(new GodotCommandError(msg.error));
      } else {
        pending.resolve(msg.result ?? {});
      }
    }
  }

  private sendRaw(payload: Record<string, unknown>): void {
    if (!this.isConnected()) return;
    this.peer!.send(JSON.stringify(payload));
  }

  async waitForConnection(timeoutMs = 30_000): Promise<void> {
    if (this.isConnected()) return;

    return new Promise((resolve, reject) => {
      const onConnect = () => {
        clearTimeout(timer);
        this.off("connected", onConnect);
        resolve();
      };

      const timer = setTimeout(() => {
        this.off("connected", onConnect);
        reject(
          new GodotConnectionError(
            "Godot is not connected. Open the Godot editor and enable the Godot MCP Pro plugin (Project → Plugins).",
          ),
        );
      }, timeoutMs);

      this.once("connected", onConnect);
    });
  }

  async send(
    method: string,
    params: Record<string, unknown> = {},
  ): Promise<unknown> {
    if (!this.isConnected()) {
      await this.waitForConnection();
    }

    const id = randomUUID();
    const request: JsonRpcRequest = {
      jsonrpc: "2.0",
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(
          new Error(
            `Command '${method}' timed out after ${COMMAND_TIMEOUT_MS / 1000}s`,
          ),
        );
      }, COMMAND_TIMEOUT_MS);

      this.pending.set(id, { resolve, reject, timer });
      this.peer!.send(JSON.stringify(request));
    });
  }

  private rejectAllPending(err: Error): void {
    for (const [, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(err);
    }
    this.pending.clear();
  }

  async stop(): Promise<void> {
    if (this.pingTimer) clearInterval(this.pingTimer);
    if (this.healthTimer) clearInterval(this.healthTimer);
    this.pingTimer = null;
    this.healthTimer = null;

    this.rejectAllPending(new GodotConnectionError("Server shutting down"));

    if (this.peer) {
      this.peer.close(1000, "Server shutting down");
      this.peer = null;
    }

    return new Promise((resolve) => {
      if (!this.wss) {
        resolve();
        return;
      }
      this.wss.close(() => {
        this.wss = null;
        resolve();
      });
    });
  }
}
