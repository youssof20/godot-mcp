import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import { registerTool } from "./helpers.js";
import { setToolCategory } from "./spec.js";

const CAN_DO = [
  "Read live editor scene tree (names, types, paths) via get_scene_tree",
  "Summarize 3D layout via describe_scene action:spatial_3d or get_spatial_map",
  "Summarize 2D positions, z-index, layers via describe_scene action:spatial_2d",
  "Outline UI hierarchy and anchors via describe_scene action:ui_outline",
  "Describe TileMap bounds and cells via describe_scene action:tilemap_grid",
  "Read animation state via describe_scene action:animation_state",
  "List project assets by type via describe_scene action:asset_inventory",
  "Diff scene tree against a prior snapshot via describe_scene action:scene_diff",
  "Read @export values including inspector overrides via get_export_values",
  "Walk the signal graph via get_signal_graph",
  "Detect Godot 3 to Godot 4 syntax issues via validate_godot4_api",
  "Run a scene and sample node properties via watch_game_state",
  "Edit GDScript via edit_script (full file, ranges, replacements)",
  "Add, move, delete, rename nodes and set properties via node tools",
  "Open, save, and create scenes",
  "Simulate keyboard, mouse, and InputMap actions in the running game",
  "Capture editor or game screenshots",
  "List registered MCP tools via list_available_tools",
  "Read MCP activity log via get_mcp_activity_log",
  "Post-edit validation on edit_script, create_script, update_property",
  "Look up Godot 4 ClassDB via get_class_doc",
  "Persist project notes via set_project_memory / get_project_memory",
  "Review session tool history via get_recent_changes and flag_chat_health",
];

const CANNOT_DO = [
  "Generate audio files; provide audio assets in the project",
  "Generate textures, sprites, or images; only read existing files",
  "Generate 3D meshes from scratch; CSG primitives and imported models only",
  "Author Shader Graph visually; text .gdshader edits only",
  "Judge game feel, juice, or audio mix quality",
  "Replace human playtesting",
  "Edit open scene files on disk without force=true (conflict error -32009)",
];

const CAVEATS = [
  "Prefer describe_scene over screenshots for layout and state",
  "watch_game_state requires mcp_*_service.gd autoloads in the game project",
  "play_scene needs a main scene, an open .tscn tab, or an explicit res:// path",
  "execute_editor_script file IO requires allow_unsafe_editor_io=true",
];

const WORKFLOW = [
  "1. list_available_tools",
  "2. get_capabilities",
  "3. initialize_session",
  "4. describe_scene with the appropriate action",
  "5. Plan, then edit",
  "6. watch_game_state after physics changes; get_mcp_activity_log on failures",
  "7. Request binary assets from the user when needed",
];

export function registerCapabilitiesTool(client: GodotClient): void {
  registerTool(client, {
    name: "get_capabilities",
    description:
      "Returns what this MCP server can and cannot do, plus a recommended workflow. Call once per session before large edits.",
    schema: z.object({}),
    handler: async () => ({
      can_do: CAN_DO,
      cannot_do: CANNOT_DO,
      caveats: CAVEATS,
      workflow: WORKFLOW,
      summary:
        "Translation layer for Godot scenes and scripts, not an asset pipeline. " +
        `Supports ${CAN_DO.length} capability areas; cannot generate audio, textures, or meshes.`,
    }),
  });
  setToolCategory("get_capabilities", "project");
}
