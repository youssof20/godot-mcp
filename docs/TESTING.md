# Testing Guide

Manual test checklist per phase. **Do not advance phases until you confirm the current phase passes.**

---

## Prerequisites

1. **Node.js 18+** installed
2. **Godot 4.4+** installed
3. This repository cloned somewhere on disk (e.g. `C:\dev\godot-mcp`)

---

## Phase 1 — End-to-end skeleton

### 1. Build TypeScript server

```powershell
cd C:\dev\godot-mcp
npm install
npm run build
```

Expected: `dist/` folder created with no TypeScript errors.

### 2. Set up a Godot test project

You need **any** Godot 4.4+ project. Options:

**Option A — New empty project (recommended for first test)**

1. Open Godot 4.4+
2. **New Project** → name it `mcp-test` → create
3. Copy the addon into the project:
   ```powershell
   xcopy /E /I "C:\dev\godot-mcp\addons\godot_mcp_personal" "C:\dev\my-game\addons\godot_mcp_personal"
   ```
   Or symlink the addon if you prefer developing in-place.

**Option B — Use this repo as project root**

1. In Godot: **Import** → select `C:\dev\godot-mcp`
2. Godot will create/import `project.godot` if missing (you may need to create one manually)

### 3. Enable the plugin

1. **Project → Project Settings → Plugins**
2. Enable **Godot MCP Personal**
3. Open **Output** panel (bottom)

Expected Output lines:

```
[godot-mcp] Plugin enabled
[godot-mcp] WebSocket server listening on ws://127.0.0.1:6505
```

If port is in use, set environment variable before launching Godot:

```powershell
$env:GODOT_MCP_PORT = "6506"
```

And match it in MCP config (see below).

### 4. Configure Cursor MCP

Copy `.mcp.example.json` content into your Cursor MCP settings (or merge):

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["C:/dev/godot-mcp/dist/index.js"],
      "env": {
        "GODOT_MCP_PORT": "6505"
      }
    }
  }
}
```

Use forward slashes in paths. Restart Cursor or reload MCP servers.

### 5. Test `godot_ping`

In Cursor chat (with Godot open and plugin enabled):

> Use the godot_ping tool

**Pass criteria:**

- Response contains `"pong": true`
- `godot_version` matches your editor (e.g. `4.4.x`)
- `project_name` matches your test project
- **Not** a fake/hardcoded success — values must reflect your live editor

**Fail scenarios to verify:**

- Godot closed → error code `GODOT_NOT_CONNECTED` with suggestion text
- Plugin disabled → same

### 6. Test `get_connection_status`

**Pass criteria:**

- `typescript.connected` is `true` when Godot is running
- `godot.connected_clients` ≥ 1 while MCP server is connected
- `godot.websocket_port` is 6505 (or your override)

### 7. Test `list_available_tools`

**Pass criteria:**

- Lists exactly 3 tools: `godot_ping`, `get_connection_status`, `list_available_tools`
- `typescript_registered` matches

---

## Quick WebSocket smoke test (optional)

With Godot plugin running, in PowerShell:

```powershell
# Requires Node installed — one-liner WebSocket client test
node -e "const W=require('ws');const w=new W('ws://127.0.0.1:6505');w.on('open',()=>w.send(JSON.stringify({id:'test-1',method:'godot_ping',params:{}})));w.on('message',d=>{console.log(d.toString());w.close();});"
```

Expected: JSON with `"ok":true` and `"pong":true`.

---

## Phase 2+ tests

Added in future phases — see `docs/TESTING.md` updates when each phase lands.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| `GODOT_NOT_CONNECTED` | Plugin enabled? Output shows server started? Port match? |
| Port in use | Change `GODOT_MCP_PORT` on both sides |
| MCP server not listed | Cursor MCP config path to `dist/index.js` correct? Run `npm run build` |
| Plugin errors on enable | Godot 4.4+? All addon files copied? Check **Debugger** tab |
| Empty tool list in Cursor | Reload MCP; check TS build succeeded |
