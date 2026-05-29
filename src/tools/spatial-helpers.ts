export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export interface SpatialNode {
  name: string;
  path: string;
  class: string;
  spatial_role: "wall_or_floor" | "visual" | "character" | "area" | "other";
  global_position: Vec3;
  rotation_degrees: Vec3;
  scale: Vec3;
}

const NODE3D_TYPE_RE = /3D$/;

export function isNode3DType(type: string): boolean {
  return type === "Node3D" || NODE3D_TYPE_RE.test(type);
}

export function classifySpatialRole(className: string): SpatialNode["spatial_role"] {
  if (className === "StaticBody3D" || className.startsWith("CSG")) {
    return "wall_or_floor";
  }
  if (className === "MeshInstance3D") {
    return "visual";
  }
  if (
    className === "CharacterBody3D" ||
    className === "RigidBody3D" ||
    className === "AnimatableBody3D"
  ) {
    return "character";
  }
  if (className === "Area3D") {
    return "area";
  }
  return "other";
}

export function parseVec3(value: unknown, fallback: Vec3 = { x: 0, y: 0, z: 0 }): Vec3 {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const o = value as Record<string, unknown>;
    return {
      x: Number(o.x ?? 0),
      y: Number(o.y ?? 0),
      z: Number(o.z ?? 0),
    };
  }
  return fallback;
}

export function formatVec3(v: Vec3): string {
  return `${round1(v.x)} ${round1(v.y)} ${round1(v.z)}`;
}

function round1(n: number): string {
  const r = Math.round(n * 10) / 10;
  return Number.isInteger(r) ? String(r) : r.toFixed(1);
}

export function distanceXZ(a: Vec3, b: Vec3): number {
  const dx = a.x - b.x;
  const dz = a.z - b.z;
  return Math.sqrt(dx * dx + dz * dz);
}

export function directionLabel(from: Vec3, to: Vec3): string {
  const dx = to.x - from.x;
  const dz = to.z - from.z;
  if (Math.abs(dx) >= Math.abs(dz)) {
    return dx >= 0 ? "to the right" : "to the left";
  }
  return dz >= 0 ? "forward" : "backward";
}

export interface SceneTreeNode {
  name: string;
  type: string;
  path: string;
  children?: SceneTreeNode[];
}

export function walkSceneTree(
  node: SceneTreeNode,
  visit: (node: SceneTreeNode) => void,
): void {
  visit(node);
  for (const child of node.children ?? []) {
    walkSceneTree(child, visit);
  }
}

export function buildSpatialPlainEnglish(
  nodes: SpatialNode[],
  truncationNote?: string,
): string {
  const sentences: string[] = [];
  if (truncationNote) {
    sentences.push(truncationNote);
  }
  sentences.push(`scene contains ${nodes.length} spatial node${nodes.length === 1 ? "" : "s"}.`);

  if (nodes.length === 0) {
    return sentences.join(" ");
  }

  const characters = nodes.filter((n) => n.spatial_role === "character");
  const walls = nodes.filter((n) => n.spatial_role === "wall_or_floor");
  const primary =
    characters.find((n) => /player/i.test(n.name)) ?? characters[0] ?? null;

  if (primary) {
    sentences.push(
      `${primary.name} ${primary.class} is at world position ${formatVec3(primary.global_position)}.`,
    );

    for (const wall of walls) {
      if (wall.path === primary.path) continue;
      const dist = distanceXZ(primary.global_position, wall.global_position);
      if (dist < 0.05) continue;
      const dir = directionLabel(primary.global_position, wall.global_position);
      sentences.push(
        `${wall.name} ${wall.class} is ${round1(dist)} meters away at position ${formatVec3(wall.global_position)} (${dir} of ${primary.name}).`,
      );
    }

    const floor = walls.find(
      (w) =>
        w.path !== primary.path &&
        Math.abs(w.global_position.x - primary.global_position.x) < 0.25 &&
        Math.abs(w.global_position.z - primary.global_position.z) < 0.25 &&
        w.global_position.y < primary.global_position.y - 0.05,
    );
    if (floor) {
      sentences.push(
        `${floor.name} ${floor.class} is directly below at position ${formatVec3(floor.global_position)}.`,
      );
    }

    let nearest: SpatialNode | null = null;
    let nearestDist = Infinity;
    for (const wall of walls) {
      if (wall.path === primary.path) continue;
      const d = distanceXZ(primary.global_position, wall.global_position);
      if (d > 0.05 && d < nearestDist) {
        nearestDist = d;
        nearest = wall;
      }
    }
    if (nearest) {
      sentences.push(
        `nearest wall_or_floor to ${primary.name} is ${round1(nearestDist)} meters ${directionLabel(primary.global_position, nearest.global_position)} (${nearest.name} ${nearest.class}).`,
      );
    }
  } else {
    const sample = nodes.slice(0, 5);
    for (const n of sample) {
      sentences.push(
        `${n.name} ${n.class} (${n.spatial_role}) is at world position ${formatVec3(n.global_position)}.`,
      );
    }
    if (nodes.length > 5) {
      sentences.push(`…and ${nodes.length - 5} more spatial nodes.`);
    }
  }

  return sentences.join(" ");
}
