#!/usr/bin/env node
/**
 * CLI for godot-mcp-local — same WebSocket commands as MCP tools.
 * Usage: node build/cli.js <group> <command> [--key value ...]
 *        node build/cli.js --help
 */
import { GodotClient } from "./godot-client.js";
import { GodotCommandError, GodotConnectionError } from "./types.js";

const GROUPS: Record<string, string[]> = {
  project: [
    "get_project_info",
    "get_filesystem_tree",
    "search_files",
    "search_in_files",
    "get_project_settings",
    "set_project_setting",
    "uid_to_project_path",
    "project_path_to_uid",
    "add_autoload",
    "remove_autoload",
  ],
  scene: [
    "get_scene_tree",
    "get_scene_file_content",
    "create_scene",
    "open_scene",
    "delete_scene",
    "save_scene",
    "play_scene",
    "stop_scene",
    "add_scene_instance",
    "get_scene_exports",
  ],
  node: [
    "add_node",
    "delete_node",
    "duplicate_node",
    "move_node",
    "update_property",
    "get_node_properties",
    "rename_node",
    "connect_signal",
    "disconnect_signal",
    "get_node_groups",
    "set_node_groups",
    "find_nodes_in_group",
    "add_resource",
    "set_anchor_preset",
  ],
  script: [
    "list_scripts",
    "read_script",
    "create_script",
    "edit_script",
    "attach_script",
    "get_open_scripts",
    "validate_script",
  ],
  editor: [
    "get_editor_errors",
    "get_output_log",
    "get_editor_screenshot",
    "get_game_screenshot",
    "execute_editor_script",
    "clear_output",
    "get_signals",
    "reload_plugin",
    "reload_project",
    "get_editor_camera",
    "set_editor_camera",
  ],
  runtime: [
    "get_game_scene_tree",
    "get_game_node_properties",
    "set_game_node_property",
    "execute_game_script",
    "capture_frames",
    "wait_for_node",
    "find_ui_elements",
  ],
  input: [
    "simulate_key",
    "simulate_mouse_click",
    "simulate_mouse_move",
    "simulate_action",
    "simulate_sequence",
  ],
  input_map: ["get_input_actions", "set_input_action"],
  physics: [
    "setup_collision",
    "setup_physics_body",
    "set_physics_layers",
    "get_physics_layers",
    "get_collision_info",
    "add_raycast",
  ],
  scene3d: [
    "add_mesh_instance",
    "setup_camera_3d",
    "setup_lighting",
    "setup_environment",
    "set_material_3d",
    "add_gridmap",
  ],
  tilemap: [
    "tilemap_set_cell",
    "tilemap_fill_rect",
    "tilemap_get_cell",
    "tilemap_clear",
    "tilemap_get_info",
    "tilemap_get_used_cells",
  ],
  shader: [
    "create_shader",
    "read_shader",
    "edit_shader",
    "assign_shader_material",
    "set_shader_param",
    "get_shader_params",
  ],
  batch: [
    "find_nodes_by_type",
    "find_signal_connections",
    "batch_set_property",
    "cross_scene_set_property",
    "get_scene_dependencies",
  ],
  testing: [
    "run_test_scenario",
    "assert_node_state",
    "assert_screen_text",
    "get_test_report",
  ],
};

function printHelp(): void {
  console.log(`godot-mcp-local CLI — direct Godot editor commands

Usage:
  node build/cli.js                           Show groups
  node build/cli.js <group>                   List commands in group
  node build/cli.js <group> <command> [opts]  Run command

Options are passed as JSON-RPC params:
  --path res://main.tscn
  --node_path Player
  --property position
  --value "Vector2(100, 200)"
  --query player
  --code "print('hi')"

Requires Godot editor open with MCP plugin enabled.

Groups: ${Object.keys(GROUPS).join(", ")}
`);
}

function parseArgs(argv: string[]): Record<string, unknown> {
  const params: Record<string, unknown> = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith("--")) {
      params[key] = true;
    } else {
      try {
        params[key] = JSON.parse(next);
      } catch {
        params[key] = next;
      }
      i++;
    }
  }
  return params;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);

  if (argv.length === 0 || argv[0] === "--help" || argv[0] === "-h") {
    printHelp();
    return;
  }

  const group = argv[0];

  if (argv.length === 1) {
    const commands = GROUPS[group];
    if (!commands) {
      console.error(`Unknown group: ${group}`);
      printHelp();
      process.exit(1);
    }
    console.log(`Commands in '${group}':\n`);
    for (const cmd of commands) {
      console.log(`  ${cmd}`);
    }
    console.log(`\nRun: node build/cli.js ${group} <command> [--params]`);
    return;
  }

  const method = argv[1];
  const params = parseArgs(argv.slice(2));

  const client = new GodotClient();
  await client.start();

  if (!client.isConnected()) {
    console.error(
      "Waiting for Godot to connect (enable MCP Pro plugin in editor)...",
    );
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new GodotConnectionError("Godot did not connect within 30s"));
      }, 30_000);
      client.once("connected", () => {
        clearTimeout(timeout);
        resolve();
      });
    });
  }

  try {
    const result = await client.send(method, params);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    if (err instanceof GodotCommandError || err instanceof GodotConnectionError) {
      console.error(err.message);
      process.exit(1);
    }
    throw err;
  } finally {
    await client.stop();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
