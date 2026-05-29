import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import { parseGodotValue } from "../types.js";
import {
  callGodot,
  formatCaptureFramesContent,
  registerTool,
} from "./helpers.js";
import {
  type GodotToolSpec,
  registerGodotSpec,
  registerGodotSpecs,
  setToolCategory,
} from "./spec.js";
import { getTypedSchema } from "./typed-schemas.js";

/** Tools with dedicated zod handlers — not registered from bulk catalog */
export const SPECIAL_TOOL_NAMES = new Set([
  "update_property",
  "set_game_node_property",
  "read_script",
  "create_script",
  "edit_script",
  "attach_script",
  "validate_script",
  "execute_editor_script",
]);

function d(
  category: GodotToolSpec["category"],
  name: string,
  description: string,
): GodotToolSpec {
  // Tools without getTypedSchema() entry use passthrough — schema pending.
  const schema = getTypedSchema(name);
  return { category, name, description, schema };
}

function buildCatalog(): GodotToolSpec[] {
  const t: GodotToolSpec[] = [];

  const project: GodotToolSpec[] = [
    d("project", "get_project_info", "Live project metadata: name, Godot version, viewport, autoloads, main scene."),
    d("project", "get_filesystem_tree", "Recursive res:// file tree; optional glob filter and max_depth."),
    d("project", "search_files", "Fuzzy/glob filename search under a path."),
    d("project", "search_in_files", "Full-text search across project source files."),
    d("project", "get_project_settings", "Read a project.godot setting by key."),
    d("project", "set_project_setting", "Set a project.godot setting via editor API."),
    d("project", "uid_to_project_path", "Convert resource UID to res:// path."),
    d("project", "project_path_to_uid", "Convert res:// path to resource UID."),
    d("project", "add_autoload", "Register an autoload singleton in project settings."),
    d("project", "remove_autoload", "Remove an autoload singleton."),
  ];

  const scene: GodotToolSpec[] = [
    d(
      "scene",
      "get_scene_tree",
      "Live edited scene hierarchy. Requires a scene tab open; auto_open:true (default) opens main scene first if set.",
    ),
    d("scene", "get_scene_file_content", "Raw .tscn/.scn file text from disk."),
    d("scene", "create_scene", "Create new scene file with root node type."),
    d("scene", "open_scene", "Open scene in editor."),
    d("scene", "delete_scene", "Delete scene file from project."),
    d("scene", "save_scene", "Save via EditorInterface; refuses inactive open tabs (-32009)."),
    d("scene", "play_scene", "Run main, current, or custom scene."),
    d("scene", "stop_scene", "Stop running scene."),
    d("scene", "add_scene_instance", "Instance a scene as child of a node."),
    d("scene", "get_scene_exports", "List @export variables on scene root script."),
  ];

  const node: GodotToolSpec[] = [
    d("node", "add_node", "Add node by class or script class_name; optional properties."),
    d("node", "delete_node", "Delete node (undoable)."),
    d("node", "duplicate_node", "Duplicate node and children."),
    d("node", "move_node", "Reparent node."),
    d("node", "get_node_properties", "All editor properties of a node (position, rotation, etc.)."),
    d("node", "add_resource", "Attach Resource (Shape2D, Material, etc.) to node property."),
    d("node", "set_anchor_preset", "Set Control anchor/layout preset."),
    d("node", "rename_node", "Rename node."),
    d("node", "connect_signal", "Connect signal between nodes."),
    d("node", "disconnect_signal", "Disconnect signal."),
    d("node", "get_node_groups", "Get groups for a node."),
    d("node", "set_node_groups", "Set node group membership."),
    d("node", "find_nodes_in_group", "Find all nodes in a group in edited scene."),
  ];

  const script: GodotToolSpec[] = [
    d("script", "list_scripts", "List .gd/.cs scripts with class_name/extends hints."),
    d("script", "get_open_scripts", "Scripts currently open in script editor."),
  ];

  const editor: GodotToolSpec[] = [
    d("editor", "get_editor_errors", "Errors/warnings from Output, script analyzer, debugger."),
    d("editor", "get_output_log", "Recent Output panel lines."),
    d("editor", "get_editor_screenshot", "PNG base64 of editor viewport — visual ground truth."),
    d("editor", "get_game_screenshot", "PNG base64 of running game (requires play_scene)."),
    d("editor", "clear_output", "Clear Output panel."),
    d("editor", "get_signals", "List signals on a node and connections."),
    d("editor", "reload_plugin", "Reload MCP plugin."),
    d("editor", "reload_project", "Rescan filesystem and reload scripts."),
    d("editor", "compare_screenshots", "Pixel diff two base64 PNG images."),
    d("editor", "set_auto_dismiss", "Enable/disable auto-dismiss of blocking editor dialogs."),
    d("editor", "get_editor_camera", "3D editor camera position, rotation, FOV."),
    d("editor", "set_editor_camera", "Move 3D editor camera for framing/screenshots."),
    d(
      "editor",
      "get_mcp_activity_log",
      "Recent MCP tool calls from the Godot panel log (method, port, duration, params/response).",
    ),
    d("editor", "clear_mcp_activity_log", "Clear the in-editor MCP activity log buffer."),
    d(
      "editor",
      "save_mcp_activity_log",
      "Write MCP activity log to user://mcp_activity_log.txt (or custom path).",
    ),
  ];

  const input: GodotToolSpec[] = [
    d("input", "simulate_key", "Keyboard input in running game (requires play + MCPInputService)."),
    d("input", "simulate_mouse_click", "Mouse click at viewport x,y in running game."),
    d("input", "simulate_mouse_move", "Mouse motion; unhandled:false for UI drag tests."),
    d("input", "simulate_action", "InputMap action press/release in game."),
    d("input", "simulate_sequence", "Sequence of input events with frame_delay."),
  ];

  const inputMap: GodotToolSpec[] = [
    d("input_map", "get_input_actions", "List InputMap actions."),
    d("input_map", "set_input_action", "Create or modify InputMap action."),
  ];

  const runtime: GodotToolSpec[] = [
    d("runtime", "get_game_scene_tree", "Live running game scene tree (positions, hierarchy)."),
    d("runtime", "get_game_node_properties", "Properties of a node in running game."),
    d("runtime", "execute_game_script", "Run GDScript in running game context."),
    d("runtime", "monitor_properties", "Record property values over frames."),
    d("runtime", "start_recording", "Start input recording in game."),
    d("runtime", "stop_recording", "Stop input recording."),
    d("runtime", "replay_recording", "Replay recorded input."),
    d("runtime", "find_nodes_by_script", "Find game nodes using a script."),
    d("runtime", "get_autoload", "Get autoload node state in game."),
    d("runtime", "batch_get_properties", "Batch read properties from multiple game nodes."),
    d("runtime", "find_ui_elements", "Find buttons, labels, sliders in running game."),
    d("runtime", "click_button_by_text", "Click UI button by visible text."),
    d("runtime", "wait_for_node", "Poll until node appears in game."),
    d("runtime", "find_nearby_nodes", "Find nodes within radius of position."),
    d("runtime", "navigate_to", "High-level navigation to target."),
    d("runtime", "move_to", "Walk character to coordinates via pathfinding."),
    d("runtime", "watch_signals", "Watch signals emitted in game."),
  ];

  const animation: GodotToolSpec[] = [
    d("animation", "list_animations", "List animations on AnimationPlayer."),
    d("animation", "create_animation", "Create animation on AnimationPlayer."),
    d("animation", "add_animation_track", "Add track to animation."),
    d("animation", "set_animation_keyframe", "Insert keyframe."),
    d("animation", "get_animation_info", "Full animation track/key info."),
    d("animation", "remove_animation", "Remove animation."),
  ];

  const animationTree: GodotToolSpec[] = [
    d("animation_tree", "create_animation_tree", "Create AnimationTree node."),
    d("animation_tree", "get_animation_tree_structure", "State machine / blend tree structure."),
    d("animation_tree", "add_state_machine_state", "Add state to state machine."),
    d("animation_tree", "remove_state_machine_state", "Remove state."),
    d("animation_tree", "add_state_machine_transition", "Add transition between states."),
    d("animation_tree", "remove_state_machine_transition", "Remove transition."),
    d("animation_tree", "set_blend_tree_node", "Configure blend tree node."),
    d("animation_tree", "set_tree_parameter", "Set AnimationTree parameter."),
  ];

  const tilemap: GodotToolSpec[] = [
    d("tilemap", "tilemap_set_cell", "Set single TileMap cell."),
    d("tilemap", "tilemap_fill_rect", "Fill rectangle with tiles."),
    d("tilemap", "tilemap_get_cell", "Get cell tile data."),
    d("tilemap", "tilemap_clear", "Clear all cells."),
    d("tilemap", "tilemap_get_info", "TileSet sources and layer info."),
    d("tilemap", "tilemap_get_used_cells", "List used cells."),
  ];

  const theme: GodotToolSpec[] = [
    d("theme", "create_theme", "Create Theme resource file."),
    d("theme", "set_theme_color", "Theme color override."),
    d("theme", "set_theme_constant", "Theme constant override."),
    d("theme", "set_theme_font_size", "Theme font size override."),
    d("theme", "set_theme_stylebox", "StyleBoxFlat theme override."),
    d("theme", "setup_control", "Layout anchor/size presets on Control."),
    d("theme", "get_theme_info", "Theme override info for Control."),
  ];

  const profiling: GodotToolSpec[] = [
    d("profiling", "get_performance_monitors", "FPS, memory, draw calls, physics monitors."),
    d("profiling", "get_editor_performance", "Quick editor performance summary."),
  ];

  const batch: GodotToolSpec[] = [
    d("batch", "find_nodes_by_type", "Find nodes by type in edited scene."),
    d("batch", "find_signal_connections", "Audit signal connections in scene."),
    d("batch", "batch_set_property", "Set property on all nodes of a type."),
    d("batch", "batch_add_nodes", "Add multiple nodes in one undo action."),
    d("batch", "find_node_references", "Search project for node/path references."),
    d("batch", "get_scene_dependencies", "Resource dependencies of a scene."),
    d("batch", "cross_scene_set_property", "Set property across scenes; defaults dry_run=true — use dry_run=false and force=true to write."),
  ];

  const shader: GodotToolSpec[] = [
    d("shader", "create_shader", "Create shader file; force if open in editor."),
    d("shader", "read_shader", "Read shader source."),
    d("shader", "edit_shader", "Edit shader; force if open."),
    d("shader", "assign_shader_material", "Assign ShaderMaterial to node."),
    d("shader", "set_shader_param", "Set shader uniform parameter."),
    d("shader", "get_shader_params", "List shader parameters."),
  ];

  const exportTools: GodotToolSpec[] = [
    d("export", "list_export_presets", "List export presets."),
    d("export", "export_project", "Get CLI export command for preset."),
    d("export", "get_export_info", "Export template/preset info."),
  ];

  const resource: GodotToolSpec[] = [
    d("resource", "read_resource", "Read .tres resource properties."),
    d("resource", "edit_resource", "Edit .tres properties."),
    d("resource", "create_resource", "Create new .tres resource."),
    d("resource", "get_resource_preview", "Thumbnail preview base64 for resource."),
  ];

  const physics: GodotToolSpec[] = [
    d("physics", "setup_collision", "Add collision shape child to physics body/area."),
    d("physics", "setup_physics_body", "Configure body mass, damping, freeze, etc."),
    d("physics", "set_physics_layers", "Set collision layer/mask."),
    d("physics", "get_physics_layers", "Get collision layer/mask info."),
    d("physics", "get_collision_info", "Collision shape details."),
    d("physics", "add_raycast", "Add RayCast2D/3D."),
  ];

  const scene3d: GodotToolSpec[] = [
    d("scene3d", "add_mesh_instance", "Add MeshInstance3D primitive or imported mesh."),
    d("scene3d", "setup_camera_3d", "Add/configure Camera3D."),
    d("scene3d", "setup_lighting", "Add directional/omni/spot light."),
    d("scene3d", "setup_environment", "WorldEnvironment sky/ambient/tonemap."),
    d("scene3d", "set_material_3d", "StandardMaterial3D on mesh surface."),
    d("scene3d", "add_gridmap", "Setup GridMap with mesh library."),
  ];

  const particles: GodotToolSpec[] = [
    d("particles", "create_particles", "Create GPUParticles2D/3D."),
    d("particles", "set_particle_material", "ParticleProcessMaterial config."),
    d("particles", "set_particle_color_gradient", "Particle color gradient."),
    d("particles", "apply_particle_preset", "Preset: fire, smoke, rain, snow, sparks, etc."),
    d("particles", "get_particle_info", "Particle system details."),
  ];

  const navigation: GodotToolSpec[] = [
    d("navigation", "setup_navigation_region", "NavigationRegion2D/3D."),
    d("navigation", "setup_navigation_agent", "NavigationAgent for pathfinding."),
    d("navigation", "bake_navigation_mesh", "Bake navigation mesh."),
    d("navigation", "set_navigation_layers", "Set navigation layers bitmask."),
    d("navigation", "get_navigation_info", "Navigation setup info."),
  ];

  const audio: GodotToolSpec[] = [
    d("audio", "get_audio_bus_layout", "Full audio bus layout."),
    d("audio", "add_audio_bus", "Add audio bus."),
    d("audio", "set_audio_bus", "Configure bus volume/solo/mute."),
    d("audio", "add_audio_bus_effect", "Add Reverb/Delay/Compressor effect."),
    d("audio", "add_audio_player", "Add audio stream player node."),
    d("audio", "get_audio_info", "Audio node info."),
  ];

  const analysis: GodotToolSpec[] = [
    d("analysis", "find_unused_resources", "Find unreferenced resources."),
    d("analysis", "analyze_signal_flow", "Map signal connections in scene."),
    d("analysis", "analyze_scene_complexity", "Scene performance complexity."),
    d("analysis", "find_script_references", "Where script/resource is used."),
    d("analysis", "detect_circular_dependencies", "Circular scene dependencies."),
    d("analysis", "get_project_statistics", "Project-wide stats."),
  ];

  const testing: GodotToolSpec[] = [
    d("testing", "run_test_scenario", "Run multi-step automated test in game."),
    d("testing", "assert_node_state", "Assert game node property (eq, gt, contains, etc.)."),
    d("testing", "assert_screen_text", "Assert UI text visible in game."),
    d("testing", "run_stress_test", "Stress test with repeated input."),
    d("testing", "get_test_report", "Get accumulated test results."),
  ];

  const android: GodotToolSpec[] = [
    d("android", "list_android_devices", "adb devices -l."),
    d("android", "get_android_preset_info", "Android export preset metadata."),
    d("android", "deploy_to_android", "Export, install, launch on device."),
  ];

  t.push(
    ...project,
    ...scene,
    ...node,
    ...script,
    ...editor,
    ...input,
    ...inputMap,
    ...runtime,
    ...animation,
    ...animationTree,
    ...tilemap,
    ...theme,
    ...profiling,
    ...batch,
    ...shader,
    ...exportTools,
    ...resource,
    ...physics,
    ...scene3d,
    ...particles,
    ...navigation,
    ...audio,
    ...analysis,
    ...testing,
    ...android,
  );

  return t.filter((spec) => !SPECIAL_TOOL_NAMES.has(spec.name));
}

export function registerCatalogTools(client: GodotClient): void {
  registerGodotSpecs(client, buildCatalog());
}

const replacementSchema = z.object({
  search: z.string(),
  replace: z.string(),
  regex: z.boolean().optional(),
});

/** Tools needing typed params or value parsing */
export function registerSpecialTools(client: GodotClient): void {
  registerGodotSpec(client, {
    name: "update_property",
    category: "node",
    description:
      'Set node property in edited scene. Parses Vector2(1,2), #ff0000, Color(1,0,0), numbers. Undoable.',
    schema: z.object({
      node_path: z.string(),
      property: z.string(),
      value: z.union([
        z.string(),
        z.number(),
        z.boolean(),
        z.record(z.unknown()),
        z.array(z.unknown()),
      ]),
    }),
    toParams: (args) => {
      let value = args.value;
      if (typeof value === "string") value = parseGodotValue(value);
      return { node_path: args.node_path, property: args.property, value };
    },
  });

  registerGodotSpec(client, {
    name: "set_game_node_property",
    category: "runtime",
    description: "Set property on node in running game (live state).",
    schema: z.object({
      node_path: z.string(),
      property: z.string(),
      value: z.union([
        z.string(),
        z.number(),
        z.boolean(),
        z.record(z.unknown()),
        z.array(z.unknown()),
      ]),
    }),
    toParams: (args) => {
      let value = args.value;
      if (typeof value === "string") value = parseGodotValue(value);
      return { node_path: args.node_path, property: args.property, value };
    },
  });

  registerGodotSpec(client, {
    name: "read_script",
    category: "script",
    description: "Read full GDScript/C# source.",
    schema: z.object({ path: z.string() }),
    toParams: (a) => ({ path: a.path }),
  });

  registerGodotSpec(client, {
    name: "create_script",
    category: "script",
    description: "Create script; -32009 if open unless force=true.",
    schema: z.object({
      path: z.string(),
      content: z.string().optional(),
      extends: z.string().optional(),
      class_name: z.string().optional(),
      force: z.boolean().optional(),
    }),
  });

  registerGodotSpec(client, {
    name: "edit_script",
    category: "script",
    description:
      "Edit script: content, replacements[], or start_line/end_line range. force=true if open.",
    schema: z.object({
      path: z.string(),
      force: z.boolean().optional(),
      content: z.string().optional(),
      replacements: z.array(replacementSchema).optional(),
      start_line: z.number().optional(),
      end_line: z.number().optional(),
      insert_at_line: z.number().optional(),
      text: z.string().optional(),
    }),
  });

  registerGodotSpec(client, {
    name: "attach_script",
    category: "script",
    description: "Attach script to edited scene node.",
    schema: z.object({
      node_path: z.string(),
      script_path: z.string(),
    }),
  });

  registerGodotSpec(client, {
    name: "validate_script",
    category: "script",
    description: "GDScript syntax check without running game.",
    schema: z.object({ path: z.string() }),
  });

  registerGodotSpec(client, {
    name: "execute_editor_script",
    category: "editor",
    description:
      "Run GDScript in the editor (@tool context). Returns captured print output. File/resource writes are blocked unless allow_unsafe_editor_io=true (-32009 conflict if unsafe APIs detected). Required: code.",
    schema: z.object({
      code: z.string().describe("GDScript body to run inside the editor wrapper"),
      allow_unsafe_editor_io: z
        .boolean()
        .optional()
        .describe("Allow FileAccess/ResourceSaver/DirAccess writes (dangerous)"),
    }),
  });
}

export function registerCaptureFramesTool(client: GodotClient): void {
  registerTool(client, {
    name: "capture_frames",
    description:
      "Capture multiple PNG frames from the running game. Params: count, frame_interval, half_resolution. Returns up to 5 MCP image blocks plus JSON.",
    schema: z.object({
      count: z.number().optional().describe("Frames to capture (1-30)"),
      frame_interval: z.number().optional().describe("Frames between captures"),
      half_resolution: z.boolean().optional().describe("Half-res captures"),
    }),
    handler: async (c, args) =>
      callGodot(c, "capture_frames", args as Record<string, unknown>),
    formatResult: formatCaptureFramesContent,
  });
  setToolCategory("capture_frames", "runtime");
}

export function registerAllGodotTools(client: GodotClient): void {
  registerSpecialTools(client);
  registerCatalogTools(client);
  registerCaptureFramesTool(client);
}
