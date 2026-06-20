import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const editorToolSchemas = {
  get_editor_errors: z.object({
    include_open_scripts: z.boolean().optional().default(true),
    include_scene_validation: z.boolean().optional().default(true),
  }),
  get_output_log: z.object({
    limit: z.number().int().min(1).max(500).optional().default(100),
    kind: z.string().optional().describe("Filter: message, error, or omit for all"),
  }),
  reload_project: z.object({}).strict(),
};

export function registerEditorTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  registerGodotTool(
    server,
    client,
    enabled,
    "get_editor_errors",
    "Get script/scene validation issues from the editor.",
    editorToolSchemas.get_editor_errors.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_output_log",
    "Get recent editor log lines captured by the MCP plugin.",
    editorToolSchemas.get_output_log.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "reload_project",
    "Rescan the filesystem and reload the current edited scene.",
    editorToolSchemas.reload_project.shape,
  );
}
