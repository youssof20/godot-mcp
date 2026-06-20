# godot-mcp

**Godot 4 MCP** bridge — TypeScript MCP server over stdio, WebSocket JSON to a Godot 4.4+ editor plugin. Works with Cursor and any MCP client.

Repository: https://github.com/youssof20/godot-mcp

## Architecture

```
MCP client (Cursor, etc.)
    ↔ stdio (@modelcontextprotocol/sdk)
TypeScript MCP server (this repo)
    ↔ WebSocket JSON (ws://127.0.0.1:6505)
Godot 4 editor plugin (addons/godot_mcp_personal)
    ↔ EditorPlugin / Godot APIs
```

See [docs/PROTOCOL.md](docs/PROTOCOL.md) and [docs/GODOT_API_NOTES.md](docs/GODOT_API_NOTES.md).

## Status — Phase 10 complete

**153 working tools** across project/scene/node/script editing, runtime, input, QA, animation, tilemap, physics, 3D, particles, navigation, audio, theme, shaders, export, analysis, and `get_tool_help`.

| Mode | Tools | Env |
|------|-------|-----|
| `minimal` | 12 core read/save tools | `GODOT_MCP_MODE=minimal` |
| `lite` | 150 (excludes export/stress/dangerous) | `GODOT_MCP_MODE=lite` |
| `full` | 153 (default) | `GODOT_MCP_MODE=full` |

## Requirements

- **Node.js 18+**
- **Godot 4.4+** (tested on 4.7)
- MCP client with stdio support

## Quick start

### 1. Install and build

```powershell
git clone https://github.com/youssof20/godot-mcp.git
cd godot-mcp
npm install
npm run build
```

### 2. Enable the Godot plugin

Copy `addons/godot_mcp_personal/` into your project, **or** open this repo as a Godot project.

Enable: **Project → Project Settings → Plugins → Godot MCP**

Confirm Output:

```
[godot-mcp] WebSocket server listening on ws://127.0.0.1:6505
```

### 3. Configure MCP

This repo includes [`.cursor/mcp.json`](.cursor/mcp.json):

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["<path-to-repo>/dist/index.js"],
      "env": { "GODOT_MCP_MODE": "full" }
    }
  }
}
```

After code changes: **reload Godot project** → **`npm run build`** → **restart MCP server**.

Verify:

```powershell
npm run test:tools    # expect count: 153
npm run test:phase10
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_MCP_PORT` | `6505` | WebSocket port |
| `GODOT_MCP_MODE` | `full` | `minimal` \| `lite` \| `full` |
| `GODOT_MCP_TIMEOUT_MS` | `30000` | Tool call timeout |
| `ALLOW_GODOT_MCP_DANGEROUS` | unset | Set `1` for dangerous tools |

## CI

GitHub Actions runs `npm ci`, `build`, and `typecheck` on push/PR to `main`.

## Repository layout

```
src/                         TypeScript MCP server
addons/godot_mcp_personal/   Godot editor plugin
docs/                        Protocol, tool matrix, testing
scripts/                     Smoke tests (phase3–phase10)
.github/workflows/ci.yml     CI pipeline
```

## Principles

- Every exported tool works end-to-end through Godot
- Mutations use undo/redo where possible
- Dangerous tools gated by `ALLOW_GODOT_MCP_DANGEROUS=1`

## License

MIT — use freely in your projects.
