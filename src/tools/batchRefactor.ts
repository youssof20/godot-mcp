import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const batchRefactorToolSchemas = {
  find_node_references: z.object({
    node_name: z.string().min(1),
    scene_path: z.string().optional().default("res://"),
    max_results: z.number().int().optional().default(100),
  }),
  find_script_references: z.object({
    script_path: z.string().min(1),
    max_results: z.number().int().optional().default(100),
  }),
  find_resource_references: z.object({
    resource_path: z.string().min(1),
    max_results: z.number().int().optional().default(100),
  }),
  get_scene_dependencies: z.object({
    scene_path: z.string().optional(),
  }),
  detect_circular_dependencies: z.object({
    path: z.string().optional().default("res://"),
    max_scenes: z.number().int().optional().default(200),
  }),
  find_nodes_by_type: z.object({
    type: z.string().min(1),
    scene_path: z.string().optional(),
    runtime: z.boolean().optional().default(false),
    max_results: z.number().int().optional().default(100),
  }),
  find_signal_connections: z.object({
    scene_path: z.string().optional(),
    node_path: z.string().optional(),
    signal: z.string().optional(),
    max_results: z.number().int().optional().default(200),
  }),
  batch_set_property: z.object({
    changes: z.array(
      z.object({
        node_path: z.string().min(1),
        property: z.string().min(1),
        value: z.unknown(),
      }),
    ),
  }),
  cross_scene_set_property: z.object({
    scene_path: z.string().min(1),
    node_path: z.string().min(1),
    property: z.string().min(1),
    value: z.unknown(),
    save: z.boolean().optional().default(true),
  }),
};

export function registerBatchRefactorTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  for (const [name, schema] of Object.entries(batchRefactorToolSchemas)) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      `Analysis/refactor tool: ${name}`,
      schema.shape,
    );
  }
}
