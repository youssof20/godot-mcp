#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p10-${method}`, method, params })));
    ws.on("message", (d) => { ws.close(); resolve(JSON.parse(String(d))); });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 30000);
  });
}

const list = await call("list_available_tools");
console.log("Tools:", list.result?.count, "(expected 172)");
if (!list.ok || list.result?.count < 170) process.exit(1);

const help = await call("get_tool_help", { tool: "godot_ping" });
console.log("Help category:", help.result?.category);
if (!help.ok || !help.result?.description) process.exit(1);

const allHelp = await call("get_tool_help", {});
console.log("Help entries:", allHelp.result?.count);
if (!allHelp.ok || allHelp.result?.count !== list.result?.count) process.exit(1);

console.log("Phase 10 smoke test passed.");
