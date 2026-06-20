#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p6-${method}`, method, params })));
    ws.on("message", (d) => {
      ws.close();
      resolve(JSON.parse(String(d)));
    });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 45000);
  });
}

const list = await call("list_available_tools");
console.log("Tools:", list.result?.count, "(expected 87)");
if (!list.ok || list.result?.count < 85) process.exit(1);

const shot = await call("get_editor_screenshot", { viewport: "2d", save: true });
console.log("Editor screenshot:", shot.ok, shot.result?.width, "x", shot.result?.height);
if (!shot.ok || !shot.result?.png_base64) process.exit(1);

const frames = await call("capture_frames", { count: 2, delay_ms: 100, target: "editor_2d" });
console.log("Capture frames:", frames.result?.count);
if (!frames.ok || frames.result?.count !== 2) process.exit(1);

const pathA = shot.result?.saved_path;
if (pathA) {
  const cmp = await call("compare_screenshots", {
    image_a: pathA,
    image_b: pathA,
    max_diff_ratio: 0,
  });
  console.log("Compare self:", cmp.result?.passed);
  if (!cmp.ok || !cmp.result?.passed) process.exit(1);
}

await call("start_recording", { target: "editor_2d", interval_ms: 100 });
await new Promise((r) => setTimeout(r, 350));
const rec = await call("stop_recording");
console.log("Recording frames:", rec.result?.frame_count);
if (!rec.ok || rec.result?.frame_count < 1) process.exit(1);

const scenario = await call("run_test_scenario", {
  name: "phase6-smoke",
  steps: [{ tool: "godot_ping", params: {} }, { tool: "get_runtime_status", params: {} }],
});
console.log("Scenario passed:", scenario.result?.passed, "failed:", scenario.result?.failed);

const stress = await call("run_stress_test", { tool: "godot_ping", iterations: 10 });
console.log("Stress avg_ms:", stress.result?.avg_ms);

const report = await call("get_test_report");
console.log("Test report type:", report.result?.type ?? report.result?.scenario);

const tree = await call("get_scene_tree", { max_depth: 2 });
const rootPath = tree.result?.root?.path ?? ".";
const mon = await call("monitor_properties", {
  node_path: rootPath,
  properties: ["name"],
  action: "snapshot",
});
console.log("Monitor snapshot:", mon.ok);

const gameShot = await call("get_game_screenshot");
console.log("Game screenshot blocked (not playing):", gameShot.error?.code === "RUNTIME_NOT_RUNNING");

console.log("Phase 6 smoke test passed.");
