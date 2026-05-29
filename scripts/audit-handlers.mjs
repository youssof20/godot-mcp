import fs from "fs";
import path from "path";

const cmdDir = "vendor/godot_mcp/commands";
const handlers = new Set();

for (const file of fs.readdirSync(cmdDir).filter((f) => f.endsWith(".gd"))) {
  const text = fs.readFileSync(path.join(cmdDir, file), "utf8");
  const blockMatch = text.match(/func get_commands\(\)[^{]*\{([\s\S]*?)\n\}/m);
  if (!blockMatch) continue;
  for (const m of blockMatch[1].matchAll(
    /"([a-z][a-z0-9_]*)":\s*_[a-z][a-z0-9_]*/g,
  )) {
    handlers.add(m[1]);
  }
}

console.log([...handlers].sort().join("\n"));
console.error("COUNT", handlers.size);
