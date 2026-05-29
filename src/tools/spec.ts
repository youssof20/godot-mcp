import { z, type ZodObject, type ZodRawShape } from "zod";
import type { GodotClient } from "../godot-client.js";
import { callGodot, registerTool } from "./helpers.js";
import { getTypedSchema } from "./typed-schemas.js";

export type ToolCategory =
  | "project"
  | "scene"
  | "node"
  | "script"
  | "editor"
  | "input"
  | "input_map"
  | "runtime"
  | "animation"
  | "animation_tree"
  | "tilemap"
  | "theme"
  | "profiling"
  | "batch"
  | "shader"
  | "export"
  | "resource"
  | "physics"
  | "scene3d"
  | "particles"
  | "navigation"
  | "audio"
  | "analysis"
  | "testing"
  | "android";

export const PASSTHROUGH_SCHEMA = z.object({}).passthrough();

export interface GodotToolSpec {
  name: string;
  description: string;
  category: ToolCategory;
  schema?: ZodObject<ZodRawShape>;
  toParams?: (args: Record<string, unknown>) => Record<string, unknown>;
}

const toolCategories = new Map<string, ToolCategory>();

export function getToolCategory(name: string): ToolCategory | undefined {
  return toolCategories.get(name);
}

export function setToolCategory(name: string, category: ToolCategory): void {
  toolCategories.set(name, category);
}

export function registerGodotSpec(
  client: GodotClient,
  spec: GodotToolSpec,
): void {
  toolCategories.set(spec.name, spec.category);
  registerTool(client, {
    name: spec.name,
    description: spec.description,
    schema:
      spec.schema ?? getTypedSchema(spec.name) ?? PASSTHROUGH_SCHEMA,
    handler: async (c, args) =>
      callGodot(
        c,
        spec.name,
        spec.toParams
          ? spec.toParams(args as Record<string, unknown>)
          : (args as Record<string, unknown>),
      ),
  });
}

export function registerGodotSpecs(
  client: GodotClient,
  specs: GodotToolSpec[],
): void {
  for (const spec of specs) {
    registerGodotSpec(client, spec);
  }
}

export function clearToolCategories(): void {
  toolCategories.clear();
}
