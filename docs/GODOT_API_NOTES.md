# Godot API Notes (Phase 0)

Research notes for **Godot 4.4+** APIs used by godot-mcp-personal.  
Official docs base: https://docs.godotengine.org/en/stable/

> **Rule:** Before implementing a tool, verify the method exists in 4.4+ docs. Isolate version-sensitive calls behind helpers and add an inline comment naming the API assumption.

---

## Plugin & Bridge (Phase 1 — in use)

| Class / Topic | Docs | Usage |
|---------------|------|--------|
| `EditorPlugin` | [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html) | Plugin lifecycle `_enter_tree` / `_exit_tree` |
| `EditorInterface` | [EditorInterface](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html) | Editor scene tree, selection, play/stop (Phase 3+) |
| `TCPServer` | [TCPServer](https://docs.godotengine.org/en/stable/classes/class_tcpserver.html) | Accept TCP connections for WebSocket upgrade |
| `WebSocketPeer` | [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html) | `accept_stream()`, `poll()`, `send_text()`, `get_packet()` |
| WebSocket tutorial | [WebSocket](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html) | Server pattern with `TCPServer` + `WebSocketPeer` |
| `Engine` | [Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html) | `get_version_info()`, `is_editor_hint()` |
| `ProjectSettings` | [ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html) | Project name, settings, autoloads |
| `JSON` | [JSON](https://docs.godotengine.org/en/stable/classes/class_json.html) | `parse_string()`, `stringify()` |
| `OS` | [OS](https://docs.godotengine.org/en/stable/classes/class_os.html) | `get_environment("GODOT_MCP_PORT")` |

**Version notes:** WebSocket server uses plain TCP on `127.0.0.1` only. Not available in Web export (not relevant for editor plugin).

---

## Project Tools (Phase 2)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `ProjectSettings` | [ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html) | Read/write `project.godot` settings |
| `DirAccess` | [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html) | Filesystem tree walk under `res://` |
| `ResourceUID` | [ResourceUID](https://docs.godotengine.org/en/stable/classes/class_resourceuid.html) | UID ↔ path (Godot 4.x) |
| `EditorFileSystem` | [EditorFileSystem](https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html) | File scan, reimport triggers |

**Version-sensitive:** `ResourceUID.id_to_text()` / path lookup — verify 4.4 signatures.

---

## Scene Tools (Phase 2–3)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `PackedScene` | [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html) | Load/instantiate/save scenes |
| `EditorInterface` | [EditorInterface](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html) | `open_scene_from_path`, `save_scene`, edited scene root |
| `SceneTree` | [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) | Runtime tree introspection |
| `Node` | [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) | Hierarchy, paths, groups |

**Version-sensitive:** Godot 4.x scene unique node names (%Name) in saved `.tscn`.

---

## Node & Undo (Phase 3)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `EditorUndoRedoManager` | [EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html) | All mutating editor ops |
| `Control` | [Control](https://docs.godotengine.org/en/stable/classes/class_control.html) | Anchor presets (UI) |
| `Node` property APIs | [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) | `set()`, `get()`, signals |

**Rule:** Prefer `EditorPlugin.get_undo_redo()` (wrapping `EditorUndoRedoManager`) for add/delete/move/property changes.

---

## Script Tools (Phase 2–3)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `Script` / `GDScript` | [Script](https://docs.godotengine.org/en/stable/classes/class_script.html) | Create, attach, validate |
| `EditorInterface` | — | Open scripts, get open script list |
| `FileAccess` | [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) | Read/write script files under `res://` |

---

## Editor, Output, Screenshots (Phase 2, 6)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `EditorLog` / debugger | Editor debugging docs | Errors and output log |
| `SubViewport` / `Viewport` | [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html) | Screenshots via `get_texture().get_image()` |
| `DisplayServer` | [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) | Window capture (fallback) |

**Dangerous:** `execute_editor_script` — runs arbitrary GDScript in editor context. Requires `ALLOW_GODOT_MCP_DANGEROUS=1`.

---

## Input (Phase 5)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `Input` | [Input](https://docs.godotengine.org/en/stable/classes/class_input.html) | Action simulation |
| `InputEventKey` / `Mouse` | Input event classes | Synthetic events |
| `ProjectSettings` input map | InputMap docs | Read/write input actions |

**Version-sensitive:** Input simulation in editor vs running game differs; runtime tools require play mode.

---

## Runtime (Phase 5)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `SceneTree` | [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) | Game tree while running |
| `EditorInterface` | — | `play_main_scene`, `stop_playing_scene` |
| `@GlobalScope` `call_deferred` | — | Thread-safe runtime queries |

**Dangerous:** `execute_game_script` — arbitrary code in running game. Requires `ALLOW_GODOT_MCP_DANGEROUS=1`.

---

## Animation & AnimationTree (Phase 7)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `AnimationPlayer` | [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html) | CRUD animations/tracks/keys |
| `Animation` | [Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html) | Track data |
| `AnimationTree` | [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html) | State machine / blend tree |
| `AnimationNodeStateMachine` | State machine node docs | Transitions |

**Version-sensitive:** AnimationTree API changed across 4.x; verify node path and parameter APIs for 4.4+.

---

## TileMap (Phase 7)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `TileMapLayer` | [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html) | Godot 4.3+ layered TileMap (4.4+ target) |
| `TileSet` | [TileSet](https://docs.godotengine.org/en/stable/classes/class_tileset.html) | Tile source info |

**Version-sensitive:** Godot 4.x replaced monolithic `TileMap` with `TileMapLayer` nodes — do not use deprecated 3.x TileMap-only APIs.

---

## Theme & UI (Phase 9)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `Theme` | [Theme](https://docs.godotengine.org/en/stable/classes/class_theme.html) | Colors, constants, fonts, StyleBoxes |
| `Control` | [Control](https://docs.godotengine.org/en/stable/classes/class_control.html) | Theme assignment |

---

## Profiling (Phase 9)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `Performance` | [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) | Monitor enums and values |
| Editor profiler | Editor docs | Editor-specific metrics (limited public API) |

---

## Shader (Phase 9)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `Shader` | [Shader](https://docs.godotengine.org/en/stable/classes/class_shader.html) | Create/edit shader code |
| `ShaderMaterial` | [ShaderMaterial](https://docs.godotengine.org/en/stable/classes/class_shadermaterial.html) | Params assignment |

---

## Export & Deploy (Phase 9)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `EditorExportPlatform` | Export docs | Presets, export |
| `EditorInterface` | — | Export plugin hooks |

**Note:** `export_project` may block for long periods; needs progress/timeout strategy.

---

## Resource & Autoload (Phase 4)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `Resource` | [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html) | Load/save `.tres` |
| `ResourceLoader` / `ResourceSaver` | — | IO |
| `ProjectSettings` autoload list | — | add/remove autoload |

---

## Physics (Phase 8)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `RigidBody2D` / `3D` | Physics body docs | Setup bodies |
| `CollisionShape2D` / `3D` | — | Shapes |
| `PhysicsRayQueryParameters2D/3D` | — | Raycasts |
| `PhysicsServer2D/3D` | — | Layer masks |

---

## 3D Scene (Phase 8)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `MeshInstance3D` | [MeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html) | Meshes |
| `Camera3D` | [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) | Camera setup |
| `DirectionalLight3D` | — | Lighting |
| `WorldEnvironment` | — | Environment |
| `GridMap` | [GridMap](https://docs.godotengine.org/en/stable/classes/class_gridmap.html) | 3D grid maps |

---

## Particles (Phase 8)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `GPUParticles2D/3D` | Particle docs | Create/configure |
| `ParticleProcessMaterial` | — | Material params |

---

## Navigation (Phase 8)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `NavigationRegion2D/3D` | Navigation docs | Regions, bake |
| `NavigationAgent2D/3D` | — | Agents |
| `NavigationServer2D/3D` | — | Path queries |

---

## Audio (Phase 8)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| `AudioStreamPlayer` | Audio docs | Players |
| `AudioServer` | [AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) | Buses, effects |

---

## Analysis & Testing (Phase 6, 9)

| Class / Topic | Docs | Planned usage |
|---------------|------|----------------|
| Scene tree walks | `Node` recursion | Complexity, signal flow |
| `Image` | [Image](https://docs.godotengine.org/en/stable/classes/class_image.html) | Screenshot compare |
| Custom test harness | — | Scenario runner in plugin |

---

## Dangerous Tools Summary

| Tool | Risk | Gate |
|------|------|------|
| `execute_editor_script` | Arbitrary editor-side code | `ALLOW_GODOT_MCP_DANGEROUS=1` |
| `execute_game_script` | Arbitrary runtime code | `ALLOW_GODOT_MCP_DANGEROUS=1` |
| `export_project` | Long-running, writes build artifacts | Explicit params + warnings |
| `edit_script` / `edit_resource` | File mutation | Path validation under `res://` |
| `set_project_setting` | Project-wide behavior change | Undo + validation |

---

## MCP TypeScript SDK (Phase 1)

| Topic | Reference |
|-------|-----------|
| Server + stdio | `@modelcontextprotocol/sdk` — `McpServer`, `StdioServerTransport` |
| Tool registration | `server.tool(name, description, schema, handler)` |
| Schemas | Zod 3 object schemas |
| Errors | Return `{ content, isError: true }` from tool handlers |

Docs: https://github.com/modelcontextprotocol/typescript-sdk
