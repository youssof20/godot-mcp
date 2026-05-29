import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import { callGodot, registerTool } from "./helpers.js";
import { setToolCategory } from "./spec.js";

interface SignalConnectionRow {
  source?: string;
  signal?: string;
  target?: string;
  method?: string;
}

function pathProximityScore(nodePath: string, anchorPath: string): number {
  if (nodePath === anchorPath) return 0;
  const aParts = anchorPath.split("/").filter(Boolean);
  const nParts = nodePath.split("/").filter(Boolean);
  let common = 0;
  for (let i = 0; i < Math.min(aParts.length, nParts.length); i++) {
    if (aParts[i] === nParts[i]) common++;
    else break;
  }
  return Math.abs(nParts.length - aParts.length) * 10 + (nParts.length - common);
}

/** Parse .tscn node sections for property overrides (inspector values). */
export function parseTscnExportOverrides(content: string): Record<string, Record<string, unknown>> {
  const result: Record<string, Record<string, unknown>> = {};
  const lines = content.split("\n");
  let currentPath = "";
  let inNode = false;

  const skipKeys = new Set([
    "type",
    "parent",
    "instance",
    "instance_placeholder",
    "script",
    "uid",
  ]);

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (line.startsWith("[node")) {
      inNode = true;
      const nameMatch = line.match(/name="([^"]+)"/);
      const parentMatch = line.match(/parent="([^"]+)"/);
      const nodeName = nameMatch?.[1] ?? "Unknown";
      if (parentMatch) {
        currentPath = `${parentMatch[1]}/${nodeName}`;
      } else {
        currentPath = nodeName;
      }
      if (!result[currentPath]) {
        result[currentPath] = {};
      }
      continue;
    }

    if (line.startsWith("[") && !line.startsWith("[node")) {
      inNode = false;
      continue;
    }

    if (!inNode || !line.includes("=")) continue;

    const eq = line.indexOf("=");
    const key = line.slice(0, eq).trim();
    if (skipKeys.has(key) || key.startsWith("metadata/")) continue;

    let valueStr = line.slice(eq + 1).trim();
    if (
      (valueStr.startsWith('"') && valueStr.endsWith('"')) ||
      (valueStr.startsWith("'") && valueStr.endsWith("'"))
    ) {
      valueStr = valueStr.slice(1, -1);
    }

    let parsed: unknown = valueStr;
    if (valueStr === "true") parsed = true;
    else if (valueStr === "false") parsed = false;
    else if (/^-?\d+$/.test(valueStr)) parsed = parseInt(valueStr, 10);
    else if (/^-?\d+\.\d+$/.test(valueStr)) parsed = parseFloat(valueStr);

    result[currentPath][key] = parsed;
  }

  return result;
}

function buildExportPlainEnglish(
  exports: Record<string, Record<string, unknown>>,
): string {
  const sentences: string[] = [];
  const paths = Object.keys(exports).filter(
    (p) => Object.keys(exports[p] ?? {}).length > 0,
  );

  if (paths.length === 0) {
    return "No inspector export overrides found in the scene file (only script defaults apply).";
  }

  sentences.push(
    `Found inspector overrides on ${paths.length} node${paths.length === 1 ? "" : "s"}.`,
  );

  for (const nodePath of paths.slice(0, 20)) {
    const vars = exports[nodePath]!;
    const parts = Object.entries(vars).map(([k, v]) => `${k}=${JSON.stringify(v)}`);
    sentences.push(`${nodePath} has ${parts.join(", ")} set in the scene file (overrides script defaults).`);
  }

  if (paths.length > 20) {
    sentences.push(`…and ${paths.length - 20} more nodes with overrides.`);
  }

  return sentences.join(" ");
}

function buildSignalGraphPlainEnglish(
  connections: Array<{
    emitter_path: string;
    signal_name: string;
    receiver_path: string;
    method_name: string;
  }>,
): string {
  if (connections.length === 0) {
    return "There are 0 signal connections in this scene.";
  }

  const sentences = [
    `There are ${connections.length} signal connection${connections.length === 1 ? "" : "s"} in this scene.`,
  ];

  for (const c of connections) {
    const emitter = c.emitter_path.split("/").pop() ?? c.emitter_path;
    const receiver = c.receiver_path.split("/").pop() ?? c.receiver_path;
    sentences.push(
      `${emitter} emits ${c.signal_name} to ${receiver}.${c.method_name}.`,
    );
  }

  return sentences.join(" ");
}

interface Gd3Pattern {
  id: string;
  regex: RegExp;
  message: string;
  replacement: string;
}

const GD3_PATTERNS: Gd3Pattern[] = [
  {
    id: "connect_string",
    regex: /\.connect\s*\(\s*["'][^"']+["']\s*,/,
    message: "Godot 3 string-based connect()",
    replacement: "Use signal_name.connect(Callable(target, \"method\")) in Godot 4",
  },
  {
    id: "yield",
    regex: /\byield\b/,
    message: "Godot 3 yield",
    replacement: "Use await in Godot 4",
  },
  {
    id: "os_ticks",
    regex: /OS\.get_ticks_msec/,
    message: "Godot 3 OS.get_ticks_msec",
    replacement: "Use Time.get_ticks_msec() in Godot 4",
  },
  {
    id: "randomize",
    regex: /\brandomize\s*\(\s*\)/,
    message: "Unnecessary randomize()",
    replacement: "Godot 4 seeds RNG automatically; remove randomize() unless you need a custom seed",
  },
  {
    id: "onready",
    regex: /^\s*onready\s+var\b/m,
    message: "Godot 3 onready var",
    replacement: "Use @onready var in Godot 4",
  },
  {
    id: "export_var",
    regex: /^\s*export\s+var\b/m,
    message: "Godot 3 export var",
    replacement: "Use @export var in Godot 4",
  },
  {
    id: "move_and_collide_bool",
    regex: /if\s+move_and_collide\s*\(/,
    message: "Godot 3 move_and_collide used as boolean",
    replacement: "In Godot 4 move_and_collide returns KinematicCollision3D; check result != null",
  },
];

export function scanGodot3Patterns(content: string): Array<{
  line: number;
  pattern_id: string;
  found_text: string;
  message: string;
  replacement: string;
}> {
  const lines = content.split("\n");
  const findings: Array<{
    line: number;
    pattern_id: string;
    found_text: string;
    message: string;
    replacement: string;
  }> = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!;
    for (const pat of GD3_PATTERNS) {
      if (pat.regex.test(line)) {
        findings.push({
          line: i + 1,
          pattern_id: pat.id,
          found_text: line.trim(),
          message: pat.message,
          replacement: pat.replacement,
        });
      }
    }
  }

  return findings;
}

function buildValidateGd4PlainEnglish(
  path: string,
  findings: ReturnType<typeof scanGodot3Patterns>,
): string {
  if (findings.length === 0) {
    return `Script ${path} has no detected Godot 3 API patterns.`;
  }

  const sentences = [
    `Script ${path} has ${findings.length} Godot 3 pattern${findings.length === 1 ? "" : "s"}.`,
  ];

  for (const f of findings.slice(0, 15)) {
    sentences.push(
      `Line ${f.line}: ${f.message}. Replace with: ${f.replacement}.`,
    );
  }

  if (findings.length > 15) {
    sentences.push(`…and ${findings.length - 15} more pattern(s) in the findings list.`);
  }

  return sentences.join(" ");
}

function collectGameTreePaths(node: unknown, paths: string[]): void {
  if (!node || typeof node !== "object") return;
  const n = node as Record<string, unknown>;
  if (typeof n.path === "string") paths.push(n.path);
  if (typeof n.name === "string" && !n.path) paths.push(n.name);
  const children = n.children;
  if (Array.isArray(children)) {
    for (const child of children) collectGameTreePaths(child, paths);
  }
}

export function registerBlindnessTools(client: GodotClient): void {
  registerTool(client, {
    name: "get_signal_graph",
    description:
      "Flat signal connection graph for the edited scene. Optional scene_root (unused filter; scans active scene). Returns connections[] and plain_english. Call before connect_signal to avoid duplicates.",
    schema: z.object({
      scene_root: z
        .string()
        .optional()
        .describe("Reserved; scans the currently edited scene"),
    }),
    handler: async (c) => {
      const raw = (await callGodot(c, "find_signal_connections", {})) as {
        connections?: SignalConnectionRow[];
      };

      const flat = (raw.connections ?? []).map((conn) => ({
        emitter_path: String(conn.source ?? ""),
        signal_name: String(conn.signal ?? ""),
        receiver_path: String(conn.target ?? ""),
        method_name: String(conn.method ?? ""),
      }));

      return {
        connections: flat,
        count: flat.length,
        plain_english: buildSignalGraphPlainEnglish(flat),
      };
    },
  });
  setToolCategory("get_signal_graph", "batch");

  registerTool(client, {
    name: "get_export_values",
    description:
      "Inspector @export overrides from the .tscn file (real game values, not script defaults). Optional scene_path; default is active scene file. Returns exports by node path and plain_english.",
    schema: z.object({
      scene_path: z
        .string()
        .optional()
        .describe("res:// scene path; default active edited scene"),
    }),
    handler: async (c, args) => {
      let path = args.scene_path;
      if (!path) {
        const tree = (await callGodot(c, "get_scene_tree", {})) as {
          scene_path?: string;
        };
        path = tree.scene_path ?? "";
      }
      if (!path) {
        return {
          exports: {},
          plain_english: "No scene open and no scene_path provided.",
        };
      }

      const file = (await callGodot(c, "get_scene_file_content", {
        path,
      })) as { content?: string };

      const exports = parseTscnExportOverrides(file.content ?? "");

      return {
        scene_path: path,
        exports,
        plain_english: buildExportPlainEnglish(exports),
      };
    },
  });
  setToolCategory("get_export_values", "scene");

  registerTool(client, {
    name: "validate_godot4_api",
    description:
      "Scan a .gd script for Godot 3 API patterns (connect strings, yield, OS.get_ticks_msec, etc.). Returns findings with line numbers and plain_english. Run after every edit_script.",
    schema: z.object({
      path: z.string().describe("res:// path to GDScript file"),
    }),
    handler: async (c, args) => {
      const script = (await callGodot(c, "read_script", { path: args.path })) as {
        content?: string;
      };
      const content = script.content ?? "";
      const findings = scanGodot3Patterns(content);

      return {
        path: args.path,
        findings,
        count: findings.length,
        plain_english: buildValidateGd4PlainEnglish(args.path, findings),
      };
    },
  });
  setToolCategory("validate_godot4_api", "script");
}

export { collectGameTreePaths, pathProximityScore };
