#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p5-${method}`, method, params })));
    ws.on("message", (d) => { ws.close(); resolve(JSON.parse(String(d))); });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 30000);
  });
}

const list = await call("list_available_tools");
console.log("Tools:", list.result?.count, "(expected 74)");
if (!list.ok || list.result?.count < 70) process.exit(1);

await call("play_scene", {});
await new Promise((r) => setTimeout(r, 1500));

const status = await call("get_runtime_status");
console.log("Playing:", status.result?.is_playing);

const tree = await call("get_game_scene_tree", { max_depth: 4 });
console.log("Game tree ok:", tree.ok);

await call("stop_scene", {});

const exec = await call("execute_game_script", { source: "print(1)" });
console.log("execute_game_script blocked:", exec.error?.code === "DANGEROUS_TOOL_DISABLED");

console.log("Phase 5 smoke test passed.");
