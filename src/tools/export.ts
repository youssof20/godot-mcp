import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const exportToolSchemas = {
  list_export_presets: z.object({}).strict(),
  get_export_info: z.object({ preset_index: z.number().int().optional().default(0) }).strict(),
  export_project: z.object({
    preset: z.string(),
    export_path: z.string(),
    debug: z.boolean().optional().default(false),
  }).strict(),
};

export function registerExportTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  registerGodotTool(server, client, enabled, "list_export_presets", "List export presets from export_presets.cfg.", exportToolSchemas.list_export_presets.shape);
  registerGodotTool(server, client, enabled, "get_export_info", "Get export preset details.", exportToolSchemas.get_export_info.shape);
  registerGodotTool(server, client, enabled, "export_project", "Export project via headless Godot CLI.", exportToolSchemas.export_project.shape);
}
