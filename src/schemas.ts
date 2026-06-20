import { z } from "zod";

/** Empty params schema for tools that take no arguments. */
export const emptyParamsSchema = z.object({}).strict();

export type EmptyParams = z.infer<typeof emptyParamsSchema>;

export const toolModeSchema = z.enum(["full", "lite", "minimal"]);
export type ToolMode = z.infer<typeof toolModeSchema>;

export function getToolMode(): ToolMode {
  const raw = process.env.GODOT_MCP_MODE?.toLowerCase();
  if (raw === "full" || raw === "lite" || raw === "minimal") {
    return raw;
  }
  return "minimal";
}

export function isDangerousToolsAllowed(): boolean {
  return process.env.ALLOW_GODOT_MCP_DANGEROUS === "1";
}

export function getGodotPort(): number {
  const raw = process.env.GODOT_MCP_PORT;
  if (!raw) {
    return 6505;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > 65535) {
    throw new Error(`Invalid GODOT_MCP_PORT: ${raw}`);
  }
  return parsed;
}

export function getRequestTimeoutMs(): number {
  const raw = process.env.GODOT_MCP_TIMEOUT_MS;
  if (!raw) {
    return 30_000;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 1000) {
    return 30_000;
  }
  return parsed;
}
