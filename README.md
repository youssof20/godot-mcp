# godot-mcp

MCP server for **Godot 4** — connect external clients to the open editor to read and edit projects.

**172 tools** · Godot 4.4+ · Node.js 18+

Repo: https://github.com/youssof20/godot-mcp

**Documentation:** [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md)

## Setup

godot-mcp is **two parts**:

| Part | Where it lives | What it does |
|------|----------------|--------------|
| **Godot plugin** | `addons/godot_mcp_personal/` inside **each** Godot project | WebSocket server in the editor |
| **Node MCP server** | One clone of this repo **anywhere** on disk | Talks to Cursor over stdio, forwards to Godot |

Copying only the addon into a project is not enough — Cursor must run the built Node server from a separate clone.

### 1. Clone and build the Node server (once)

```powershell
git clone https://github.com/youssof20/godot-mcp.git
cd godot-mcp
npm install
npm run build
```

Confirm this file exists (use your real path):

```powershell
Test-Path C:\dev\godot-mcp\dist\index.js   # should be True (use your clone path)
```

### 2. Add the plugin to your Godot project

Copy `addons/godot_mcp_personal/` into **your game's** `addons/` folder (or symlink it).

In Godot: **Project → Plugins → Godot MCP → Enable**

Confirm in the Output panel:

```
[godot-mcp] WebSocket server listening on ws://127.0.0.1:6505
```

### 3. Configure Cursor MCP (not inside the Godot project)

Edit **Cursor Settings → MCP** or your project's `.cursor/mcp.json`.

Replace the path below with the **absolute path** to `dist/index.js` from step 1 — not a placeholder, not a path inside your game project:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["C:/dev/godot-mcp/dist/index.js"],
      "env": {
        "GODOT_MCP_PORT": "6505",
        "GODOT_MCP_MODE": "full"
      }
    }
  }
}
```

Use forward slashes or escaped backslashes on Windows. The path must point at the repo where you ran `npm run build`.

Restart the MCP server in Cursor after saving.

### Troubleshooting

| Error | Fix |
|-------|-----|
| `Cannot find module ... dist/index.js` | Wrong path in `mcp.json` — use absolute path to built repo; run `npm run build` |
| `GODOT_NOT_CONNECTED` | Godot not open, or plugin disabled, or wrong port |
| Stale tool count | Reload Godot project, `npm run build`, restart MCP server |

After updates: reload Godot → `npm run build` → restart MCP server.

## Verify

```powershell
npm run test:tools    # 172 tools
npm run test:phase11
```

## Docs

| Doc | Purpose |
|-----|---------|
| [DOCUMENTATION.md](docs/DOCUMENTATION.md) | Full project documentation |
| [TOOL_MATRIX.md](docs/TOOL_MATRIX.md) | All tools and status |
| [PROTOCOL.md](docs/PROTOCOL.md) | WebSocket wire format |
| [TESTING.md](docs/TESTING.md) | Smoke tests |

## Env vars

| Variable | Default |
|----------|---------|
| `GODOT_MCP_PORT` | `6505` |
| `GODOT_MCP_MODE` | `full` (`minimal` / `lite` / `full`) |
| `ALLOW_GODOT_MCP_DANGEROUS` | off |

## Status

Phases 0–11 complete. See [DOCUMENTATION.md — Roadmap](docs/DOCUMENTATION.md#roadmap-post-phase-11) for optional next work.

MIT
