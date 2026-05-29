import fs from "fs";
import path from "path";

const cmdDir = "vendor/godot_mcp/commands";
const handlers = new Set();

for (const f of fs.readdirSync(cmdDir).filter((x) => x.endsWith(".gd"))) {
  const t = fs.readFileSync(path.join(cmdDir, f), "utf8");
  const m = t.match(/func get_commands\(\)[^{]*\{([\s\S]*?)^\}/m);
  if (!m) continue;
  const block = m[1];
  for (const k of block.matchAll(/"([a-z][a-z0-9_]*)":\s*_[a-z][a-z0-9_]*/g)) {
    handlers.add(k[1]);
  }
}

console.log([...handlers].sort().join("\n"));
console.error("COUNT", handlers.size);
