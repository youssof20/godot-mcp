# Cursor + godot-mcp-local capabilities

What this MCP **can** and **cannot** do in a Godot 4 project. Cursor agents should call **`get_capabilities`** once per session to load this same information.

The goal is honest scope: this server is a **translation layer** so Cursor can read the scene as text. It is not an asset pipeline.

---

## ✅ Can do (high confidence)

| Area | How |
|------|-----|
| Read live editor scene tree (names, types, paths) | `get_scene_tree` (auto-opens main scene) |
| Read 3D spatial layout in plain English | `describe_scene action:spatial_3d` / `get_spatial_map` |
| Read 2D positions, Z-index, layers in plain English | `describe_scene action:spatial_2d` |
| Read UI hierarchy + anchors as outline | `describe_scene action:ui_outline` |
| Read TileMap as coordinate grid | `describe_scene action:tilemap_grid` |
| Read animation state (playing, position, speed) | `describe_scene action:animation_state` |
| List `@export` values incl. inspector overrides | `get_export_values` |
| Walk signal graph (who connects to what) | `get_signal_graph` |
| Validate Godot 3 → Godot 4 patterns in scripts | `validate_godot4_api` |
| Run scene + sample properties over time | `watch_game_state` |
| Read editor errors / Output log | `get_editor_errors`, `get_output_log` |
| Read full MCP activity log | `get_mcp_activity_log`, `save_mcp_activity_log` |
| Edit GDScript (full file, ranges, replacements) | `edit_script` |
| Add / move / delete / rename nodes | `add_node`, `move_node`, `delete_node`, `rename_node` |
| Set node properties (undoable, with Godot value parsing) | `update_property` |
| Open scene tabs, save scenes, create new scenes | `open_scene`, `save_scene`, `create_scene` |
| Connect / disconnect signals between nodes | `connect_signal`, `disconnect_signal` |
| Simulate keyboard / mouse / InputMap actions in the running game | `simulate_key`, `simulate_action`, `simulate_sequence` |
| Capture editor / game screenshots (returned as MCP image blocks) | `get_editor_screenshot`, `get_game_screenshot`, `capture_frames` |
| List & toggle every available MCP tool | `list_available_tools` |

---

## ⚠️ Can do but with caveats

| Area | Caveat |
|------|--------|
| Read screenshots | Vision models miss small UI text, low-contrast 3D, off-camera state. Prefer `describe_scene` first. |
| `watch_game_state` runtime sampling | Requires the runtime autoload services (`mcp_*_service.gd`) installed in the **game project**. Returns structured error otherwise. |
| `execute_editor_script` / `execute_game_script` | GDScript with full editor power — agent must avoid file IO unless `allow_unsafe_editor_io=true`. |
| Play scene | Needs **Main Scene** set in Project Settings, **or** a `.tscn` tab open in the editor, **or** an explicit `res://` path. Otherwise Godot pops a native dialog. |
| 3D primitives + lights + camera | `setup_camera_3d`, `setup_lighting`, `add_mesh_instance` create basic CSG / primitive nodes — not authored art. |
| Tilemap edits | Requires an existing TileSet resource. Cannot author tile art. |
| Particles | Presets only (`fire`, `smoke`, etc.); custom particle materials need manual tuning. |
| Android export | `deploy_to_android` needs Android export templates + ADB on PATH. |

---

## ❌ Cannot do (do not attempt)

| Limitation | Why |
|-----------|-----|
| **Generate audio files** (`.wav`, `.ogg`, `.mp3`) | No audio synthesis surface. Agent must ask user to provide audio. |
| **Generate textures / sprites / images** | No image-gen tool. Agent can read existing PNG/JPG but not author. |
| **Generate 3D meshes from scratch** | Only CSG primitives + import existing `.gltf` / `.glb`. No procedural mesh authoring beyond `MeshInstance3D` of primitives. |
| **Generate or tune audio mixes by ear** | Bus / effect parameters are exposed; "sounds good" is subjective and unverifiable. |
| **Author shader graphs visually** | `.gdshader` text edit only — no Shader Graph node manipulation. |
| **Judge "game feel" / juice / polish** | Subjective. Agent can observe objective state (velocity, frame timing, hitbox overlap). |
| **Inspect rendered pixels without screenshots** | `compare_screenshots` exists but cannot tell *why* something looks wrong. |
| **Click in the running game like a human** | `simulate_*` works mechanically; agent cannot reason like a player about pacing or readability. |
| **Edit `.tscn` while it's open in the editor** | Refuses with `-32009` conflict unless `force=true` (dangerous, can corrupt). |
| **Modify `project.godot` autoloads it didn't register** | `add_autoload` / `remove_autoload` only manage explicitly listed autoloads. |
| **Replace human playtesting** | No model can feel timing, weight, or readability. `watch_game_state` reports numbers; user reports feel. |
| **Guarantee deterministic gameplay** | Physics is frame-rate sensitive; sampling can miss events. |

---

## 🧭 Workflow Cursor should follow

1. **`list_available_tools`** — confirm tool exists before calling.
2. **`get_capabilities`** — load this file's content.
3. **`initialize_session`** — load project info, scene tree, errors, .gd / .tscn counts.
4. **`describe_scene`** with the right `action` — read whatever part of the scene matters (preferred over raw `get_node_properties`).
5. Plan the edit, then act.
6. **`watch_game_state`** after physics or movement changes; **`get_mcp_activity_log errors_only:true`** after any failure.
7. Read **`post_edit_validation`** after script/property edits (automatic on `edit_script` / `create_script` / `update_property`).
8. **`get_class_doc`** before guessing API names; **`set_project_memory`** for facts that must survive chat resets.
9. **`flag_chat_health`** if the agent loops — usually means start a fresh Cursor chat.
10. Ask the user for assets (audio, textures, meshes) — do not pretend to make them.

---

## Honest boundary statement

This MCP tries to make Cursor a **better-informed** game developer in Godot, not a **complete** one. It cannot replace:

- Your taste in art, sound, and game feel
- Your decisions about scope and design
- Your manual playtesting
- Your authoring of original assets

It can replace:

- Manually copy-pasting scene state and errors into chat
- Guessing at node positions from filenames
- Re-checking inspector overrides after every edit
- Polling for "did the player land yet?" by eye

Use it as a translation layer, not an oracle.
