# godot-mcp-personal

Personal, clean-room **Godot 4 MCP** bridge for Cursor — TypeScript MCP server over stdio, WebSocket JSON bridge, Godot 4.4+ editor plugin.

## Architecture

```
Cursor MCP client
    ↔ stdio (@modelcontextprotocol/sdk)
TypeScript MCP server (this repo)
    ↔ WebSocket JSON (ws://127.0.0.1:6505)
Godot 4 editor plugin (addons/godot_mcp_personal)
    ↔ EditorPlugin / Godot APIs
```

See [docs/PROTOCOL.md](docs/PROTOCOL.md) and [docs/GODOT_API_NOTES.md](docs/GODOT_API_NOTES.md).

## Current status — Phase 8

**Working tools (130):** Phases 1–8 including physics, 3D scene setup, particles, navigation, and audio.

See [docs/TOOL_MATRIX.md](docs/TOOL_MATRIX.md) for the full list.

## Requirements

- **Node.js 18+**
- **Godot 4.4+**
- **Cursor** (or any MCP client with stdio support)

## Quick start

### 1. Install and build

```powershell
cd e:\Code\godot-mcp-personal
npm install
npm run build
```

### 2. Add plugin to your Godot project

Copy `addons/godot_mcp_personal/` into your project's `addons/` folder, **or** open this repo as a Godot project.

Enable: **Project → Project Settings → Plugins → Godot MCP Personal**

Confirm Output shows:

```
[godot-mcp] WebSocket server listening on ws://127.0.0.1:6505
```

### 3. Configure Cursor MCP

This repo includes [`.cursor/mcp.json`](.cursor/mcp.json) with `GODOT_MCP_MODE=full`.

If Cursor still shows **74 tools** (or any stale count):

1. Rebuild: `npm run build`
2. **Project → Reload Current Project** in Godot
3. **Cursor Settings → MCP → Restart** the `godot-mcp-personal` server
4. Confirm no duplicate godot MCP entry in user/global MCP settings without `GODOT_MCP_MODE=full`

Verify tool count:

```powershell
npm run test:tools
```

Should show `"count": 130` (or check with `npm run test:tools`).

Restart Cursor / reload MCP servers after changes.

### 4. Test from repo root (not `C:\Users\C`)

The `ws` module is installed inside this repo. Run:

```powershell
cd e:\Code\godot-mcp-personal
npm run test:ping
npm run test:project
```

After plugin code changes, **Project → Reload Current Project** in Godot, then restart the Cursor MCP server.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_MCP_PORT` | `6505` | WebSocket port (set before launching Godot too) |
| `GODOT_MCP_MODE` | `minimal` | `minimal` \| `lite` \| `full` (only working tools register today) |
| `GODOT_MCP_TIMEOUT_MS` | `30000` | Tool call timeout |
| `ALLOW_GODOT_MCP_DANGEROUS` | unset | Set to `1` to enable dangerous tools (future phases) |

## Repository layout

```
src/                    TypeScript MCP server
addons/godot_mcp_personal/   Godot editor plugin
docs/                   Protocol, API notes, tool matrix, testing
```

## Development principles

- No fake data — every exported tool must work end-to-end
- `NOT_IMPLEMENTED` tools stay out of the MCP tool list until wired
- Mutations use Godot undo/redo where possible (Phase 3+)
- Dangerous tools gated by `ALLOW_GODOT_MCP_DANGEROUS=1`

## License

Personal use — your project, your rules.
