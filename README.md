# godot-mcp

MCP server for **Godot 4** that connects your game project editor to MCP clients over a local WebSocket. The server exposes a focused tool set and returns scene state as structured summaries so clients do not have to guess layout from file names alone.

```
MCP client  ←stdio→  godot-mcp (Node)  ←WebSocket→  Godot MCP Pro plugin (in your game project)
```

This repository is the **Node server and vendored editor plugin**. It is not a Godot game. Open your own project in Godot and install the plugin under `addons/godot_mcp/`.

## Features

- Read and edit scenes, nodes, scripts, signals, and exports from the editor
- Summarize 2D/3D layout, UI, TileMaps, animation, and assets (`describe_scene`)
- Run the game and sample runtime state (`watch_game_state`, input simulation)
- Post-edit checks on script and property changes (syntax, API patterns, Output log)
- ClassDB lookup (`get_class_doc`) and optional project notes (`project_memory`)
- Modes: full (~190 tools), **lite** (~98, default), 3D-focused, or minimal

The server does **not** generate audio, textures, meshes, or subjective "game feel" judgments. Provide those assets yourself.

## Requirements

- **Node.js** 18+
- **Godot** 4.4+ with your game project
- An MCP-capable client (e.g. Cursor, Claude Desktop, other MCP hosts)

## Quick start

### 1. Build the server

```bash
git clone https://github.com/youssof20/godot-mcp.git
cd godot-mcp
npm install
npm run build
```

Smoke test (optional):

```bash
npm start
# Expect: WebSocket listening on ws://127.0.0.1:6505
```

### 2. Install the Godot plugin

Copy the bundled addon into your game project:

**From:** `vendor/godot_mcp`  
**To:** `YourGame/addons/godot_mcp`

Confirm these runtime files exist (see `vendor/godot_mcp/REQUIRED_FILES.txt`):

- `mcp_screenshot_service.gd`
- `mcp_input_service.gd`
- `mcp_game_inspector_service.gd`

In Godot: **Project → Project Settings → Plugins** → enable **Godot MCP Pro**.

### 3. Configure your MCP client

Point the client at `build/index.js`. Example `mcp.json`:

```json
{
  "mcpServers": {
    "godot-local": {
      "command": "node",
      "args": ["/absolute/path/to/godot-mcp/build/index.js", "--lite"]
    }
  }
}
```

Use forward slashes in JSON paths on Windows. Restart the MCP server after rebuilding.

### 4. Each work session

1. Open your **game** in Godot (plugin enabled).
2. Start or reload the MCP server in your client.
3. Call `get_project_info` or `initialize_session` to verify the link.

The server waits up to 30 seconds for Godot on the first command if the editor was started later.

## MCP modes

| Flag | Approx. tools | Use case |
|------|----------------|----------|
| *(none)* | ~190 | Full command surface |
| `--lite` | ~98 | Daily use (default in sample `mcp.json`) |
| `--3d` | ~111 | Lite plus physics, navigation, animation tree |
| `--minimal` | ~45 | Small context windows |

Call `list_available_tools` to see what the current mode exposes.

## Useful tools

| Goal | Tool |
|------|------|
| Scope and limits | `get_capabilities` |
| Session bootstrap | `initialize_session` |
| Scene layout summary | `describe_scene` (see `action` parameter) |
| 3D positions | `describe_scene` / `get_spatial_map` |
| Signals before wiring | `get_signal_graph` |
| Inspector exports | `get_export_values` |
| Runtime sampling | `watch_game_state` |
| Godot 4 API reference | `get_class_doc` |
| Debug failed calls | `get_mcp_activity_log` |

After `edit_script`, `create_script`, or `update_property`, check `post_edit_validation` in the response.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Godot not connected | Godot open, plugin enabled, MCP server running; restart both |
| `get_scene_tree` fails | Open a scene tab or set **Application → Run → Main Scene** |
| Autoload errors for `mcp_*_service.gd` | Re-copy the entire `vendor/godot_mcp` folder into `addons/godot_mcp` |
| `get_game_*` fails | Press Play or use `play_scene` with a valid scene path |
| Port in use | Stop other server instances or set `GODOT_MCP_PORT=6506` |

Godot tries WebSocket ports **6505–6509**. Use the MCP panel in the editor to view activity and connected clients.

## CLI (without an MCP client)

```bash
node build/cli.js project get_project_info
```

Godot must be running with the plugin enabled.

## Versions

| Component | Version |
|-----------|---------|
| npm package `godot-mcp-local` | 2.0.0 |
| Bundled Godot MCP Pro plugin (`vendor/godot_mcp`) | 1.14.1 |

Plugin version in Godot’s plugin list is independent of the npm package version. Both share the same JSON-RPC command set.

## Architecture

- Node listens on `127.0.0.1:6505–6509`
- The Godot plugin connects outbound to Node
- JSON-RPC 2.0, 30s command timeout, ping/pong keepalive

## License

The addon in `vendor/godot_mcp` follows [godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro) licensing. This Node server is an independent implementation of the public wire protocol.
