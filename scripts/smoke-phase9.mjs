#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p9-${method}`, method, params })));
    ws.on("message", (d) => { ws.close(); resolve(JSON.parse(String(d))); });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 45000);
  });
}

function ok(label, res) {
  if (!res.ok) { console.error(label, JSON.stringify(res)); process.exit(1); }
  return res.result;
}

const list = await call("list_available_tools");
console.log("Tools:", list.result?.count, "(expected 152)");
if (!list.ok || list.result?.count < 150) process.exit(1);

const theme = ok("create_theme", await call("create_theme", { theme_path: "res://themes/mcp_smoke_theme.tres" }));
ok("set_theme_color", await call("set_theme_color", {
  theme_path: theme.theme_path,
  color: { r: 0.2, g: 0.6, b: 1, a: 1 },
}));
ok("get_theme_info", await call("get_theme_info", { theme_path: theme.theme_path }));

const shader = ok("create_shader", await call("create_shader", { shader_path: "res://shaders/mcp_smoke.gdshader" }));
ok("read_shader", await call("read_shader", { shader_path: shader.shader_path }));

ok("get_performance_monitors", await call("get_performance_monitors", {}));
ok("get_editor_performance", await call("get_editor_performance", {}));

ok("list_export_presets", await call("list_export_presets"));
ok("get_export_info", await call("get_export_info", { preset_index: 0 }));

ok("analyze_scene_complexity", await call("analyze_scene_complexity", {}));
ok("get_project_statistics", await call("get_project_statistics", {}));
ok("audit_project_health", await call("audit_project_health", {}));

console.log("Phase 9 smoke test passed.");
