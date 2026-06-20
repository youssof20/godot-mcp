#!/usr/bin/env node
/**
 * Phase 3 smoke test: create or open scene, add node, update property, save.
 */
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);
const scenePath = "res://scenes/mcp_test_main.tscn";

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    const id = `phase3-${method}`;
    ws.on("open", () => ws.send(JSON.stringify({ id, method, params })));
    ws.on("message", (data) => { ws.close(); resolve(JSON.parse(String(data))); });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 15000);
  });
}

let create = await call("create_scene", {
  scene_path: scenePath,
  root_type: "Node2D",
  root_name: "Main",
  open: true,
});

if (!create.ok && create.error?.code === "ALREADY_EXISTS") {
  console.log("Scene exists, opening...");
  create = await call("open_scene", { scene_path: scenePath });
}

console.log("\n=== create_scene / open_scene ===");
console.log(JSON.stringify(create, null, 2));
if (!create.ok) process.exit(1);

const steps = [
  ["add_node", { node_type: "Sprite2D", node_name: "Hero", parent_path: "." }],
  ["update_property", { node_path: "Hero", property: "position", value: { x: 128, y: 64 } }],
  ["save_scene", {}],
  ["get_scene_tree", {}],
];

for (const [method, params] of steps) {
  const res = await call(method, params);
  console.log(`\n=== ${method} ===`);
  console.log(JSON.stringify(res, null, 2));
  if (!res.ok) process.exit(1);
}

console.log("\nPhase 3 smoke test passed.");
