import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const profilingToolSchemas = {
  get_performance_monitors: z.object({
    monitors: z.array(z.string()).optional(),
  }).strict(),
  get_editor_performance: z.object({}).strict(),
};

export function registerProfilingTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  registerGodotTool(server, client, enabled, "get_performance_monitors", "Read Godot Performance monitors.", profilingToolSchemas.get_performance_monitors.shape);
  registerGodotTool(server, client, enabled, "get_editor_performance", "Editor FPS, memory, and scene stats.", profilingToolSchemas.get_editor_performance.shape);
}
