import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const analysisToolSchemas = {
  analyze_scene_complexity: z.object({ scene_path: z.string().optional() }).strict(),
  analyze_signal_flow: z.object({}).strict(),
  find_unused_resources: z.object({
    path: z.string().optional().default("res://"),
    limit: z.number().int().optional().default(100),
    extensions: z.array(z.string()).optional(),
  }).strict(),
  get_project_statistics: z.object({}).strict(),
  audit_project_health: z.object({}).strict(),
};

export function registerAnalysisTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  for (const name of Object.keys(analysisToolSchemas) as Array<keyof typeof analysisToolSchemas>) {
    registerGodotTool(server, client, enabled, name, `Analysis tool: ${name}`, analysisToolSchemas[name].shape);
  }
}
