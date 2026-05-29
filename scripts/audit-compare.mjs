import fs from "fs";
import path from "path";

const cmdDir = "vendor/godot_mcp/commands";
const handlers = new Set();
for (const f of fs.readdirSync(cmdDir).filter((x) => x.endsWith(".gd"))) {
  const t = fs.readFileSync(path.join(cmdDir, f), "utf8");
  const re = /"([a-z_][a-z0-9_]*)":\s*_[a-z_][a-z0-9_]*/g;
  for (const m of t.matchAll(re)) handlers.add(m[1]);
}

const { registerAllGodotTools } = await import("../build/tools/catalog.js");
const { getRegisteredTools, clearToolRegistry } = await import("../build/tools/helpers.js");
const { clearToolCategories, getToolCategory } = await import("../build/tools/spec.js");
const { GodotClient } = await import("../build/godot-client.js");

clearToolRegistry();
clearToolCategories();
registerAllGodotTools(new GodotClient());
const tools = getRegisteredTools().map((t) => t.name).sort();

const byCat = {};
for (const n of tools) {
  const c = getToolCategory(n) ?? "special";
  (byCat[c] ??= []).push(n);
}

console.log("ADDON_COUNT", handlers.size);
console.log("MCP_COUNT", tools.length);
console.log(
  "ONLY_ADDON",
  [...handlers].filter((h) => !tools.includes(h)).join(", ") || "(none)",
);
console.log(
  "ONLY_MCP",
  tools.filter((t) => !handlers.has(t)).join(", ") || "(none)",
);
for (const [c, list] of Object.entries(byCat).sort()) {
  console.log(`CAT ${c} ${list.length}: ${list.join(", ")}`);
}
