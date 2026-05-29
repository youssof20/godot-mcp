import { z, type ZodObject, type ZodRawShape } from "zod";

/**
 * Typed Zod schemas for high-traffic addon tools.
 * Tools without an entry here use PASSTHROUGH_SCHEMA (schema pending).
 */
export const typedSchemas: Record<string, ZodObject<ZodRawShape>> = {
  add_node: z.object({
    type: z.string().describe("Godot class name or script class_name"),
    parent_path: z.string().optional().describe("Parent node path; default ."),
    name: z.string().optional().describe("New node name"),
    properties: z.record(z.unknown()).optional().describe("Initial property values"),
  }),

  open_scene: z.object({
    path: z.string().describe("res:// path to .tscn/.scn"),
  }),

  create_scene: z.object({
    path: z.string().describe("res:// path for new scene file"),
    root_type: z.string().optional().describe("Root node class, e.g. Node2D"),
    root_name: z.string().optional().describe("Root node name"),
  }),

  delete_node: z.object({
    node_path: z.string().describe("Path to node to delete"),
  }),

  rename_node: z.object({
    node_path: z.string().describe("Path to node"),
    new_name: z.string().describe("New node name"),
  }),

  move_node: z.object({
    node_path: z.string().describe("Path to node to reparent"),
    new_parent_path: z.string().describe("Path to new parent"),
  }),

  get_node_properties: z.object({
    node_path: z.string().describe("Path to node"),
    category: z.string().optional().describe("Filter properties by name prefix"),
  }),

  duplicate_node: z.object({
    node_path: z.string().describe("Path to node to duplicate"),
    new_name: z.string().optional().describe("Name for duplicate"),
  }),

  connect_signal: z.object({
    source_path: z.string().describe("Emitter node path"),
    signal_name: z.string().describe("Signal name on source"),
    target_path: z.string().describe("Receiver node path"),
    method_name: z.string().describe("Method to call on target"),
  }),

  disconnect_signal: z.object({
    source_path: z.string().describe("Emitter node path"),
    signal_name: z.string().describe("Signal name"),
    target_path: z.string().describe("Receiver node path"),
    method_name: z.string().describe("Connected method name"),
  }),

  play_scene: z.object({
    mode: z
      .string()
      .optional()
      .describe('"main", "current", or res:// path to a scene file'),
  }),

  stop_scene: z.object({}),

  save_scene: z.object({
    path: z.string().optional().describe("Save path; uses active scene path if omitted"),
  }),

  get_scene_file_content: z.object({
    path: z.string().describe("res:// path to scene file"),
  }),

  add_scene_instance: z.object({
    scene_path: z.string().describe("res:// path of scene to instance"),
    parent_path: z.string().optional().describe("Parent node path; default ."),
    name: z.string().optional().describe("Instance node name"),
  }),

  get_signals: z.object({
    node_path: z.string().describe("Path to node"),
  }),

  tilemap_set_cell: z.object({
    node_path: z.string().describe("TileMapLayer node path"),
    x: z.number().describe("Tile X coordinate"),
    y: z.number().describe("Tile Y coordinate"),
    source_id: z.number().optional().describe("TileSet source id"),
    atlas_x: z.number().optional().describe("Atlas coords X"),
    atlas_y: z.number().optional().describe("Atlas coords Y"),
    alternative: z.number().optional().describe("Alternative tile id"),
  }),

  tilemap_fill_rect: z.object({
    node_path: z.string().describe("TileMapLayer node path"),
    x1: z.number().describe("Rect start X"),
    y1: z.number().describe("Rect start Y"),
    x2: z.number().describe("Rect end X"),
    y2: z.number().describe("Rect end Y"),
    source_id: z.number().optional().describe("TileSet source id"),
    atlas_x: z.number().optional(),
    atlas_y: z.number().optional(),
    alternative: z.number().optional(),
  }),

  tilemap_get_info: z.object({
    node_path: z.string().describe("TileMapLayer node path"),
  }),

  get_performance_monitors: z.object({}),

  list_animations: z.object({
    node_path: z.string().describe("AnimationPlayer node path"),
  }),

  create_animation: z.object({
    node_path: z.string().describe("AnimationPlayer node path"),
    name: z.string().describe("Animation name"),
    length: z.number().optional().describe("Duration in seconds"),
    loop_mode: z.number().optional().describe("0=none, 1=linear, 2=pingpong"),
  }),

  get_project_settings: z.object({
    section: z.string().optional().describe("Setting section prefix filter"),
    key: z.string().optional().describe("Specific setting key"),
  }),

  set_project_setting: z.object({
    key: z.string().describe("ProjectSettings key"),
    value: z.union([z.string(), z.number(), z.boolean()]).describe("Value to set"),
  }),

  add_autoload: z.object({
    name: z.string().describe("Autoload name"),
    path: z.string().describe("res:// script path"),
  }),

  remove_autoload: z.object({
    name: z.string().describe("Autoload name to remove"),
  }),

  create_shader: z.object({
    path: z.string().describe("res:// shader path"),
    content: z.string().optional().describe("Shader source"),
    shader_type: z.string().optional().describe("spatial, canvas_item, particles, sky"),
    force: z.boolean().optional().describe("Overwrite if open in editor (-32009)"),
  }),

  edit_shader: z.object({
    path: z.string().describe("res:// shader path"),
    content: z.string().optional().describe("Full replacement content"),
    replacements: z
      .array(
        z.object({
          search: z.string(),
          replace: z.string(),
          regex: z.boolean().optional(),
        }),
      )
      .optional(),
    force: z.boolean().optional().describe("Overwrite if open in editor"),
  }),

  get_mcp_activity_log: z.object({
    max_entries: z.number().optional().describe("Max log entries to return (default 50)"),
    errors_only: z.boolean().optional().describe("Only failed tool calls"),
    since_index: z.number().optional().describe("Return entries after this buffer index"),
    as_text: z.boolean().optional().describe("Return plain text instead of JSON entries"),
    include_params: z.boolean().optional().describe("Include request params in text export"),
    include_responses: z.boolean().optional().describe("Include responses in text export"),
    full_responses: z.boolean().optional().describe("No truncation in text export"),
  }),

  clear_mcp_activity_log: z.object({}),

  save_mcp_activity_log: z.object({
    path: z
      .string()
      .optional()
      .describe("Output path (default user://mcp_activity_log.txt)"),
    include_params: z.boolean().optional(),
    include_responses: z.boolean().optional(),
    full_responses: z.boolean().optional(),
    errors_only: z.boolean().optional(),
  }),

  cross_scene_set_property: z.object({
    type: z.string().describe("Node class/type to match"),
    property: z.string().describe("Property name"),
    value: z.union([z.string(), z.number(), z.boolean(), z.record(z.unknown())]),
    path_filter: z.string().optional().describe("Scene path filter, default res://"),
    exclude_addons: z.boolean().optional(),
    dry_run: z.boolean().optional().describe("Default true; preview only"),
    force: z.boolean().optional().describe("Required with dry_run=false to write"),
  }),
};

export function getTypedSchema(
  name: string,
): ZodObject<ZodRawShape> | undefined {
  return typedSchemas[name];
}
