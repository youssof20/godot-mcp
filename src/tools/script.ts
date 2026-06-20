import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const scriptToolSchemas = {
  list_scripts: z.object({
    path: z.string().optional().default("res://"),
    extensions: z.array(z.string()).optional(),
    max_results: z.number().int().min(1).max(5000).optional().default(500),
  }),
  read_script: z.object({
    script_path: z.string().min(1),
  }),
  create_script: z.object({
    script_path: z.string().min(1),
    content: z.string().optional(),
    extends_class: z.string().optional().default("Node"),
    attach_to_node: z.boolean().optional().default(false),
    node_path: z.string().optional(),
  }),
  edit_script: z.object({
    script_path: z.string().min(1),
    content: z.string(),
  }),
  attach_script: z.object({
    node_path: z.string().min(1),
    script_path: z.string().min(1),
  }),
  validate_script: z.object({
    script_path: z.string().optional(),
    content: z.string().optional(),
  }),
  search_in_files: z.object({
    query: z.string().min(1),
    path: z.string().optional().default("res://"),
    case_sensitive: z.boolean().optional().default(false),
    max_results: z.number().int().min(1).max(1000).optional().default(100),
    extensions: z.array(z.string()).optional(),
  }),
  get_open_scripts: z.object({}).strict(),
};

export function registerScriptTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  registerGodotTool(
    server,
    client,
    enabled,
    "list_scripts",
    "List script files under a res:// path.",
    scriptToolSchemas.list_scripts.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "read_script",
    "Read script file contents from the project.",
    scriptToolSchemas.read_script.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "create_script",
    "Create a new script file (undoable).",
    scriptToolSchemas.create_script.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "edit_script",
    "Replace script file contents (undoable).",
    scriptToolSchemas.edit_script.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "attach_script",
    "Attach a script resource to a node (undoable).",
    scriptToolSchemas.attach_script.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "validate_script",
    "Validate GDScript source via GDScript.reload().",
    scriptToolSchemas.validate_script.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "search_in_files",
    "Search text content in project files.",
    scriptToolSchemas.search_in_files.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_open_scripts",
    "List scripts currently open in the Godot script editor.",
    scriptToolSchemas.get_open_scripts.shape,
  );
}
