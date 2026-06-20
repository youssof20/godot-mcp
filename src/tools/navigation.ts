import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const vec3 = z.object({ x: z.number(), y: z.number(), z: z.number().optional().default(0) });

export const navigationToolSchemas = {
  setup_navigation_region: z.object({
    parent_path: z.string().optional().default("."),
    dimension: z.enum(["2d", "3d"]).optional().default("3d"),
    node_name: z.string().optional(),
    navigation_layers: z.number().int().optional(),
  }).strict(),
  setup_navigation_agent: z.object({
    parent_path: z.string().optional().default("."),
    dimension: z.enum(["2d", "3d"]).optional().default("3d"),
    node_name: z.string().optional(),
    target_desired_distance: z.number().optional(),
    path_desired_distance: z.number().optional(),
  }).strict(),
  bake_navigation_mesh: z.object({ node_path: z.string() }).strict(),
  set_navigation_layers: z.object({
    node_path: z.string(),
    navigation_layers: z.number().int(),
  }).strict(),
  get_navigation_info: z.object({ node_path: z.string() }).strict(),
  get_navigation_path_preview: z.object({
    dimension: z.enum(["2d", "3d"]).optional().default("3d"),
    from: vec3.optional(),
    to: vec3.optional(),
  }).strict(),
};

export function registerNavigationTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  const tools: Array<{ name: keyof typeof navigationToolSchemas; description: string }> = [
    { name: "setup_navigation_region", description: "Add NavigationRegion2D or NavigationRegion3D." },
    { name: "setup_navigation_agent", description: "Add NavigationAgent2D or NavigationAgent3D." },
    { name: "bake_navigation_mesh", description: "Bake navigation mesh for a region." },
    { name: "set_navigation_layers", description: "Set navigation_layers on a region." },
    { name: "get_navigation_info", description: "Read navigation region metadata." },
    { name: "get_navigation_path_preview", description: "Query path between two points via NavigationServer." },
  ];
  for (const { name, description } of tools) {
    registerGodotTool(server, client, enabled, name, description, navigationToolSchemas[name].shape);
  }
}
