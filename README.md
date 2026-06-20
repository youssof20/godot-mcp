# godot-mcp

MCP server for **Godot 4** — lets AI assistants (Cursor, Claude, etc.) read and edit your project through the open editor.

**153 tools** · Godot 4.4+ · Node.js 18+

Repo: https://github.com/youssof20/godot-mcp

**Full guide for AI agents:** [docs/AI_GUIDE.md](docs/AI_GUIDE.md) — architecture, workflows, error codes, tool list, and rules.

## Setup

```powershell
git clone https://github.com/youssof20/godot-mcp.git
cd godot-mcp
npm install
npm run build
```

1. Enable plugin: **Project → Plugins → Godot MCP**
2. Confirm: `[godot-mcp] WebSocket server listening on ws://127.0.0.1:6505`
3. Point your MCP client at `dist/index.js` (see [`.cursor/mcp.json`](.cursor/mcp.json))

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

After updates: reload Godot → `npm run build` → restart MCP server.

## Verify

```powershell
npm run test:tools    # 153 tools
npm run test:phase10
```

## Docs

| Doc | Purpose |
|-----|---------|
| [AI_GUIDE.md](docs/AI_GUIDE.md) | **Start here** for Cursor/Claude — how to use tools correctly |
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

Phases 0–10 complete. No further planned release phases; optional future work includes AnimationTree editing, batch refactor tools, and runtime script execution.

MIT
