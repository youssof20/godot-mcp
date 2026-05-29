import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import { callGodot, registerTool } from "./helpers.js";
import { resolvePlaySceneMode } from "./scene-helpers.js";
import { GodotCommandError } from "../types.js";
import { collectGameTreePaths, pathProximityScore } from "./blindness-tools.js";
import { setToolCategory } from "./spec.js";
import {
  buildSpatialPlainEnglish,
  classifySpatialRole,
  distanceXZ,
  isNode3DType,
  parseVec3,
  type SceneTreeNode,
  type SpatialNode,
  walkSceneTree,
} from "./spatial-helpers.js";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function mapInBatches<T, R>(
  items: T[],
  batchSize: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(batch.map(fn));
    results.push(...batchResults);
  }
  return results;
}

function stableStringify(value: unknown): string {
  return JSON.stringify(value);
}

function valuesEqual(a: unknown, b: unknown): boolean {
  return stableStringify(a) === stableStringify(b);
}

interface GodotPropsResult {
  properties?: Record<string, unknown>;
  node_path?: string;
  type?: string;
}

interface SampleRow {
  timestamp_ms: number;
  node_path: string;
  property: string;
  value: unknown;
}

interface ChangeRow {
  node_path: string;
  property: string;
  from: unknown;
  to: unknown;
  at_timestamp_ms: number;
}

function extractErrors(result: unknown): string[] {
  if (!result || typeof result !== "object") return [];
  const errors = (result as { errors?: unknown }).errors;
  if (!Array.isArray(errors)) return [];
  return errors.map((e) => String(e));
}

function extractLogLines(result: unknown): string[] {
  if (!result || typeof result !== "object") return [];
  const lines = (result as { lines?: unknown }).lines;
  if (!Array.isArray(lines)) return [];
  return lines.map((l) => String(l));
}

function diffNewLines(before: string[], after: string[]): string[] {
  const beforeSet = new Set(before);
  return after.filter((line) => !beforeSet.has(line));
}

function magnitude3(v: unknown): number | null {
  if (!v || typeof v !== "object" || Array.isArray(v)) return null;
  const o = v as Record<string, unknown>;
  const x = Number(o.x ?? 0);
  const y = Number(o.y ?? 0);
  const z = Number(o.z ?? 0);
  return Math.sqrt(x * x + y * y + z * z);
}

function nodeMatchesPath(node: SceneTreeNode, rootPath: string): boolean {
  return (
    node.path === rootPath ||
    node.name === rootPath ||
    node.path.endsWith("/" + rootPath) ||
    (rootPath === "." && !node.path.includes("/"))
  );
}

function buildWatchPlainEnglish(
  nodePaths: string[],
  properties: string[],
  samples: SampleRow[],
  durationSeconds: number,
  sampleIntervalMs: number,
  runtimeErrors: { errors: string[]; log_lines: string[] },
  readyWarning?: string,
): string {
  const sentences: string[] = [];
  if (readyWarning) {
    sentences.push(readyWarning);
  }
  const sampleCount = new Set(samples.map((s) => s.timestamp_ms)).size;
  const watched = nodePaths.join(", ") || "nodes";
  sentences.push(
    `watched ${watched} for ${durationSeconds} seconds across ${sampleCount} sample${sampleCount === 1 ? "" : "s"} (every ${sampleIntervalMs} ms).`,
  );

  for (const nodePath of nodePaths) {
    for (const prop of properties) {
      const propSamples = samples
        .filter((s) => s.node_path === nodePath && s.property === prop)
        .sort((a, b) => a.timestamp_ms - b.timestamp_ms);
      if (propSamples.length === 0) continue;

      const changed = propSamples.some(
        (s, i) => i > 0 && !valuesEqual(s.value, propSamples[i - 1]!.value),
      );

      if (prop === "global_position") {
        const first = propSamples[0]!.value;
        const last = propSamples[propSamples.length - 1]!.value;
        let total = 0;
        for (let i = 1; i < propSamples.length; i++) {
          const a = parseVec3(propSamples[i - 1]!.value);
          const b = parseVec3(propSamples[i]!.value);
          total += distanceXZ(a, b) + Math.abs(a.y - b.y);
        }
        const changeCount = propSamples.filter(
          (s, i) => i > 0 && !valuesEqual(s.value, propSamples[i - 1]!.value),
        ).length;
        sentences.push(
          `${nodePath} global_position changed ${changeCount} time${changeCount === 1 ? "" : "s"}, starting at ${formatValue(first)} and ending at ${formatValue(last)}, total movement ${round1(total)} meters.`,
        );
        continue;
      }

      if (prop === "velocity") {
        const magnitudes = propSamples
          .map((s) => magnitude3(s.value))
          .filter((m): m is number => m !== null);
        const nonzero = magnitudes.filter((m) => m > 0.01).length;
        const peak = magnitudes.length ? Math.max(...magnitudes) : 0;
        sentences.push(
          `${nodePath} velocity was nonzero in ${nonzero} of ${propSamples.length} samples, peak velocity was ${round1(peak)} meters per second.`,
        );
        continue;
      }

      if (typeof propSamples[0]!.value === "boolean") {
        const boolSamples = propSamples.map((s) => Boolean(s.value));
        const allTrue = boolSamples.every((v) => v);
        const allFalse = boolSamples.every((v) => !v);
        if (allTrue) {
          sentences.push(
            `${nodePath} ${prop} was true in all ${propSamples.length} samples.`,
          );
        } else if (allFalse) {
          sentences.push(
            `${nodePath} ${prop} was false in all ${propSamples.length} samples.`,
          );
        } else {
          const trueCount = boolSamples.filter((v) => v).length;
          sentences.push(
            `${nodePath} ${prop} was true in ${trueCount} of ${propSamples.length} samples and false in ${propSamples.length - trueCount}.`,
          );
        }
        continue;
      }

      if (changed) {
        sentences.push(
          `${nodePath} ${prop} changed between samples (first ${formatValue(propSamples[0]!.value)}, last ${formatValue(propSamples[propSamples.length - 1]!.value)}).`,
        );
      } else {
        sentences.push(
          `${nodePath} ${prop} stayed constant at ${formatValue(propSamples[0]!.value)} across all samples.`,
        );
      }
    }
  }

  const errCount = runtimeErrors.errors.length + runtimeErrors.log_lines.length;
  if (errCount === 0) {
    sentences.push("no new errors appeared in the editor output or error log during this run.");
  } else {
    sentences.push(
      `${errCount} new error or log line${errCount === 1 ? "" : "s"} appeared during this run (see runtime_errors).`,
    );
  }

  return sentences.join(" ");
}

function formatValue(v: unknown): string {
  if (v && typeof v === "object" && !Array.isArray(v)) {
    const o = v as Record<string, unknown>;
    if ("x" in o && "y" in o && "z" in o) {
      return `${round1(Number(o.x))} ${round1(Number(o.y))} ${round1(Number(o.z))}`;
    }
  }
  return stableStringify(v);
}

function round1(n: number): string {
  const r = Math.round(n * 10) / 10;
  return Number.isInteger(r) ? String(r) : r.toFixed(1);
}

const PLAY_START_DELAY_MS = 1500;
const GAME_TREE_RETRY_MS = 500;
const GAME_TREE_MAX_RETRIES = 10;

export interface GameReachableFailure {
  success: false;
  error: string;
  hint: string;
  retries: number;
  last_error?: string;
}

type GameReachableResult = { ok: true } | GameReachableFailure;

async function ensureGameReachable(
  client: GodotClient,
): Promise<GameReachableResult> {
  await sleep(PLAY_START_DELAY_MS);

  let lastError: string | undefined;
  for (let attempt = 0; attempt < GAME_TREE_MAX_RETRIES; attempt++) {
    try {
      const treeResult = (await callGodot(client, "get_game_scene_tree", {
        max_depth: 1,
      })) as { tree?: unknown; error?: string };
      if (treeResult.error) {
        lastError = String(treeResult.error);
      } else if (treeResult.tree) {
        return { ok: true };
      } else {
        lastError = "get_game_scene_tree returned no tree";
      }
    } catch (err) {
      lastError =
        err instanceof GodotCommandError
          ? err.message
          : err instanceof Error
            ? err.message
            : String(err);
    }
    if (attempt < GAME_TREE_MAX_RETRIES - 1) {
      await sleep(GAME_TREE_RETRY_MS);
    }
  }

  return {
    success: false,
    error:
      "play_scene was called but the running game could not be reached after about 5 seconds.",
    hint:
      "This usually means the MCP runtime autoloads failed to register. Check that mcp_game_inspector_service.gd, mcp_input_service.gd, and mcp_screenshot_service.gd exist in your project's addons/godot_mcp/ folder (see vendor/godot_mcp/REQUIRED_FILES.txt) and restart Godot.",
    retries: GAME_TREE_MAX_RETRIES,
    last_error: lastError,
  };
}

async function waitForWatchedNodes(
  client: GodotClient,
  nodePaths: string[],
  waitReadyMs: number,
): Promise<string | undefined> {
  const deadline = Date.now() + waitReadyMs;
  while (Date.now() < deadline) {
    try {
      const treeResult = (await callGodot(client, "get_game_scene_tree", {})) as {
        tree?: unknown;
      };
      const paths: string[] = [];
      collectGameTreePaths(treeResult.tree, paths);
      const normalized = new Set(paths.map((p) => p.replace(/^\//, "")));
      const found = nodePaths.some((np) => {
        const n = np.replace(/^\//, "");
        return normalized.has(n) || paths.some((p) => p.endsWith("/" + n) || p === n);
      });
      if (found) return undefined;
    } catch {
      // keep waiting
    }
    await sleep(GAME_TREE_RETRY_MS);
  }
  return "Warning: watched node_paths were not found in the live game tree within wait_ready_ms; samples may be empty.";
}

export function registerAwarenessTools(client: GodotClient): void {
  registerTool(client, {
    name: "get_spatial_map",
    description:
      "3D spatial ground truth for the edited scene. Returns Node3D positions plus plain_english distances. Params: root_path (default .), radius (0=all, >0 XZ filter), max_nodes (default 50, closest to root_path when truncated).",
    schema: z.object({
      root_path: z
        .string()
        .optional()
        .default(".")
        .describe("Anchor node path for radius filter and truncation sort"),
      radius: z
        .number()
        .optional()
        .default(0)
        .describe("XZ distance from anchor; 0 includes all (subject to max_nodes)"),
      max_nodes: z
        .number()
        .optional()
        .default(50)
        .describe("Max Node3D nodes to query; closest to root_path when truncated"),
    }),
    handler: async (c, args) => {
      const treeResult = (await callGodot(c, "get_scene_tree", {})) as {
        tree?: SceneTreeNode;
      };
      const tree = treeResult.tree;
      if (!tree) {
        return { nodes: [], plain_english: "scene contains 0 spatial nodes (no scene open)." };
      }

      const candidates: SceneTreeNode[] = [];
      walkSceneTree(tree, (n) => {
        if (isNode3DType(n.type)) candidates.push(n);
      });

      const anchorPath =
        candidates.find((n) => nodeMatchesPath(n, args.root_path))?.path ??
        candidates[0]?.path ??
        args.root_path;

      let toFetch = candidates;
      let truncationNote: string | undefined;
      if (candidates.length > args.max_nodes) {
        const skipped = candidates.length - args.max_nodes;
        toFetch = [...candidates]
          .sort(
            (a, b) =>
              pathProximityScore(a.path, anchorPath) -
              pathProximityScore(b.path, anchorPath),
          )
          .slice(0, args.max_nodes);
        truncationNote = `Scene truncated: ${skipped} Node3D node${skipped === 1 ? "" : "s"} skipped (limit max_nodes=${args.max_nodes}); listed nodes are closest to ${anchorPath} in the scene tree.`;
      }

      const spatialNodes = await mapInBatches(toFetch, 10, async (node) => {
        const propsResult = (await callGodot(c, "get_node_properties", {
          node_path: node.path,
        })) as GodotPropsResult;
        const props = propsResult.properties ?? {};
        return {
          name: node.name,
          path: propsResult.node_path ?? node.path,
          class: propsResult.type ?? node.type,
          spatial_role: classifySpatialRole(node.type),
          global_position: parseVec3(props.global_position),
          rotation_degrees: parseVec3(props.rotation_degrees),
          scale: parseVec3(props.scale, { x: 1, y: 1, z: 1 }),
        } satisfies SpatialNode;
      });

      let filtered = spatialNodes;
      if (args.radius > 0) {
        const anchor =
          spatialNodes.find(
            (n) =>
              n.path === args.root_path ||
              n.name === args.root_path ||
              n.path.endsWith("/" + args.root_path),
          ) ?? spatialNodes[0];
        if (anchor) {
          filtered = spatialNodes.filter(
            (n) => distanceXZ(n.global_position, anchor.global_position) <= args.radius,
          );
        }
      }

      return {
        nodes: filtered,
        truncated: Boolean(truncationNote),
        plain_english: buildSpatialPlainEnglish(filtered, truncationNote),
      };
    },
  });
  setToolCategory("get_spatial_map", "scene");

  registerTool(client, {
    name: "watch_game_state",
    description:
      "Runs the game, waits for watched nodes in the live tree, samples properties, stops. Returns samples, changes, plain_english, runtime_errors. Required: node_paths[], properties[]. Optional: duration_seconds (3), sample_interval_ms (500), wait_ready_ms (5000).",
    schema: z.object({
      node_paths: z
        .array(z.string())
        .min(1)
        .describe("Game node paths to watch, e.g. Player"),
      properties: z
        .array(z.string())
        .min(1)
        .describe("Property names to sample on each node"),
      duration_seconds: z.number().optional().default(3),
      sample_interval_ms: z.number().optional().default(500),
      wait_ready_ms: z
        .number()
        .optional()
        .default(5000)
        .describe("Max ms to wait for game tree to include node_paths"),
      scene_path: z
        .string()
        .optional()
        .describe(
          "res:// scene to play; defaults to project main_scene, then current editor scene",
        ),
    }),
    handler: async (c, args) => {
      const durationMs = args.duration_seconds * 1000;
      const interval = args.sample_interval_ms;

      const errorsBefore = extractErrors(
        await callGodot(c, "get_editor_errors", { max_lines: 100 }),
      );
      const logBefore = extractLogLines(
        await callGodot(c, "get_output_log", { max_lines: 200 }),
      );

      const play = await resolvePlaySceneMode(c, args.scene_path);
      await callGodot(c, "play_scene", { mode: play.mode });

      const reachable = await ensureGameReachable(c);
      if ("success" in reachable && reachable.success === false) {
        try {
          await callGodot(c, "stop_scene", {});
        } catch {
          // ignore stop errors when play never started properly
        }
        return reachable;
      }

      const readyWarning = await waitForWatchedNodes(
        c,
        args.node_paths,
        args.wait_ready_ms,
      );

      const samples: SampleRow[] = [];
      const started = Date.now();

      while (Date.now() - started < durationMs) {
        await sleep(interval);
        const timestamp_ms = Date.now() - started;

        for (const nodePath of args.node_paths) {
          const result = (await callGodot(c, "get_game_node_properties", {
            node_path: nodePath,
            properties: args.properties,
          })) as GodotPropsResult;

          const props = result.properties ?? {};
          for (const prop of args.properties) {
            if (prop in props) {
              samples.push({
                timestamp_ms,
                node_path: nodePath,
                property: prop,
                value: props[prop],
              });
            }
          }
        }
      }

      await callGodot(c, "stop_scene", {});

      const errorsAfter = extractErrors(
        await callGodot(c, "get_editor_errors", { max_lines: 100 }),
      );
      const logAfter = extractLogLines(
        await callGodot(c, "get_output_log", { max_lines: 200 }),
      );

      const changes: ChangeRow[] = [];
      for (const nodePath of args.node_paths) {
        for (const prop of args.properties) {
          const series = samples
            .filter((s) => s.node_path === nodePath && s.property === prop)
            .sort((a, b) => a.timestamp_ms - b.timestamp_ms);
          for (let i = 1; i < series.length; i++) {
            const prev = series[i - 1]!;
            const curr = series[i]!;
            if (!valuesEqual(prev.value, curr.value)) {
              changes.push({
                node_path: nodePath,
                property: prop,
                from: prev.value,
                to: curr.value,
                at_timestamp_ms: curr.timestamp_ms,
              });
            }
          }
        }
      }

      const runtime_errors = {
        errors: diffNewLines(errorsBefore, errorsAfter),
        log_lines: diffNewLines(logBefore, logAfter),
      };

      return {
        success: true,
        samples,
        changes,
        plain_english: buildWatchPlainEnglish(
          args.node_paths,
          args.properties,
          samples,
          args.duration_seconds,
          args.sample_interval_ms,
          runtime_errors,
          readyWarning,
        ),
        runtime_errors,
      };
    },
    formatResult: (result) => {
      if (
        result &&
        typeof result === "object" &&
        (result as { success?: boolean }).success === false
      ) {
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
          isError: true,
        };
      }
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },
  });
  setToolCategory("watch_game_state", "runtime");
}
