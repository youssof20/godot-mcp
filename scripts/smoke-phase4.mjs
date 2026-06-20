#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p4-${method}`, method, params })));
    ws.on("message", (d) => { ws.close(); resolve(JSON.parse(String(d))); });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 15000);
  });
}

const list = await call("list_available_tools");
console.log("Tool count:", list.result?.count);
if (!list.ok || list.result?.count < 50) {
  console.error("FAIL: expected 50+ tools");
  process.exit(1);
}

const deps = await call("get_scene_dependencies", { scene_path: "res://scenes/mcp_test_main.tscn" });
if (!deps.ok) {
  console.error("get_scene_dependencies failed:", JSON.stringify(deps.error));
  process.exit(1);
}
console.log("Scene deps count:", deps.result?.count);

const autoload = await call("get_autoload");
if (!autoload.ok) {
  console.error("get_autoload failed:", JSON.stringify(autoload.error));
  process.exit(1);
}
console.log("Autoload count:", autoload.result?.count);

const actions = await call("get_input_actions");
if (!actions.ok) {
  console.error("get_input_actions failed:", JSON.stringify(actions.error));
  process.exit(1);
}
console.log("Input actions:", actions.result?.count);

console.log("Phase 4/5 smoke test passed.");
