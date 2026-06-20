#!/usr/bin/env node
import WebSocket from "ws";

const port = Number.parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

async function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    ws.on("open", () => ws.send(JSON.stringify({ id: `p7-${method}`, method, params })));
    ws.on("message", (d) => {
      ws.close();
      resolve(JSON.parse(String(d)));
    });
    ws.on("error", reject);
    setTimeout(() => reject(new Error("timeout")), 45000);
  });
}

function assertOk(label, res) {
  if (!res.ok) {
    console.error(`${label} failed:`, JSON.stringify(res));
    process.exit(1);
  }
  return res.result;
}

const list = await call("list_available_tools");
console.log("Tools:", list.result?.count, "(expected 101)");
if (!list.ok || list.result?.count < 99) process.exit(1);

const root = await call("get_scene_tree", { max_depth: 1 });
assertOk("get_scene_tree", root);

const spriteAdd = await call("add_node", {
  node_type: "Sprite2D",
  node_name: "MCPSprite",
  parent_path: ".",
});
assertOk("add_node Sprite2D", spriteAdd);

const playerAdd = await call("add_node", {
  node_type: "AnimationPlayer",
  node_name: "MCPAnimPlayer",
  parent_path: ".",
});
const playerPath = assertOk("add_node AnimationPlayer", playerAdd).node_path;
console.log("AnimationPlayer:", playerPath);

const createAnim = await call("create_animation", {
  node_path: playerPath,
  animation_name: "mcp_test_anim",
  length: 2,
});
assertOk("create_animation", createAnim);

const track = await call("add_animation_track", {
  node_path: playerPath,
  animation_name: "mcp_test_anim",
  track_type: "value",
  path: "MCPSprite:position:x",
});
const trackIndex = assertOk("add_animation_track", track).track_index;
console.log("Track index:", trackIndex);

const key = await call("set_animation_keyframe", {
  node_path: playerPath,
  animation_name: "mcp_test_anim",
  track_index: trackIndex,
  time: 0,
  value: 0,
});
assertOk("set_animation_keyframe", key);

const anims = await call("list_animations", { node_path: playerPath });
console.log("Animations:", assertOk("list_animations", anims).count);

const info = await call("get_animation_info", {
  node_path: playerPath,
  animation_name: "mcp_test_anim",
});
console.log("Track count:", assertOk("get_animation_info", info).track_count);

const treeAdd = await call("create_animation_tree", {
  parent_path: ".",
  node_name: "MCPAnimTree",
  anim_player_path: playerPath,
});
const treePath = assertOk("create_animation_tree", treeAdd).node_path;
console.log("AnimationTree:", treePath);

const treeInfo = await call("get_animation_tree_structure", { node_path: treePath });
console.log("Tree root:", assertOk("get_animation_tree_structure", treeInfo).tree_root_type);

const layerAdd = await call("add_node", {
  node_type: "TileMapLayer",
  node_name: "MCPTileLayer",
  parent_path: ".",
});
const layerPath = assertOk("add_node TileMapLayer", layerAdd).node_path;
console.log("TileMapLayer:", layerPath);

await call("tilemap_set_cell", { node_path: layerPath, coords: { x: 0, y: 0 }, source_id: -1 });
const cell = await call("tilemap_get_cell", { node_path: layerPath, coords: { x: 0, y: 0 } });
console.log("Cell empty:", assertOk("tilemap_get_cell", cell).empty);

await call("tilemap_fill_rect", {
  node_path: layerPath,
  from: { x: 0, y: 0 },
  to: { x: 1, y: 1 },
  source_id: -1,
});
const used = await call("tilemap_get_used_cells", { node_path: layerPath, limit: 10 });
console.log("Used cells:", assertOk("tilemap_get_used_cells", used).count);

const layerInfo = await call("tilemap_get_info", { node_path: layerPath });
assertOk("tilemap_get_info", layerInfo);

await call("tilemap_clear", { node_path: layerPath });
console.log("Phase 7 smoke test passed.");
