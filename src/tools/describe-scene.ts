import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import { callGodot, registerTool } from "./helpers.js";
import { setToolCategory } from "./spec.js";
import {
  buildSpatialPlainEnglish,
  classifySpatialRole,
  isNode3DType,
  parseVec3,
  walkSceneTree,
  type SceneTreeNode,
  type SpatialNode,
  type Vec3,
} from "./spatial-helpers.js";

const ACTIONS = [
  "spatial_3d",
  "spatial_2d",
  "ui_outline",
  "tilemap_grid",
  "animation_state",
  "asset_inventory",
  "scene_diff",
  "visible_nodes",
  "physics_events",
] as const;

type DescribeAction = (typeof ACTIONS)[number];

interface NodeProps {
  properties?: Record<string, unknown>;
  node_path?: string;
  type?: string;
}

const NODE_2D_RE = /(2D|Sprite|TileMap|Polygon2D|Line2D|CanvasItem)$/;
const CONTROL_TYPES = new Set([
  "Control",
  "Button",
  "Label",
  "Panel",
  "PanelContainer",
  "VBoxContainer",
  "HBoxContainer",
  "GridContainer",
  "MarginContainer",
  "CenterContainer",
  "TextureRect",
  "ColorRect",
  "RichTextLabel",
  "LineEdit",
  "TextEdit",
  "OptionButton",
  "CheckBox",
  "CheckButton",
  "Slider",
  "HSlider",
  "VSlider",
  "ProgressBar",
  "ScrollContainer",
  "TabContainer",
  "ItemList",
  "Tree",
]);

function isNode2D(type: string): boolean {
  return (
    type === "Node2D" ||
    NODE_2D_RE.test(type) ||
    type === "CanvasLayer" ||
    type === "Camera2D"
  );
}

function isControl(type: string): boolean {
  return CONTROL_TYPES.has(type) || type.endsWith("Container");
}

function round1(n: number): string {
  const r = Math.round(n * 10) / 10;
  return Number.isInteger(r) ? String(r) : r.toFixed(1);
}

function vec2Of(value: unknown): { x: number; y: number } {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const o = value as Record<string, unknown>;
    return { x: Number(o.x ?? 0), y: Number(o.y ?? 0) };
  }
  return { x: 0, y: 0 };
}

async function mapInBatches<T, R>(
  items: T[],
  batchSize: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const out: R[] = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = await Promise.all(items.slice(i, i + batchSize).map(fn));
    out.push(...batch);
  }
  return out;
}

async function getEditedSceneTree(
  client: GodotClient,
  maxDepth?: number,
): Promise<SceneTreeNode | undefined> {
  const params: Record<string, unknown> = { auto_open: true };
  if (maxDepth !== undefined) params.max_depth = maxDepth;
  const result = (await callGodot(client, "get_scene_tree", params)) as {
    tree?: SceneTreeNode;
  };
  return result.tree;
}

// ── spatial_3d ──────────────────────────────────────────────────────────────

async function actionSpatial3D(
  client: GodotClient,
  args: { max_nodes: number },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) {
    return { nodes: [], plain_english: "No edited scene; nothing to describe in 3D." };
  }

  const candidates: SceneTreeNode[] = [];
  walkSceneTree(tree, (n) => {
    if (isNode3DType(n.type)) candidates.push(n);
  });

  const toFetch = candidates.slice(0, args.max_nodes);
  const truncation =
    candidates.length > args.max_nodes
      ? `Scene truncated: ${candidates.length - args.max_nodes} Node3D node(s) skipped (limit max_nodes=${args.max_nodes}).`
      : undefined;

  const spatial = await mapInBatches(toFetch, 10, async (node) => {
    const props = (await callGodot(client, "get_node_properties", {
      node_path: node.path,
    })) as NodeProps;
    const p = props.properties ?? {};
    return {
      name: node.name,
      path: props.node_path ?? node.path,
      class: props.type ?? node.type,
      spatial_role: classifySpatialRole(node.type),
      global_position: parseVec3(p.global_position),
      rotation_degrees: parseVec3(p.rotation_degrees),
      scale: parseVec3(p.scale, { x: 1, y: 1, z: 1 }),
    } satisfies SpatialNode;
  });

  return {
    nodes: spatial,
    truncated: Boolean(truncation),
    plain_english: buildSpatialPlainEnglish(spatial, truncation),
  };
}

// ── spatial_2d ──────────────────────────────────────────────────────────────

interface Spatial2DNode {
  name: string;
  path: string;
  class: string;
  position: { x: number; y: number };
  global_position: { x: number; y: number };
  z_index: number;
  visible: boolean;
  modulate_alpha: number;
}

async function actionSpatial2D(
  client: GodotClient,
  args: { max_nodes: number },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) {
    return { nodes: [], plain_english: "No edited scene; nothing to describe in 2D." };
  }

  const candidates: SceneTreeNode[] = [];
  walkSceneTree(tree, (n) => {
    if (isNode2D(n.type) && !isControl(n.type)) candidates.push(n);
  });

  const toFetch = candidates.slice(0, args.max_nodes);
  const truncation =
    candidates.length > args.max_nodes
      ? `Scene truncated: ${candidates.length - args.max_nodes} Node2D node(s) skipped.`
      : undefined;

  const nodes: Spatial2DNode[] = await mapInBatches(toFetch, 10, async (node) => {
    const props = (await callGodot(client, "get_node_properties", {
      node_path: node.path,
    })) as NodeProps;
    const p = props.properties ?? {};
    const modulate = vec2Of(p.modulate);
    const modulateAlpha =
      p.modulate && typeof p.modulate === "object" && "a" in (p.modulate as object)
        ? Number((p.modulate as { a: number }).a ?? 1)
        : 1;
    return {
      name: node.name,
      path: props.node_path ?? node.path,
      class: props.type ?? node.type,
      position: vec2Of(p.position),
      global_position: vec2Of(p.global_position),
      z_index: Number(p.z_index ?? 0),
      visible: p.visible !== false,
      modulate_alpha: modulate ? modulateAlpha : 1,
    };
  });

  const sentences: string[] = [];
  if (truncation) sentences.push(truncation);
  sentences.push(`Scene contains ${nodes.length} 2D node(s).`);

  if (nodes.length > 0) {
    const minX = Math.min(...nodes.map((n) => n.global_position.x));
    const maxX = Math.max(...nodes.map((n) => n.global_position.x));
    const minY = Math.min(...nodes.map((n) => n.global_position.y));
    const maxY = Math.max(...nodes.map((n) => n.global_position.y));
    sentences.push(
      `Bounds X ${round1(minX)} to ${round1(maxX)}, Y ${round1(minY)} to ${round1(maxY)} (Godot 2D Y points down).`,
    );

    const byZ = [...nodes].sort((a, b) => b.z_index - a.z_index);
    const top = byZ.slice(0, 5);
    for (const n of top) {
      sentences.push(
        `${n.name} ${n.class} at (${round1(n.global_position.x)}, ${round1(n.global_position.y)}) z=${n.z_index}${n.visible ? "" : " hidden"}.`,
      );
    }
    if (byZ.length > 5) sentences.push(`…and ${byZ.length - 5} more 2D node(s).`);
  }

  return {
    nodes,
    plain_english: sentences.join(" "),
  };
}

// ── ui_outline ──────────────────────────────────────────────────────────────

interface UiNode {
  name: string;
  path: string;
  class: string;
  depth: number;
  anchor: { left: number; top: number; right: number; bottom: number };
  size: { x: number; y: number };
  position: { x: number; y: number };
  text?: string;
  visible: boolean;
}

const ANCHOR_PRESETS: Record<string, string> = {
  "0,0,0,0": "top-left",
  "0,0,1,0": "top-wide",
  "1,0,1,0": "top-right",
  "0,0,0,1": "left-wide",
  "0,0,1,1": "full-rect",
  "1,0,1,1": "right-wide",
  "0,1,0,1": "bottom-left",
  "0,1,1,1": "bottom-wide",
  "1,1,1,1": "bottom-right",
  "0.5,0.5,0.5,0.5": "center",
};

function anchorLabel(a: UiNode["anchor"]): string {
  const key = `${a.left},${a.top},${a.right},${a.bottom}`;
  return ANCHOR_PRESETS[key] ?? `custom(${key})`;
}

async function actionUiOutline(
  client: GodotClient,
  args: { max_nodes: number },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) {
    return { nodes: [], plain_english: "No edited scene; nothing to describe for UI." };
  }

  const candidates: Array<{ node: SceneTreeNode; depth: number }> = [];
  const walk = (n: SceneTreeNode, depth: number) => {
    if (isControl(n.type)) candidates.push({ node: n, depth });
    for (const c of n.children ?? []) walk(c, depth + 1);
  };
  walk(tree, 0);

  const toFetch = candidates.slice(0, args.max_nodes);
  const truncation =
    candidates.length > args.max_nodes
      ? `UI truncated: ${candidates.length - args.max_nodes} Control node(s) skipped.`
      : undefined;

  const nodes: UiNode[] = await mapInBatches(toFetch, 10, async ({ node, depth }) => {
    const props = (await callGodot(client, "get_node_properties", {
      node_path: node.path,
    })) as NodeProps;
    const p = props.properties ?? {};
    return {
      name: node.name,
      path: props.node_path ?? node.path,
      class: props.type ?? node.type,
      depth,
      anchor: {
        left: Number(p.anchor_left ?? 0),
        top: Number(p.anchor_top ?? 0),
        right: Number(p.anchor_right ?? 0),
        bottom: Number(p.anchor_bottom ?? 0),
      },
      size: vec2Of(p.size),
      position: vec2Of(p.position),
      text: typeof p.text === "string" ? p.text : undefined,
      visible: p.visible !== false,
    };
  });

  const lines: string[] = [];
  if (truncation) lines.push(truncation);
  lines.push(`UI tree: ${nodes.length} Control node(s).`);

  for (const n of nodes) {
    const indent = "  ".repeat(Math.max(0, n.depth));
    const anchor = anchorLabel(n.anchor);
    const size = `${round1(n.size.x)}×${round1(n.size.y)}`;
    const text = n.text ? ` "${n.text.slice(0, 30)}${n.text.length > 30 ? "…" : ""}"` : "";
    const hidden = n.visible ? "" : " (hidden)";
    lines.push(`${indent}- ${n.name} ${n.class} [${anchor}] ${size}${text}${hidden}`);
  }

  return {
    nodes,
    plain_english: lines.join("\n"),
  };
}

// ── tilemap_grid ────────────────────────────────────────────────────────────

interface TileCell {
  x: number;
  y: number;
  source_id: number;
}

async function actionTilemapGrid(
  client: GodotClient,
  args: { node_path?: string; max_cells: number },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) {
    return { plain_english: "No edited scene." };
  }

  const tilemaps: SceneTreeNode[] = [];
  walkSceneTree(tree, (n) => {
    if (n.type === "TileMapLayer" || n.type === "TileMap") tilemaps.push(n);
  });

  if (tilemaps.length === 0) {
    return { tilemaps: [], plain_english: "No TileMapLayer/TileMap in this scene." };
  }

  const targetPath = args.node_path ?? tilemaps[0]!.path;
  const info = (await callGodot(client, "tilemap_get_info", {
    node_path: targetPath,
  })) as {
    used_cells?: number;
    tile_size?: number[];
    tile_set_sources?: Array<Record<string, unknown>>;
  };
  const cellsResult = (await callGodot(client, "tilemap_get_used_cells", {
    node_path: targetPath,
    max_count: args.max_cells,
  })) as { cells?: TileCell[]; total?: number; returned?: number };

  const cells = cellsResult.cells ?? [];
  const minX = cells.length ? Math.min(...cells.map((c) => c.x)) : 0;
  const maxX = cells.length ? Math.max(...cells.map((c) => c.x)) : 0;
  const minY = cells.length ? Math.min(...cells.map((c) => c.y)) : 0;
  const maxY = cells.length ? Math.max(...cells.map((c) => c.y)) : 0;

  const bySource = new Map<number, number>();
  for (const c of cells) {
    bySource.set(c.source_id, (bySource.get(c.source_id) ?? 0) + 1);
  }

  const sentences = [
    `TileMap "${targetPath}" has ${info.used_cells ?? cellsResult.total ?? 0} used cell(s) over bounds X ${minX}..${maxX}, Y ${minY}..${maxY}.`,
  ];
  if (info.tile_size) {
    sentences.push(`Tile size ${info.tile_size[0]}×${info.tile_size[1]} px.`);
  }
  if (info.tile_set_sources?.length) {
    sentences.push(
      `${info.tile_set_sources.length} TileSet source(s); cells per source: ${[...bySource.entries()].map(([id, n]) => `${id}=${n}`).join(", ")}.`,
    );
  }
  if (cellsResult.total && cellsResult.returned && cellsResult.total > cellsResult.returned) {
    sentences.push(
      `Returned first ${cellsResult.returned} of ${cellsResult.total} cells (increase max_cells for more).`,
    );
  }

  return {
    target_path: targetPath,
    all_tilemaps: tilemaps.map((t) => ({ name: t.name, path: t.path, type: t.type })),
    bounds: { min_x: minX, max_x: maxX, min_y: minY, max_y: maxY },
    cells_by_source: Object.fromEntries(bySource),
    cells,
    plain_english: sentences.join(" "),
  };
}

// ── animation_state ─────────────────────────────────────────────────────────

async function actionAnimationState(
  client: GodotClient,
  args: { node_path?: string },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) return { plain_english: "No edited scene." };

  const players: SceneTreeNode[] = [];
  walkSceneTree(tree, (n) => {
    if (n.type === "AnimationPlayer" || n.type === "AnimationTree") players.push(n);
  });

  if (players.length === 0) {
    return { players: [], plain_english: "No AnimationPlayer or AnimationTree in this scene." };
  }

  const targets = args.node_path
    ? players.filter((p) => p.path === args.node_path || p.name === args.node_path)
    : players;

  const results = await mapInBatches(targets, 5, async (node) => {
    try {
      const props = (await callGodot(client, "get_node_properties", {
        node_path: node.path,
      })) as NodeProps;
      const p = props.properties ?? {};
      const info: Record<string, unknown> = {
        name: node.name,
        path: node.path,
        type: node.type,
        autoplay: p.autoplay ?? "",
        current_animation: p.current_animation ?? "",
        assigned_animation: p.assigned_animation ?? "",
        speed_scale: Number(p.speed_scale ?? 1),
      };
      if (node.type === "AnimationPlayer") {
        try {
          const list = (await callGodot(client, "list_animations", {
            node_path: node.path,
          })) as { animations?: string[] };
          info.animation_count = list.animations?.length ?? 0;
          info.animations = list.animations ?? [];
        } catch {
          info.animations_error = true;
        }
      }
      return info;
    } catch (err) {
      return {
        name: node.name,
        path: node.path,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  });

  const sentences: string[] = [
    `${results.length} animation node(s) found.`,
  ];
  for (const r of results) {
    if ("error" in r) {
      sentences.push(`${r.name}: error (${r.error}).`);
      continue;
    }
    const cur = r.current_animation || "(idle)";
    const auto = r.autoplay ? `, autoplay=${r.autoplay}` : "";
    const count = "animation_count" in r ? ` ${r.animation_count} animation(s)` : "";
    sentences.push(`${r.name} ${r.type}: current=${cur}${auto}${count}, speed=${r.speed_scale}.`);
  }

  return { players: results, plain_english: sentences.join(" ") };
}

// ── asset_inventory ─────────────────────────────────────────────────────────

interface FsNode {
  name?: string;
  path?: string;
  type?: string;
  children?: FsNode[];
}

function countByExt(node: FsNode | undefined, counts: Map<string, number>): void {
  if (!node) return;
  if (node.type === "file" && node.name) {
    const idx = node.name.lastIndexOf(".");
    if (idx > 0) {
      const ext = node.name.slice(idx).toLowerCase();
      counts.set(ext, (counts.get(ext) ?? 0) + 1);
    }
  }
  for (const c of node.children ?? []) countByExt(c, counts);
}

const ASSET_GROUPS: Record<string, string[]> = {
  scripts: [".gd", ".cs"],
  scenes: [".tscn", ".scn"],
  resources: [".tres", ".res"],
  textures: [".png", ".jpg", ".jpeg", ".webp", ".svg"],
  meshes: [".gltf", ".glb", ".obj", ".dae", ".fbx"],
  audio: [".ogg", ".wav", ".mp3"],
  shaders: [".gdshader", ".gdshaderinc"],
  fonts: [".ttf", ".otf", ".woff", ".woff2"],
};

async function actionAssetInventory(
  client: GodotClient,
  args: { path: string; max_depth: number },
): Promise<Record<string, unknown>> {
  const fs = (await callGodot(client, "get_filesystem_tree", {
    path: args.path,
    max_depth: args.max_depth,
  })) as { tree?: FsNode };

  const counts = new Map<string, number>();
  countByExt(fs.tree, counts);

  const groups: Record<string, { total: number; extensions: Record<string, number> }> = {};
  let assignedTotal = 0;
  for (const [group, exts] of Object.entries(ASSET_GROUPS)) {
    const extMap: Record<string, number> = {};
    let total = 0;
    for (const ext of exts) {
      const n = counts.get(ext) ?? 0;
      if (n > 0) {
        extMap[ext] = n;
        total += n;
      }
    }
    if (total > 0) groups[group] = { total, extensions: extMap };
    assignedTotal += total;
  }

  const other: Record<string, number> = {};
  let otherTotal = 0;
  for (const [ext, n] of counts) {
    const known = Object.values(ASSET_GROUPS).some((list) => list.includes(ext));
    if (!known) {
      other[ext] = n;
      otherTotal += n;
    }
  }
  if (otherTotal > 0) {
    groups.other = { total: otherTotal, extensions: other };
  }

  const sentences: string[] = [
    `Asset inventory under ${args.path} (depth ${args.max_depth}):`,
  ];
  const order = ["scripts", "scenes", "textures", "meshes", "audio", "shaders", "resources", "fonts", "other"];
  for (const key of order) {
    const g = groups[key];
    if (!g) continue;
    const extDetail = Object.entries(g.extensions).map(([e, n]) => `${n} ${e}`).join(", ");
    sentences.push(`${g.total} ${key} (${extDetail}).`);
  }
  sentences.push(
    `Cursor cannot generate audio, textures, meshes, or fonts — if any of these counts are 0 or low and your game needs them, ask the user.`,
  );

  return {
    path: args.path,
    groups,
    total_files_indexed: assignedTotal + otherTotal,
    plain_english: sentences.join(" "),
  };
}

// ── scene_diff ──────────────────────────────────────────────────────────────

const sceneSnapshots = new Map<string, Map<string, string>>();

function flattenForDiff(tree: SceneTreeNode): Map<string, string> {
  const map = new Map<string, string>();
  walkSceneTree(tree, (n) => {
    map.set(n.path, n.type);
  });
  return map;
}

async function actionSceneDiff(
  client: GodotClient,
  args: { snapshot_key: string; save_new_snapshot: boolean },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) return { plain_english: "No edited scene." };
  const flat = flattenForDiff(tree);

  const prior = sceneSnapshots.get(args.snapshot_key);
  if (args.save_new_snapshot) {
    sceneSnapshots.set(args.snapshot_key, flat);
  }

  if (!prior) {
    return {
      snapshot_key: args.snapshot_key,
      first_snapshot: true,
      node_count: flat.size,
      plain_english: `First snapshot for key "${args.snapshot_key}" — ${flat.size} node(s) recorded. Call again later to diff.`,
    };
  }

  const added: Array<{ path: string; type: string }> = [];
  const removed: Array<{ path: string; type: string }> = [];
  const changed: Array<{ path: string; from: string; to: string }> = [];

  for (const [path, type] of flat) {
    if (!prior.has(path)) {
      added.push({ path, type });
    } else if (prior.get(path) !== type) {
      changed.push({ path, from: prior.get(path)!, to: type });
    }
  }
  for (const [path, type] of prior) {
    if (!flat.has(path)) removed.push({ path, type });
  }

  const sentences = [
    `Diff vs snapshot "${args.snapshot_key}": +${added.length} added, -${removed.length} removed, ~${changed.length} type changes.`,
  ];
  if (added.length) sentences.push(`Added: ${added.slice(0, 5).map((a) => `${a.path}(${a.type})`).join(", ")}${added.length > 5 ? "…" : ""}.`);
  if (removed.length) sentences.push(`Removed: ${removed.slice(0, 5).map((a) => `${a.path}(${a.type})`).join(", ")}${removed.length > 5 ? "…" : ""}.`);
  if (changed.length) sentences.push(`Changed: ${changed.slice(0, 5).map((a) => `${a.path}: ${a.from}→${a.to}`).join(", ")}${changed.length > 5 ? "…" : ""}.`);

  return {
    snapshot_key: args.snapshot_key,
    added,
    removed,
    changed,
    node_count: flat.size,
    plain_english: sentences.join(" "),
  };
}

// ── visible_nodes (frustum approximation) ───────────────────────────────────

interface Camera3DInfo {
  position: Vec3;
  rotation_degrees: Vec3;
  fov: number;
  far: number;
  near: number;
}

function withinXZRange(p: Vec3, cam: Vec3, far: number): boolean {
  const dx = p.x - cam.x;
  const dz = p.z - cam.z;
  return Math.sqrt(dx * dx + dz * dz) <= far;
}

async function actionVisibleNodes(
  client: GodotClient,
  args: { radius: number; max_nodes: number },
): Promise<Record<string, unknown>> {
  const tree = await getEditedSceneTree(client);
  if (!tree) return { plain_english: "No edited scene." };

  let camInfo: Camera3DInfo | null = null;
  let camLabel = "(no Camera3D found)";

  const cameras: SceneTreeNode[] = [];
  walkSceneTree(tree, (n) => {
    if (n.type === "Camera3D") cameras.push(n);
  });

  if (cameras.length > 0) {
    try {
      const props = (await callGodot(client, "get_node_properties", {
        node_path: cameras[0]!.path,
      })) as NodeProps;
      const p = props.properties ?? {};
      camInfo = {
        position: parseVec3(p.global_position),
        rotation_degrees: parseVec3(p.rotation_degrees),
        fov: Number(p.fov ?? 75),
        far: Number(p.far ?? 4000),
        near: Number(p.near ?? 0.05),
      };
      camLabel = `Camera3D "${cameras[0]!.path}" at ${round1(camInfo.position.x)},${round1(camInfo.position.y)},${round1(camInfo.position.z)} fov=${camInfo.fov} far=${camInfo.far}`;
    } catch {
      // fall through
    }
  } else {
    try {
      const editorCam = (await callGodot(client, "get_editor_camera", {})) as Record<
        string,
        unknown
      >;
      camInfo = {
        position: parseVec3(editorCam.position),
        rotation_degrees: parseVec3(editorCam.rotation_degrees),
        fov: Number(editorCam.fov ?? 75),
        far: 200,
        near: 0.05,
      };
      camLabel = `(no scene Camera3D — using editor camera at ${round1(camInfo.position.x)},${round1(camInfo.position.y)},${round1(camInfo.position.z)})`;
    } catch {
      camInfo = null;
    }
  }

  if (!camInfo) {
    return {
      plain_english:
        "No Camera3D in scene and editor camera unavailable; cannot compute visibility.",
    };
  }

  const candidates: SceneTreeNode[] = [];
  walkSceneTree(tree, (n) => {
    if (isNode3DType(n.type) && n.type !== "Camera3D") candidates.push(n);
  });

  const radius = args.radius > 0 ? args.radius : camInfo.far;
  const nearby = await mapInBatches(candidates.slice(0, args.max_nodes), 10, async (node) => {
    const props = (await callGodot(client, "get_node_properties", {
      node_path: node.path,
    })) as NodeProps;
    const p = props.properties ?? {};
    return {
      name: node.name,
      path: node.path,
      class: node.type,
      global_position: parseVec3(p.global_position),
    };
  });

  const visible = nearby.filter((n) => withinXZRange(n.global_position, camInfo!.position, radius));
  visible.sort((a, b) => {
    const dxA = a.global_position.x - camInfo!.position.x;
    const dzA = a.global_position.z - camInfo!.position.z;
    const dxB = b.global_position.x - camInfo!.position.x;
    const dzB = b.global_position.z - camInfo!.position.z;
    return dxA * dxA + dzA * dzA - (dxB * dxB + dzB * dzB);
  });

  const sentences = [
    `${camLabel}.`,
    `${visible.length} Node3D within ${radius} m XZ of camera (frustum check approximate, ignores rotation).`,
  ];
  for (const v of visible.slice(0, 8)) {
    const dx = v.global_position.x - camInfo.position.x;
    const dz = v.global_position.z - camInfo.position.z;
    const d = Math.sqrt(dx * dx + dz * dz);
    sentences.push(`${v.name} ${v.class} at ${round1(v.global_position.x)},${round1(v.global_position.y)},${round1(v.global_position.z)} (~${round1(d)}m).`);
  }
  if (visible.length > 8) sentences.push(`…and ${visible.length - 8} more.`);

  return {
    camera: camInfo,
    camera_label: camLabel,
    visible,
    plain_english: sentences.join(" "),
  };
}

// ── physics_events (delegates to watch_signals on common physics signals) ────

async function actionPhysicsEvents(
  client: GodotClient,
  args: { node_paths: string[]; duration_seconds: number },
): Promise<Record<string, unknown>> {
  if (args.node_paths.length === 0) {
    return {
      plain_english:
        "physics_events needs node_paths (e.g. CharacterBody3D, RigidBody3D, Area3D). Pass node_paths:[\"Player\"] for a start.",
    };
  }

  const duration_ms = Math.max(1000, args.duration_seconds * 1000);

  try {
    const result = (await callGodot(client, "watch_signals", {
      node_paths: args.node_paths,
      signal_filter: ["body_entered", "body_exited", "area_entered", "area_exited"],
      duration_ms,
    })) as Record<string, unknown>;
    const events = Array.isArray(result.events) ? (result.events as unknown[]) : [];
    return {
      ...result,
      plain_english: `Watched ${args.node_paths.length} node(s) for ${args.duration_seconds}s; captured ${events.length} physics event(s). Use watch_game_state for property sampling instead of events.`,
    };
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : String(err),
      hint:
        "physics_events requires the runtime autoload (mcp_game_inspector_service.gd) and the game running. Press Play, or call watch_game_state which plays the scene for you.",
      plain_english:
        "Could not watch physics signals — the game probably is not running or runtime autoloads are missing.",
    };
  }
}

// ── registration ────────────────────────────────────────────────────────────

type ActionArgs = {
  action: DescribeAction;
  max_nodes: number;
  max_cells: number;
  max_depth: number;
  node_path?: string;
  node_paths?: string[];
  path: string;
  radius: number;
  snapshot_key: string;
  save_new_snapshot: boolean;
  duration_seconds: number;
};

export function registerDescribeSceneTool(client: GodotClient): void {
  registerTool(client, {
    name: "describe_scene",
    description:
      'Scene translation layer. One tool, eight actions: ' +
      'spatial_3d, spatial_2d, ui_outline, tilemap_grid, animation_state, asset_inventory, scene_diff, visible_nodes, physics_events. ' +
      'Returns structured data plus plain_english Cursor can read directly. Prefer this over many low-level get_node_properties calls.',
    schema: z.object({
      action: z
        .enum(ACTIONS)
        .describe("Which translation to run; see tool description for the list."),
      max_nodes: z
        .number()
        .optional()
        .default(50)
        .describe("Limit nodes scanned (spatial_*, ui_outline, visible_nodes)."),
      max_cells: z
        .number()
        .optional()
        .default(500)
        .describe("Limit TileMap cells returned (tilemap_grid)."),
      max_depth: z
        .number()
        .optional()
        .default(3)
        .describe("Filesystem scan depth (asset_inventory)."),
      node_path: z
        .string()
        .optional()
        .describe("Target TileMapLayer / AnimationPlayer node path."),
      node_paths: z
        .array(z.string())
        .optional()
        .describe("Target nodes (physics_events)."),
      path: z
        .string()
        .optional()
        .default("res://")
        .describe("Filesystem root for asset_inventory."),
      radius: z
        .number()
        .optional()
        .default(0)
        .describe("XZ radius from camera for visible_nodes (0 = use camera.far)."),
      snapshot_key: z
        .string()
        .optional()
        .default("default")
        .describe("Identifier for scene_diff snapshot bucket."),
      save_new_snapshot: z
        .boolean()
        .optional()
        .default(true)
        .describe("Update the snapshot after diffing (scene_diff)."),
      duration_seconds: z
        .number()
        .optional()
        .default(3)
        .describe("Watch window for physics_events."),
    }),
    handler: async (c, rawArgs) => {
      const args = rawArgs as ActionArgs;
      switch (args.action) {
        case "spatial_3d":
          return actionSpatial3D(c, args);
        case "spatial_2d":
          return actionSpatial2D(c, args);
        case "ui_outline":
          return actionUiOutline(c, args);
        case "tilemap_grid":
          return actionTilemapGrid(c, { node_path: args.node_path, max_cells: args.max_cells });
        case "animation_state":
          return actionAnimationState(c, { node_path: args.node_path });
        case "asset_inventory":
          return actionAssetInventory(c, { path: args.path, max_depth: args.max_depth });
        case "scene_diff":
          return actionSceneDiff(c, {
            snapshot_key: args.snapshot_key,
            save_new_snapshot: args.save_new_snapshot,
          });
        case "visible_nodes":
          return actionVisibleNodes(c, { radius: args.radius, max_nodes: args.max_nodes });
        case "physics_events":
          return actionPhysicsEvents(c, {
            node_paths: args.node_paths ?? [],
            duration_seconds: args.duration_seconds,
          });
        default:
          return { plain_english: `Unknown action: ${args.action}` };
      }
    },
  });
  setToolCategory("describe_scene", "scene");
}
