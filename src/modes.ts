import type { ToolCategory } from "./tools/spec.js";
import { getToolCategory } from "./tools/spec.js";

export type ServerMode = "full" | "lite" | "3d" | "minimal";

/** Tools in --lite that are outside lite categories (e.g. batch). */
const LITE_EXTRA_TOOLS = new Set([
  "get_signal_graph",
  "get_export_values",
  "validate_godot4_api",
  "describe_scene",
  "get_capabilities",
  "get_class_doc",
  "get_project_memory",
  "set_project_memory",
  "get_recent_changes",
  "flag_chat_health",
]);

/** Categories included in --lite (~85 tools, includes awareness + blindness tools) */
const LITE_CATEGORIES = new Set<ToolCategory>([
  "project",
  "scene",
  "node",
  "script",
  "editor",
  "input",
  "input_map",
  "runtime",
]);

/** Extra categories for --3d (lite + physics + navigation + animation_tree) */
const MODE_3D_EXTRA = new Set<ToolCategory>([
  "physics",
  "navigation",
  "animation_tree",
]);

/** 38 essential tools for --minimal */
export const MINIMAL_TOOL_NAMES = new Set([
  "list_available_tools",
  "get_capabilities",
  "initialize_session",
  "describe_scene",
  "get_project_info",
  "get_filesystem_tree",
  "search_files",
  "get_scene_tree",
  "open_scene",
  "save_scene",
  "create_scene",
  "play_scene",
  "stop_scene",
  "add_node",
  "delete_node",
  "update_property",
  "get_node_properties",
  "rename_node",
  "read_script",
  "edit_script",
  "create_script",
  "attach_script",
  "validate_script",
  "get_editor_errors",
  "get_output_log",
  "get_mcp_activity_log",
  "get_editor_screenshot",
  "get_game_screenshot",
  "execute_editor_script",
  "get_game_scene_tree",
  "get_game_node_properties",
  "set_game_node_property",
  "execute_game_script",
  "simulate_key",
  "simulate_mouse_click",
  "simulate_action",
  "wait_for_node",
  "find_ui_elements",
  "click_button_by_text",
  "batch_get_properties",
  "get_spatial_map",
  "watch_game_state",
  "validate_godot4_api",
  "get_class_doc",
  "get_project_memory",
  "set_project_memory",
  "flag_chat_health",
  "get_recent_changes",
]);

export function parseServerMode(argv: string[]): ServerMode {
  if (argv.includes("--minimal")) return "minimal";
  if (argv.includes("--lite")) return "lite";
  if (argv.includes("--3d")) return "3d";
  return "full";
}

export function isToolEnabledInMode(
  toolName: string,
  mode: ServerMode,
): boolean {
  if (mode === "full") return true;

  if (mode === "minimal") {
    return MINIMAL_TOOL_NAMES.has(toolName);
  }

  const category = getToolCategory(toolName);
  if (!category) return false;

  if (mode === "lite") {
    return LITE_CATEGORIES.has(category) || LITE_EXTRA_TOOLS.has(toolName);
  }

  if (mode === "3d") {
    return LITE_CATEGORIES.has(category) || MODE_3D_EXTRA.has(category);
  }

  return false;
}
