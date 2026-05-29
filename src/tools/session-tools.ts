import { z } from "zod";
import type { GodotClient } from "../godot-client.js";
import {
  callGodot,
  getToolRegistryEntries,
  registerTool,
} from "./helpers.js";
import { ensureEditorSceneOpen } from "./scene-helpers.js";
import { getToolCategory, setToolCategory, type ToolCategory } from "./spec.js";

const CATEGORY_TITLES: Record<ToolCategory, string> = {
  project: "Project & files",
  scene: "Scene editor",
  node: "Nodes & properties",
  script: "Scripts",
  editor: "Editor & play mode",
  input: "Input simulation",
  input_map: "Input map",
  runtime: "Runtime / game tree",
  animation: "Animation",
  animation_tree: "AnimationTree",
  tilemap: "TileMap",
  theme: "UI theme",
  profiling: "Profiling",
  batch: "Batch operations",
  shader: "Shaders",
  export: "Export",
  resource: "Resources",
  physics: "Physics",
  scene3d: "3D scene",
  particles: "Particles",
  navigation: "Navigation",
  audio: "Audio",
  analysis: "Analysis",
  testing: "Testing",
  android: "Android",
};

function categoryTitle(cat: ToolCategory | undefined): string {
  if (!cat) return "Other";
  return CATEGORY_TITLES[cat] ?? cat;
}

interface FsTreeNode {
  name?: string;
  path?: string;
  type?: string;
  children?: FsTreeNode[];
}

function countFilesInTree(
  node: FsTreeNode | undefined,
  extension: string,
): number {
  if (!node) return 0;
  let count = 0;
  if (node.type === "file" && node.name?.endsWith(extension)) {
    count += 1;
  }
  if (Array.isArray(node.children)) {
    for (const child of node.children) {
      count += countFilesInTree(child, extension);
    }
  }
  return count;
}

function countSceneTreeNodes(
  node: unknown,
  depth = 0,
  maxDepth = 4,
): number {
  if (!node || typeof node !== "object" || depth > maxDepth) return 0;
  const n = node as { children?: unknown[] };
  let count = 1;
  if (Array.isArray(n.children)) {
    for (const child of n.children) {
      count += countSceneTreeNodes(child, depth + 1, maxDepth);
    }
  }
  return count;
}

function sceneRootLabel(tree: unknown): string {
  if (!tree || typeof tree !== "object") return "unknown";
  const t = tree as { name?: string; path?: string; type?: string };
  const name = t.name ?? t.path ?? "root";
  const type = t.type ? ` (${t.type})` : "";
  return `${name}${type}`;
}

async function safeGodotCall(
  client: GodotClient,
  command: string,
  params: Record<string, unknown> = {},
): Promise<{ ok: true; data: unknown } | { ok: false; error: string }> {
  try {
    return { ok: true, data: await callGodot(client, command, params) };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { ok: false, error: msg };
  }
}

function buildInitializeSummary(parts: {
  project?: Record<string, unknown>;
  projectError?: string;
  sceneTree?: unknown;
  sceneError?: string;
  editorErrors?: unknown;
  errorsFetchError?: string;
  filesystem?: FsTreeNode;
  fsError?: string;
  sceneFilesystem?: FsTreeNode;
  sceneFsError?: string;
}): string {
  const sentences: string[] = [];

  if (parts.projectError) {
    sentences.push(`Project info could not be loaded (${parts.projectError}).`);
  } else if (parts.project) {
    const name =
      typeof parts.project.project_name === "string"
        ? parts.project.project_name
        : "unknown project";
    const version =
      typeof parts.project.godot_version === "string"
        ? parts.project.godot_version
        : "unknown Godot version";
    const mainScene =
      typeof parts.project.main_scene === "string" && parts.project.main_scene
        ? parts.project.main_scene
        : "(not set in Project Settings → Application → Run)";
    sentences.push(
      `Project "${name}" is open on Godot ${version}. Main scene: ${mainScene}.`,
    );
  }

  const scriptCount = countFilesInTree(parts.filesystem, ".gd");
  if (parts.fsError) {
    sentences.push(`Script filesystem scan failed (${parts.fsError}).`);
  } else {
    sentences.push(
      `About ${scriptCount} .gd script${scriptCount === 1 ? "" : "s"} under res:// (depth 3 scan).`,
    );
  }

  if (parts.sceneFsError) {
    sentences.push(`Scene file scan failed (${parts.sceneFsError}).`);
  } else if (parts.sceneFilesystem !== undefined) {
    const sceneCount = countFilesInTree(parts.sceneFilesystem, ".tscn");
    sentences.push(
      `About ${sceneCount} .tscn scene file${sceneCount === 1 ? "" : "s"} under res:// (depth 3 scan).`,
    );
  }

  if (parts.sceneError) {
    sentences.push(`Editor scene tree could not be read (${parts.sceneError}).`);
  } else if (parts.sceneTree) {
    const tree = (parts.sceneTree as { tree?: unknown }).tree;
    const nodes = countSceneTreeNodes(tree, 0, 4);
    sentences.push(
      `Current editor scene hierarchy: ${sceneRootLabel(tree)} with about ${nodes} node${nodes === 1 ? "" : "s"} visible up to depth 4.`,
    );
  }

  if (parts.errorsFetchError) {
    sentences.push(`Editor errors could not be fetched (${parts.errorsFetchError}).`);
  } else {
    const errResult = parts.editorErrors as { errors?: unknown[] } | undefined;
    const errList = Array.isArray(errResult?.errors) ? errResult!.errors! : [];
    sentences.push(
      `The Godot output/error panel currently shows ${errList.length} error line${errList.length === 1 ? "" : "s"}.`,
    );
  }

  return sentences.join(" ");
}

export function registerSessionTools(client: GodotClient): void {
  registerTool(client, {
    name: "list_available_tools",
    description:
      "Returns every MCP tool name registered in this server build, grouped by category, with a one-line description each. Call this first in a new session before using other tools.",
    schema: z.object({}),
    handler: async () => {
      const byCategory = new Map<string, Array<{ name: string; description: string }>>();

      for (const entry of getToolRegistryEntries()) {
        const title = categoryTitle(getToolCategory(entry.name));
        const list = byCategory.get(title) ?? [];
        list.push({ name: entry.name, description: entry.description });
        byCategory.set(title, list);
      }

      const categories = [...byCategory.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([category, tools]) => ({
          category,
          tools: tools.sort((a, b) => a.name.localeCompare(b.name)),
        }));

      const total = getToolRegistryEntries().length;
      return {
        tool_count: total,
        categories,
        plain_english: `${total} tools are available in this server mode, grouped into ${categories.length} categories. Use the category list to confirm a tool exists before calling it.`,
      };
    },
  });
  setToolCategory("list_available_tools", "project");

  registerTool(client, {
    name: "initialize_session",
    description:
      "Session bootstrap: loads project info, editor scene tree (depth 4), editor errors, and a .gd filesystem scan, then returns a plain_english orientation summary. Call after list_available_tools at the start of every game-dev session.",
    schema: z.object({}),
    handler: async (c) => {
      const projectResult = await safeGodotCall(c, "get_project_info", {});
      await ensureEditorSceneOpen(c);
      const sceneResult = await safeGodotCall(c, "get_scene_tree", {
        max_depth: 4,
        auto_open: true,
      });
      const errorsResult = await safeGodotCall(c, "get_editor_errors", { max_lines: 100 });
      const fsResult = await safeGodotCall(c, "get_filesystem_tree", {
        path: "res://",
        filter: "*.gd",
        max_depth: 3,
      });
      const sceneFsResult = await safeGodotCall(c, "get_filesystem_tree", {
        path: "res://",
        filter: "*.tscn",
        max_depth: 3,
      });

      const project =
        projectResult.ok && projectResult.data && typeof projectResult.data === "object"
          ? (projectResult.data as Record<string, unknown>)
          : undefined;

      const filesystem =
        fsResult.ok && fsResult.data && typeof fsResult.data === "object"
          ? ((fsResult.data as { tree?: FsTreeNode }).tree ?? undefined)
          : undefined;
      const sceneFilesystem =
        sceneFsResult.ok && sceneFsResult.data && typeof sceneFsResult.data === "object"
          ? ((sceneFsResult.data as { tree?: FsTreeNode }).tree ?? undefined)
          : undefined;

      const plain_english = buildInitializeSummary({
        project,
        projectError: projectResult.ok ? undefined : projectResult.error,
        sceneTree: sceneResult.ok ? sceneResult.data : undefined,
        sceneError: sceneResult.ok ? undefined : sceneResult.error,
        editorErrors: errorsResult.ok ? errorsResult.data : undefined,
        errorsFetchError: errorsResult.ok ? undefined : errorsResult.error,
        filesystem,
        fsError: fsResult.ok ? undefined : fsResult.error,
        sceneFilesystem,
        sceneFsError: sceneFsResult.ok ? undefined : sceneFsResult.error,
      });

      return {
        project_info: projectResult.ok ? projectResult.data : { error: projectResult.error },
        scene_tree: sceneResult.ok ? sceneResult.data : { error: sceneResult.error },
        editor_errors: errorsResult.ok ? errorsResult.data : { error: errorsResult.error },
        filesystem_tree: fsResult.ok ? fsResult.data : { error: fsResult.error },
        plain_english,
      };
    },
  });
  setToolCategory("initialize_session", "project");
}
