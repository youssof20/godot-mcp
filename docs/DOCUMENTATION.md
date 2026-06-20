# Documentation

Complete reference for **godot-mcp** — an MCP server that connects external clients to the Godot 4 editor.

Repo: https://github.com/youssof20/godot-mcp

---

## Overview

godot-mcp exposes **172 tools** for reading and editing Godot projects. A Node.js process speaks MCP over stdio; a Godot editor plugin listens on WebSocket and executes tools against the open project.

```
MCP client  →  TypeScript server (stdio)  →  WebSocket (6505)  →  Godot editor plugin
```

Requirements:

- Godot **4.4+** (tested on 4.7)
- Node.js **18+**
- Any MCP-compatible client (Cursor, Claude Desktop, custom scripts, etc.)

The editor must be **open** with the plugin enabled. Tools operate on the edited scene and `res://` filesystem — not a headless Godot process.

---

## Installation

See [README.md](../README.md) for clone, build, plugin enable, and MCP config.

**Important:** The Godot addon and the Node MCP server are separate. The addon goes in your game project; the Node server stays in one godot-mcp repo clone and is referenced from Cursor's MCP config.

Quick checklist:

1. Clone godot-mcp somewhere on disk → `npm install && npm run build`
2. Copy `addons/godot_mcp_personal/` into your Godot project's `addons/`
3. Enable **Project → Plugins → Godot MCP** (Godot must show WebSocket listening on 6505)
4. In Cursor MCP config, set `args` to the **absolute path** to that clone's `dist/index.js`
5. Set `GODOT_MCP_MODE=full` unless you want a reduced tool set

After code changes: reload the Godot project, rebuild TypeScript, restart the MCP server.

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_MCP_PORT` | `6505` | WebSocket port (Godot plugin and Node server must match) |
| `GODOT_MCP_MODE` | `full` | Tool registration mode (see below) |
| `GODOT_MCP_TIMEOUT_MS` | `30000` | Per-tool call timeout |
| `ALLOW_GODOT_MCP_DANGEROUS` | unset | Set to `1` to allow gated dangerous tools |

### Tool modes

| Mode | Tools | Use case |
|------|-------|----------|
| `full` | 172 | Default — all implemented tools |
| `lite` | 169 | Excludes `export_project`, `execute_editor_script`, `execute_game_script`, `run_stress_test` |
| `minimal` | 13 | Core read/save + `get_editor_state` |

Only tools that are implemented **and** enabled by the current mode appear in the MCP client. The Godot plugin always implements all 153; the TypeScript server filters what it registers.

---

## Tool discovery

| Tool | Description |
|------|-------------|
| `godot_ping` | Health check — Godot version, project name, uptime |
| `list_available_tools` | All tools wired on the Godot side |
| `get_tool_help` | Help for one tool (`tool` param) or all tools if omitted |
| `get_connection_status` | Connection state from both TypeScript and Godot |

**Authoritative list:** always use `list_available_tools`. Tools not in that list are not available, regardless of older docs or plans.

Full catalog: [TOOL_MATRIX.md](TOOL_MATRIX.md)

---

## Common workflows

### Inspect a project

```
get_project_info
get_filesystem_tree
get_scene_tree          # edited scene, or pass scene_path
get_node_properties
```

Read-only tools accept `scene_path` to load a `.tscn` without opening it in the editor.

### Edit scenes

Mutations use Godot **undo/redo** where supported.

```
open_scene
add_node / update_property / connect_signal / rename_node
save_scene
```

Node paths are **scene-relative** (e.g. `Player/Sprite2D`), not full editor tree paths.

### Scripts

```
list_scripts
read_script
create_script / edit_script
attach_script
validate_script
search_in_files
```

All script paths must be under `res://`.

### Play mode

```
play_scene
get_runtime_status
get_game_scene_tree
get_game_node_properties
stop_scene
```

Runtime-only tools fail with `RUNTIME_NOT_RUNNING` when the scene is not playing.

### Resources & autoloads

```
read_resource / edit_resource / create_resource
add_autoload / remove_autoload / get_autoload
```

### Input simulation

```
simulate_key / simulate_mouse_click / simulate_action / simulate_sequence
get_input_actions / set_input_action
```

Requires play mode for in-game input; editor-focused tools work in the editor.

### Screenshots & testing

```
get_editor_screenshot / get_game_screenshot
compare_screenshots
run_test_scenario / assert_node_state / get_test_report
```

Screenshots can be saved under `user://mcp_captures/`.

### Animation, TileMap, 3D, physics, audio, theme, shaders

See [TOOL_MATRIX.md](TOOL_MATRIX.md) for the full list by category. Examples:

- Animation: `create_animation`, `add_animation_track`, `create_animation_tree`
- TileMap: `tilemap_set_cell`, `tilemap_get_used_cells` (Godot 4.3+ `TileMapLayer`)
- 3D: `add_mesh_instance`, `setup_camera_3d`, `setup_environment`
- Physics: `setup_physics_body`, `setup_collision`, `add_raycast`
- Export: `list_export_presets`, `export_project`, `get_export_info`

---

## Wire protocol

MCP clients call TypeScript tools; TypeScript forwards JSON over WebSocket to Godot.

**Request:** `{ "id", "method", "params" }`  
**Success:** `{ "id", "ok": true, "result" }`  
**Error:** `{ "id", "ok": false, "error": { "code", "message", "suggestion?" } }`

Details: [PROTOCOL.md](PROTOCOL.md)

---

## Error codes

| Code | Meaning |
|------|---------|
| `GODOT_NOT_CONNECTED` | Editor closed or plugin disabled |
| `NOT_FOUND` | Scene, node, script, or file missing |
| `INVALID_PARAMS` | Bad or missing arguments |
| `ALREADY_EXISTS` | Create target already exists |
| `RUNTIME_NOT_RUNNING` | Need `play_scene` first |
| `DANGEROUS_TOOL_DISABLED` | Set `ALLOW_GODOT_MCP_DANGEROUS=1` |
| `NOT_IMPLEMENTED` | Tool not wired end-to-end |
| `GODOT_API_ERROR` | Godot API call failed |
| `SCENE_ERROR` | Scene load/save failure |

Always check `ok` in responses.

---

## Paths & conventions

- **Project files:** `res://` (e.g. `res://scenes/main.tscn`)
- **Captures:** `user://mcp_captures/` for saved screenshots
- **UIDs:** `uid_to_project_path` / `project_path_to_uid`
- **Godot 4.7 notes:** `TileMapLayer` (not monolithic TileMap), `AnimationNodeStateMachine.get_node_list()`, `GradientTexture1D` for particle color ramps — see [GODOT_API_NOTES.md](GODOT_API_NOTES.md)

---

## Testing

```powershell
npm run test:tools       # tool count
npm run test:ping
npm run test:phase3      # … through phase10
npm run test:ci          # build + typecheck
```

Godot must be running with the plugin enabled for WebSocket smoke tests.

Full checklist: [TESTING.md](TESTING.md)

---

## Repository layout

```
src/                          TypeScript MCP server
  index.ts                    Entry point (stdio MCP)
  godotClient.ts              WebSocket client
  toolRegistry.ts             Tool registration + modes
  tools/                      Zod schemas per category

addons/godot_mcp_personal/    Godot 4 editor plugin
  plugin.gd                   Plugin entry
  websocket_server.gd           WebSocket listener
  tool_router.gd              Routes methods to handlers
  tools/                      GDScript tool implementations

docs/                         Documentation
scripts/                      Smoke tests
.github/workflows/ci.yml      CI (build + typecheck)
```

---

## Adding a tool

1. Implement handler in `addons/godot_mcp_personal/tools/*.gd`
2. Add to `IMPLEMENTED_TOOLS` and `route()` in `tool_router.gd`
3. Add Zod schema and registration in `src/tools/*.ts`
4. Add name to `IMPLEMENTED_TOOLS` in `src/tools/constants.ts`
5. `npm run build`, reload Godot, restart MCP server
6. Add smoke coverage if appropriate

Do not register tools in MCP until they work end-to-end through Godot.

---

## Related docs

| Document | Contents |
|----------|----------|
| [TOOL_MATRIX.md](TOOL_MATRIX.md) | Every tool, phase, implementation status |
| [PROTOCOL.md](PROTOCOL.md) | WebSocket message format |
| [GODOT_API_NOTES.md](GODOT_API_NOTES.md) | Godot 4.4+ API research, version notes |
| [TESTING.md](TESTING.md) | Manual and automated testing |

---

## Roadmap (post Phase 11)

Phases **0–11 are complete** (172 tools). Remaining optional work:

| Area | Planned tools (not implemented) |
|------|----------------------------------|
| **Android / deploy** | `get_android_export_info`, `validate_android_export_setup`, `get_deploy_command` |

### Phase 11 additions (complete)

| Category | Tools |
|----------|-------|
| **AnimationTree** | `set_tree_parameter`, `add/remove_state_machine_state`, `add/remove_state_machine_transition`, `set_blend_tree_node` |
| **Batch** | `find_nodes_by_type`, `find_signal_connections`, `batch_set_property`, `cross_scene_set_property` |
| **Editor** | `get_open_scripts`, `set_project_setting`, `reload_plugin`, `clear_output`, `add_scene_instance` |
| **Dangerous** | `execute_editor_script`, `execute_game_script` (Expression/block modes) |
| **QoL** | `get_editor_state`, `get_selected_nodes`, `list_node_types` |

Confirm availability with `list_available_tools` before use.

---

## License

MIT
