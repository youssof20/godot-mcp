# godot-mcp-local

**Translation layer between Cursor and the Godot 4 editor.** Cursor reads your scene as text, not as guesswork. The point of this repo is **not** "expose every Godot API" — other MCPs do that and produce 162–288 tools the agent wades through. The point here is to make Cursor a better-informed Godot developer with a small, focused tool surface.

```
Cursor  ←—stdio/MCP—→  godot-mcp-local (Node, this repo)  ←—WebSocket—←  Godot MCP Pro plugin (in your game project)
```

This repo is **not** a Godot game. You do **not** open this folder as a Godot project. You open **your game project** in Godot and copy the plugin into it.

## Design principle

The MCP is a **translation layer**, not an asset pipeline. It can:

- read 2D, 2.5D, 3D, UI, TileMap, animation, physics state as plain English
- edit scenes, scripts, nodes, signals, exports
- run scenes and sample state over time

It **cannot** generate audio, textures, 3D meshes, or judge "feel". See [`CAPABILITIES.md`](CAPABILITIES.md) — the same content Cursor loads via `get_capabilities`.

---

## Version numbers (why you see “1.14”)

| Component | Version | What it means |
|-----------|---------|----------------|
| **godot-mcp-local** (npm / this server) | **2.0.0** | Our independent MCP server (`package.json`, MCP handshake). |
| **Godot MCP Pro plugin** (`vendor/godot_mcp/plugin.cfg`) | **1.14.1** | Upstream addon release we ship in `vendor/`. Same plugin family as [godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro). |
| **Wire protocol** | v1.14+ | Server and addon speak the same JSON-RPC command set. |

The plugin version is **not** our server version. Godot’s plugin list will still say “Godot MCP Pro 1.14.x” — that is expected. You are **not** running the old reference repo; you are running **`node build/index.js`** from this repo.

---

## What you need (two separate installs)

| Piece | Where it lives | Required? |
|-------|----------------|-----------|
| **Node MCP server** | This folder: `e:\Godot\MCP Tool` | Yes — `npm install` + `npm run build` |
| **Godot addon (plugin)** | **Your game project**: `YourGame/addons/godot_mcp/` | Yes — copy from `vendor/godot_mcp/` |

Opening only this repo in Cursor is fine for editing the server. **Godot must open your game project** with the plugin enabled.

---

## Install and run (step by step)

### Step 1 — Build the Node MCP server (once per machine / after code changes)

```powershell
cd "e:\Godot\MCP Tool"
npm install
npm run build
```

You should get a `build/` folder with `build/index.js`. If `npm run build` errors, fix TypeScript before continuing.

Optional smoke test (no Cursor):

```powershell
npm start
```

Leave that terminal open. You should see something like:

`[godot-mcp-local] WebSocket listening on ws://127.0.0.1:6505`

Press Ctrl+C to stop when done testing.

---

### Step 2 — Install the plugin in **your Godot game project** (once per game)

1. Open your **game** folder in File Explorer (the folder that contains `project.godot`).
2. If there is no `addons` folder, create `addons`.
3. Copy the entire folder:

   **From:** `e:\Godot\MCP Tool\vendor\godot_mcp`  
   **To:** `YourGame\addons\godot_mcp`

   After copying you should have e.g. `YourGame\addons\godot_mcp\plugin.cfg`.

3. **Verify runtime files** (incomplete copies cause startup errors):

   - `addons/godot_mcp/mcp_screenshot_service.gd`
   - `addons/godot_mcp/mcp_input_service.gd`
   - `addons/godot_mcp/mcp_game_inspector_service.gd`

   Full checklist: [`vendor/godot_mcp/REQUIRED_FILES.txt`](vendor/godot_mcp/REQUIRED_FILES.txt). If any file is missing, delete `addons/godot_mcp` in your game and copy the whole folder again.

4. Open **that game project** in Godot 4.4+ (not the MCP Tool repo).
5. **Project → Project Settings → Plugins**
6. Find **Godot MCP Pro** → set **Enable** → **Close**
7. Confirm:
   - Godot **Output** panel shows MCP started (ports 6505–6514).
   - Bottom **MCP** dock/panel shows a connection when the Node server is running (Step 4).

---

### Step 3 — Connect Cursor to the MCP server

You need Cursor to start `node build/index.js` via MCP. Use **your real paths** (Windows example below).

**Option A — Project MCP config (good if this repo is your Cursor workspace)**

1. In Cursor, open the folder `e:\Godot\MCP Tool` (or your clone path).
2. Use the repo’s [`mcp.json`](mcp.json) or create `.cursor/mcp.json` with the same content:

```json
{
  "mcpServers": {
    "godot-local": {
      "command": "node",
      "args": ["e:/Godot/MCP Tool/build/index.js"]
    }
  }
}
```

Use forward slashes in JSON paths on Windows.

**Option B — Global Cursor MCP (works for any Cursor project)**

1. **Cursor Settings → MCP** (or **Features → MCP**).
2. **Add new MCP server**
3. Name: `godot-local`
4. Command: `node`
5. Arguments (one per line or as array): `e:/Godot/MCP Tool/build/index.js`

**Lite mode** (fewer tools, smaller context):

```json
"args": ["e:/Godot/MCP Tool/build/index.js", "--lite"]
```

4. **Save** and **restart MCP** / reload the window (Cursor must spawn a fresh server process).

---

### Step 4 — Run order every session

Do this order so nothing times out on the first tool call:

1. **Start Godot** with your **game project** open (plugin enabled from Step 2).
2. **Start or reload MCP in Cursor** (so `godot-local` runs `build/index.js`).
   - In MCP settings, `godot-local` should show **running** (green / connected).
3. In Godot, check the **MCP** panel: it should show connected to `127.0.0.1:6505` (or 6506–6509 if 6505 is busy).
4. In Cursor chat, ask the agent to call a tool, e.g.:

   > Use the godot-local MCP tool `get_project_info` and show me the result.

The server **waits up to 30 seconds** for Godot on the first command if Godot was opened after Cursor.

---

## You are here: plugin on, new Cursor project — what now?

If the plugin is already enabled in Godot:

1. **Godot:** Keep your **game project** open (any scene is fine).
2. **Cursor:** Add MCP config (Step 3) if you have not already — **opening a new Cursor project does not auto-configure MCP** unless you use global MCP or add `mcp.json` in that workspace.
3. **Cursor:** Open MCP settings → confirm **`godot-local`** is listed and **enabled** → click **Restart** on that server if it exists.
4. **Terminal (optional check):**

   ```powershell
   cd "e:\Godot\MCP Tool"
   npm run build
   node build/index.js
   ```

   Then look at Godot MCP panel for “connected”.

5. **First test in Cursor chat:**

   ```
   Call list_available_tools, then initialize_session from godot-local.
   ```

   Or only:

   ```
   Call get_project_info from godot-local and paste the JSON.
   ```

   Success looks like real `godot_version`, project name, viewport size — not “Godot is not connected”.

6. **Second test** (with a scene open in Godot):

   ```
   Call get_scene_tree from godot-local.
   ```

7. If you use **Agent** mode, ensure **godot-local** tools are allowed (MCP tools toggle for the agent).

You do **not** need to open the MCP Tool repo as a Godot project. You **do** need the MCP server running via Cursor and Godot open on your **game** project.

---

## Troubleshooting

| Symptom | What to do |
|---------|------------|
| `Godot is not connected` | Godot not open, or plugin disabled, or wrong project. Enable plugin; restart Godot; restart MCP in Cursor. |
| MCP server won’t start in Cursor | Run `node build/index.js` in a terminal — read the error. Run `npm run build`. Check Node 18+: `node -v`. |
| Port in use | Close other `node build/index.js` instances. Or set env `GODOT_MCP_PORT=6506` and restart both. |
| Tools missing in Cursor | Restart MCP server; check mode flags (`--lite` exposes fewer tools). Call `list_available_tools` to see what this mode exposes. |
| `get_scene_tree` fails / “select main scene” popup | **No .tscn tab is active** in the editor, or **main scene is unset**. Open a scene in FileSystem, set **Project → Project Settings → Application → Run → Main Scene**, or call `open_scene` with a path. After updating the addon, `get_scene_tree` can auto-open the main scene (`auto_open: true`, default). |
| `get_game_*` fails | Press Play in Godot first, or use `play_scene` with a `res://` path / configured main scene (not `current` with no scene open). |
| Wrong workspace | Cursor MCP only runs the server you configured — paths in `mcp.json` must point to **this** repo’s `build/index.js`. |

### Common startup errors (Godot Output)

If Godot prints errors like these on project load:

```
load_source_code: Attempt to open script 'res://addons/godot_mcp/mcp_screenshot_service.gd' resulted in error 'File not found'.
start: Failed to instantiate an autoload, can't load from path: res://addons/godot_mcp/mcp_screenshot_service.gd.
```

(and the same pattern for `mcp_input_service.gd` or `mcp_game_inspector_service.gd`)

**Cause:** The plugin registered autoloads in `project.godot`, but the three runtime `.gd` files were not copied into your game’s `addons/godot_mcp/` folder (partial copy or old addon folder).

**Fix:** Re-copy the **entire** `vendor/godot_mcp` folder from this repo into your game’s `addons/godot_mcp`, confirm the three files exist, restart Godot. Runtime tools (`watch_game_state`, `get_game_scene_tree`, screenshots) will not work until these autoloads load.

### Debugging MCP traffic

- In Godot, open the bottom **MCP Pro** panel → **Activity** tab:
  - **Full JSON** / **Params** toggles for request/response detail
  - **Copy All**, **Copy Errors**, **Save** (`user://mcp_activity_log.txt`), per-row **Copy**
  - Each line shows port, duration (ms), and error message when a tool fails
- **Clients** tab shows which WebSocket port each Cursor window uses (6505–6509).
- From Cursor, call **`get_mcp_activity_log`** (`errors_only: true` after a failed session) or **`save_mcp_activity_log`** to export the same log the panel shows.
- After `npm run build`, restart the MCP server in Cursor so new tools appear.

Godot addon tries ports **6505–6509**. Node listens on the first free port in that range.

---

## MCP modes

| Flag | Tools | Use when |
|------|-------|----------|
| *(none)* | **183** | Full surface (debugging / edge cases) |
| **`--lite` (default)** | **~92** | Daily dev: core editor + translation layer + awareness + session |
| `--3d` | ~111 | Lite + physics + navigation + animation_tree |
| `--minimal` | 43 | Small context / local models |

The shipped `mcp.json` defaults to **`--lite`**. Switch to `--3d` or full only if you hit a missing tool — that's why `list_available_tools` exists.

Example:

```json
"args": ["e:/Godot/MCP Tool/build/index.js", "--lite"]
```

---

## CLI (optional, no Cursor)

```powershell
cd "e:\Godot\MCP Tool"
node build/cli.js project get_project_info
```

Godot must be open with the plugin enabled. Waits up to 30s for connection.

---

## Translation layer (the actual edge)

These tools turn raw editor state into something Cursor can read as text. Always prefer them over chains of `get_node_properties`.

| Problem | Tool | Action / params |
|---------|------|-----------------|
| Know what tools exist | `list_available_tools` | — |
| Know what Cursor cannot do | `get_capabilities` | optional `include_markdown` |
| First-session orientation | `initialize_session` | — |
| **3D scene as words** | `describe_scene` | `action: spatial_3d` (or `get_spatial_map`) |
| **2D scene + Z-order** | `describe_scene` | `action: spatial_2d` |
| **UI hierarchy + anchors** | `describe_scene` | `action: ui_outline` |
| **TileMap bounds and cells** | `describe_scene` | `action: tilemap_grid` |
| **Animation state** | `describe_scene` | `action: animation_state` |
| **Asset inventory (catches missing audio/textures)** | `describe_scene` | `action: asset_inventory` |
| **Scene diff vs prior snapshot** | `describe_scene` | `action: scene_diff` |
| **Visible Node3Ds near camera** | `describe_scene` | `action: visible_nodes` |
| **Physics events while playing** | `describe_scene` | `action: physics_events, node_paths:[...]` |
| Runtime physics behavior | `watch_game_state` | reads `plain_english` |
| Signal wiring | `get_signal_graph` | — |
| Inspector vs script defaults | `get_export_values` | — |
| Godot 3 syntax in scripts | `validate_godot4_api` | path |
| Screenshots when text isn't enough | `get_editor_screenshot`, `get_game_screenshot`, `capture_frames` | — |
| Debug a failed run | `get_mcp_activity_log`, `save_mcp_activity_log` | `errors_only: true` |

See [`.cursorrules`](.cursorrules) for the enforced session order.

**~190 tools** total: **175** addon commands + **composed** Node tools (`list_available_tools`, `get_capabilities`, `initialize_session`, `describe_scene`, awareness/blindness tools, plus guardrails: `get_class_doc`, `get_project_memory`, `set_project_memory`, `get_recent_changes`, `flag_chat_health`, …).

**Guardrails (v2):** `edit_script`, `create_script`, and `update_property` responses include `post_edit_validation` (syntax, Godot 4 API patterns, Output panel errors). Conflict errors (`-32009`) return `plain_english` explaining open-scene / open-script refusals. `set_project_memory` persists facts in `user://mcp_project_memory.json` across Cursor chat resets.

High-traffic tools have typed JSON schemas in `src/tools/typed-schemas.ts`; the rest are passthrough until more schemas are added.

---

## Architecture (short)

- Node runs a **WebSocket server** on `127.0.0.1:6505–6509`.
- Godot **plugin connects to Node** (not the other way around).
- JSON-RPC 2.0; ping/pong; 30s command timeout; first call waits for Godot up to 30s.

---

## Session 1 learnings (first real game-dev run)

What we saw testing **CrazyCattle3D-V2.0** with two Cursor windows and Godot **4.6.1**:

| What broke | Why | What we fixed |
|------------|-----|----------------|
| Godot errors: `mcp_*_service.gd` not found | Autoloads in `project.godot` but **incomplete** `addons/godot_mcp` copy in the game project | Documented required files + troubleshooting; ship full services in `vendor/godot_mcp/` — **re-copy whole folder** into the game |
| `watch_game_state` → “No scene is currently playing” | `play_scene` returns before the editor reports a running game; missing autoloads break game IPC | **1.5 s** delay after play, then **10×** `get_game_scene_tree` retries; structured `isError` JSON with autoload hint if still unreachable |
| Cursor called `initialize_session` (missing) | Tool was never registered; agent guessed project layout | Added **`initialize_session`** and **`list_available_tools`** (all modes including `--minimal`) |
| Agent called unknown tools | No session map of registered tools | **`.cursorrules`**: call `list_available_tools` then orient; README first-test flow updated |

**Before your first session checklist**

1. Godot game project has a **full** `addons/godot_mcp` copy (see `REQUIRED_FILES.txt`).
2. Godot Output has **no** autoload errors on startup.
3. `npm run build` in this repo; **restart** `godot-local` MCP in Cursor.
4. In chat (in this exact order, enforced by `.cursorrules`):
   1. `list_available_tools`
   2. `get_capabilities` — Cursor reads the do/don't list
   3. `initialize_session` — project info + scene tree + errors + asset counts
   4. `describe_scene` with the right `action` whenever you need to read state
5. For runtime sampling: set **Application → Run → Main Scene** if needed; `watch_game_state` calls `play_scene` for you.

**Physics note (game tuning, not MCP):** Milestone 1 sheep data showed charge release capped at **20 m/s** because `max_horizontal_speed` was 20; raise to ~**28** for a true ~2× burst over **13.5 m/s** base.

---

## License

Addon in `vendor/godot_mcp` follows [godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro) licensing. This Node server is an independent implementation of the public wire protocol.
"# godot-mcp" 
