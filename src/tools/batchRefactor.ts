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
      `Analysis tool: ${name}`,
      schema.shape,
    );
  }
}
