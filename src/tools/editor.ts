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
  execute_editor_script: z.object({
    source: z.string().min(1),
    mode: z.enum(["expression", "block"]).optional().default("expression"),
  }),
  clear_output: z.object({}).strict(),
  reload_plugin: z.object({}).strict(),
  get_editor_state: z.object({}).strict(),
  get_selected_nodes: z.object({}).strict(),
  list_node_types: z.object({
    category: z.string().optional(),
    search: z.string().optional(),
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
    "execute_editor_script",
    "DANGEROUS: Run GDScript in the editor (requires ALLOW_GODOT_MCP_DANGEROUS=1).",
    editorToolSchemas.execute_editor_script.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "clear_output",
    "Clear the MCP-captured editor output log buffer.",
    editorToolSchemas.clear_output.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "reload_plugin",
    "Disable and re-enable the Godot MCP plugin (restarts WebSocket server).",
    editorToolSchemas.reload_plugin.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_editor_state",
    "Snapshot of editor context: open scene, scripts, selection, play mode, validation issues.",
    editorToolSchemas.get_editor_state.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_selected_nodes",
    "Get currently selected nodes in the Godot editor.",
    editorToolSchemas.get_selected_nodes.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "list_node_types",
    "List common Godot node types by category or search (for add_node).",
    editorToolSchemas.list_node_types.shape,
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
