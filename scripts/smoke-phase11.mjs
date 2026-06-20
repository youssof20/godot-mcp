#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p11-${method}`, method, params })));
    ws.on("message", (d) => {
      ws.close();
      resolve(JSON.parse(String(d)));
    });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 30000);
  });
}

const list = await call("list_available_tools");
const count = list.result?.count ?? 0;
console.log("Tools:", count, "(expected 172)");
if (!list.ok || count < 170) process.exit(1);

const state = await call("get_editor_state");
console.log("Editor state scene:", state.result?.edited_scene_path ?? "(none)");
if (!state.ok) process.exit(1);

const types = await call("list_node_types", { category: "2d" });
console.log("2D node types:", types.result?.count);
if (!types.ok || types.result?.count < 5) process.exit(1);

const open = await call("get_open_scripts");
console.log("Open scripts:", open.result?.count);
if (!open.ok) process.exit(1);

const help = await call("get_tool_help", { tool: "batch_set_property" });
if (!help.ok || !help.result?.description) process.exit(1);
console.log("batch_set_property help OK");

console.log("Phase 11 smoke test passed.");
