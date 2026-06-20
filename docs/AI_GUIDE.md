# AI assistant guide (Cursor, Claude, etc.)

This document helps AI coding agents use **godot-mcp** effectively with Godot 4 projects.

## What this is

```
Your MCP client  →  Node.js server (stdio)  →  WebSocket  →  Godot editor plugin
```

- The **Godot editor must be open** with the plugin enabled.
- Tools talk to the **edited scene** and project on disk — not a headless engine.
- **153 tools** are implemented end-to-end. If a tool is not in `list_available_tools`, it does not exist yet.

## Before you call tools

1. Godot 4.4+ running with **Project → Plugins → Godot MCP** enabled.
2. Output shows: `[godot-mcp] WebSocket server listening on ws://127.0.0.1:6505`
3. MCP server built: `npm run build` in the repo root.
4. After plugin or server code changes: reload Godot project and restart the MCP server.

## Discover tools

| Tool | Use |
|------|-----|
| `godot_ping` | Check Godot is reachable |
| `list_available_tools` | Full list of working tools (153) |
| `get_tool_help` | Metadata for one tool, or all if `tool` omitted |
| `get_connection_status` | WebSocket / client status |

Always prefer `list_available_tools` over guessing tool names from old docs.

## Common workflows

### Inspect project

```
get_project_info → get_filesystem_tree → get_scene_tree
```

Use `scene_path` on read-only tools to inspect a `.tscn` without opening it.

### Edit scene (uses undo/redo)

```
open_scene → add_node / update_property / connect_signal → save_scene
```

Node paths are **scene-relative** (e.g. `Player/Sprite2D`), not absolute editor paths.

### Scripts

```
list_scripts → read_script → create_script / edit_script → attach_script → validate_script
```

Paths must be under `res://`.

### Play mode / runtime

```
play_scene → get_game_scene_tree / get_game_node_properties → stop_scene
```

Runtime tools only work while the scene is playing.

### Screenshots & QA

```
get_editor_screenshot → compare_screenshots
run_test_scenario → get_test_report
```

### 3D / physics / tilemap / animation

See [TOOL_MATRIX.md](TOOL_MATRIX.md) for categories. Examples: `add_mesh_instance`, `setup_physics_body`, `tilemap_set_cell`, `create_animation`.

## Tool modes (MCP env)

| `GODOT_MCP_MODE` | Count | Notes |
|------------------|-------|--------|
| `full` (default) | 153 | All working tools |
| `lite` | 150 | No export / stress / dangerous |
| `minimal` | 12 | Read-only essentials |

## Errors

Responses use `{ ok: false, error: { code, message, suggestion? } }`.

| Code | Meaning |
|------|---------|
| `GODOT_NOT_CONNECTED` | Editor closed or plugin off |
| `NOT_FOUND` | Scene/node/script missing |
| `INVALID_PARAMS` | Fix arguments |
| `RUNTIME_NOT_RUNNING` | Call `play_scene` first |
| `DANGEROUS_TOOL_DISABLED` | Set `ALLOW_GODOT_MCP_DANGEROUS=1` |
| `NOT_IMPLEMENTED` | Tool not wired — do not retry |

## Rules for agents

1. **Do not invent tools** — only call names from `list_available_tools`.
2. **Do not assume success** — check `ok` in responses.
3. **Open a scene** before node/scene mutations (`open_scene` or `create_scene`).
4. **Use `res://` paths** for files; captures save to `user://mcp_captures/`.
5. **Godot 4.7+** uses `TileMapLayer`, `get_node_list()` on AnimationTree state machines, `GradientTexture1D` for particle color ramps.
6. **`execute_game_script`** is blocked unless dangerous mode is on — and still returns NOT_IMPLEMENTED (no debugger bridge yet).

## Architecture & protocol

- [PROTOCOL.md](PROTOCOL.md) — WebSocket JSON format, error codes
- [GODOT_API_NOTES.md](GODOT_API_NOTES.md) — Godot 4.4+ API notes, version-sensitive areas
- [TOOL_MATRIX.md](TOOL_MATRIX.md) — Every tool, phase, status
- [TESTING.md](TESTING.md) — Smoke tests and manual checklist

## Not implemented yet (do not call)

These appear in planning docs but are **not** registered in MCP:

- `execute_editor_script`, `execute_game_script` (runtime debugger)
- AnimationTree editing: `set_tree_parameter`, `add_state_machine_state`, blend tree tools
- Batch: `find_nodes_by_type`, `batch_set_property`, `cross_scene_set_property`
- `set_project_setting`, `get_open_scripts`, `clear_output`, `reload_plugin`, `add_scene_instance`
- Android: `get_android_export_info`, `validate_android_export_setup`, `get_deploy_command`

Use `get_tool_help` or `list_available_tools` to confirm before implementing client logic.

## Repo layout

```
src/                          TypeScript MCP server
addons/godot_mcp_personal/    Godot plugin (WebSocket + tool router)
scripts/smoke-*.mjs           Phase smoke tests
```

## Adding a new tool (contributors)

1. Implement handler in `addons/godot_mcp_personal/tools/*.gd`
2. Register in `tool_router.gd` `IMPLEMENTED_TOOLS` + `route()`
3. Add Zod schema + registration in `src/tools/*.ts`
4. Add to `IMPLEMENTED_TOOLS` in `src/tools/constants.ts`
5. `npm run build` — tool appears only after Godot reload + MCP restart
