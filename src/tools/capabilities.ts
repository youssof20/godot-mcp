import { z } from "zod";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { GodotClient } from "../godot-client.js";
import { registerTool } from "./helpers.js";
import { setToolCategory } from "./spec.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

const CAN_DO = [
  "Read live editor scene tree (names, types, paths) via get_scene_tree",
  "Translate 3D spatial layout to plain English via describe_scene action:spatial_3d or get_spatial_map",
  "Translate 2D positions, z-index, layers to plain English via describe_scene action:spatial_2d",
  "Outline UI hierarchy + anchors via describe_scene action:ui_outline",
  "Describe TileMap as coordinate ranges via describe_scene action:tilemap_grid",
  "Read animation state (playing animation, position, speed) via describe_scene action:animation_state",
  "List asset inventory (counts and sizes by extension) via describe_scene action:asset_inventory",
  "Diff scene tree against a prior snapshot via describe_scene action:scene_diff",
  "Read @export values incl. inspector overrides via get_export_values",
  "Walk the signal graph via get_signal_graph",
  "Detect Godot 3 → Godot 4 syntax issues via validate_godot4_api",
  "Run a scene and sample node properties via watch_game_state",
  "Edit GDScript files via edit_script (full file, ranges, replacements)",
  "Add/move/delete/rename nodes and set undoable properties via add_node, move_node, update_property",
  "Open/save/create scene files via open_scene, save_scene, create_scene",
  "Simulate keyboard, mouse, and InputMap actions in the running game",
  "Capture editor or running-game screenshots",
  "List all registered MCP tools and their categories via list_available_tools",
  "Read full MCP activity log (every prior tool call) via get_mcp_activity_log",
  "Auto-run validate_script + Godot 4 API scan + get_editor_errors after edit_script, create_script, update_property (post_edit_validation in response)",
  "Look up Godot 4 ClassDB API via get_class_doc",
  "Persist facts across chat resets via set_project_memory / get_project_memory (user://mcp_project_memory.json)",
  "Review this MCP session via get_recent_changes; detect loops via flag_chat_health",
];

const CANNOT_DO = [
  "Generate audio files (.wav, .ogg, .mp3) — ask the user to provide audio assets",
  "Generate textures, sprites, or images — can only read existing files",
  "Generate 3D meshes from scratch — only CSG primitives and imported .gltf/.glb",
  "Author Shader Graph visually — text .gdshader edits only",
  "Judge game feel, juice, art direction, or audio mix quality — subjective, requires playtesting",
  "Click like a human player (timing, readability) — only mechanical input simulation",
  "Edit scene files while open in editor without force=true — refuses with -32009",
  "Replace user playtesting — can report objective state only (positions, velocity, errors)",
];

const CAVEATS = [
  "Screenshots are unreliable for small UI text and low-contrast scenes — prefer describe_scene first",
  "watch_game_state needs the runtime autoload services (mcp_*_service.gd) installed in the game project",
  "play_scene needs a Main Scene set in Project Settings, an open .tscn tab, or an explicit res:// path",
  "execute_editor_script can write files only with allow_unsafe_editor_io=true",
];

const WORKFLOW = [
  "1. list_available_tools — confirm tool exists",
  "2. get_capabilities — load this list",
  "3. initialize_session — project info + scene tree + errors + script counts",
  "4. describe_scene with the right action — read whatever matters",
  "5. Plan, then edit",
  "6. watch_game_state after physics/movement; get_mcp_activity_log errors_only:true after any failure",
  "7. Ask the user for assets — do not pretend to author audio, textures, or meshes",
];

function readCapabilitiesMarkdown(): string | undefined {
  const candidates = [
    resolve(__dirname, "..", "..", "..", "CAPABILITIES.md"),
    resolve(__dirname, "..", "..", "CAPABILITIES.md"),
    resolve(process.cwd(), "CAPABILITIES.md"),
  ];
  for (const path of candidates) {
    try {
      return readFileSync(path, "utf8");
    } catch {
      // try next
    }
  }
  return undefined;
}

export function registerCapabilitiesTool(client: GodotClient): void {
  registerTool(client, {
    name: "get_capabilities",
    description:
      "Returns what godot-mcp-local CAN and CANNOT do, with the recommended session workflow. Call this once per session before any edits so Cursor knows its limits (no audio gen, no texture gen, no mesh authoring, etc.).",
    schema: z.object({
      include_markdown: z
        .boolean()
        .optional()
        .describe("Include the full CAPABILITIES.md text (default false)"),
    }),
    handler: async (_c, args) => {
      const result: Record<string, unknown> = {
        can_do: CAN_DO,
        cannot_do: CANNOT_DO,
        caveats: CAVEATS,
        workflow: WORKFLOW,
        plain_english:
          `This MCP is a translation layer for Godot scenes, not an asset pipeline. ` +
          `It can do ${CAN_DO.length} things (read scene state, edit nodes/scripts, drive runtime). ` +
          `It cannot do ${CANNOT_DO.length} things — most importantly: generate audio, textures, or 3D meshes from scratch. ` +
          `Follow the ${WORKFLOW.length}-step workflow and ask the user for any binary assets.`,
      };

      if (args.include_markdown) {
        const md = readCapabilitiesMarkdown();
        if (md) {
          result.capabilities_markdown = md;
        }
      }

      return result;
    },
  });
  setToolCategory("get_capabilities", "project");
}
