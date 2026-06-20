#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p8-${method}`, method, params })));
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
console.log("Tools:", list.result?.count, "(expected 130)");
if (!list.ok || list.result?.count < 128) process.exit(1);

const body = ok("setup_physics_body", await call("setup_physics_body", {
  body_type: "RigidBody2D", node_name: "MCPBody", parent_path: ".",
}));
console.log("Body:", body.node_path);

ok("setup_collision", await call("setup_collision", { node_path: body.node_path, shape_type: "circle", radius: 20 }));
ok("get_physics_layers", await call("get_physics_layers", { node_path: body.node_path }));

const mesh = ok("add_mesh_instance", await call("add_mesh_instance", { node_name: "MCPMesh" }));
console.log("Mesh:", mesh.node_path);
ok("set_material_3d", await call("set_material_3d", { node_path: mesh.node_path, color: { r: 0.2, g: 0.6, b: 1 } }));

const particles = ok("create_particles", await call("create_particles", { node_name: "MCPParticles", amount: 16 }));
ok("get_particle_info", await call("get_particle_info", { node_path: particles.node_path }));

const nav = ok("setup_navigation_region", await call("setup_navigation_region", { node_name: "MCPNav" }));
ok("get_navigation_info", await call("get_navigation_info", { node_path: nav.node_path }));

const audio = ok("add_audio_player", await call("add_audio_player", { node_name: "MCPAudio" }));
ok("get_audio_info", await call("get_audio_info", { node_path: audio.node_path }));
ok("get_audio_bus_layout", await call("get_audio_bus_layout"));

console.log("Phase 8 smoke test passed.");
