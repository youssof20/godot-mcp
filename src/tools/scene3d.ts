import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const scene3dToolSchemas = {
  add_mesh_instance: z.object({
    parent_path: z.string().optional().default("."),
    node_name: z.string().optional(),
    mesh_type: z.enum(["box", "sphere", "plane"]).optional().default("box"),
    size: z.object({ x: z.number(), y: z.number(), z: z.number() }).optional(),
    radius: z.number().optional(),
    width: z.number().optional(),
    depth: z.number().optional(),
    height: z.number().optional(),
  }).strict(),
  setup_camera_3d: z.object({
    parent_path: z.string().optional().default("."),
    node_name: z.string().optional(),
    fov: z.number().optional(),
    position: z.object({ x: z.number(), y: z.number(), z: z.number() }).optional(),
    rotation: z.object({ x: z.number(), y: z.number(), z: z.number() }).optional(),
    current: z.boolean().optional(),
  }).strict(),
  setup_lighting: z.object({
    parent_path: z.string().optional().default("."),
    light_type: z.enum(["directional", "omni", "spot"]).optional().default("directional"),
    node_name: z.string().optional(),
    energy: z.number().optional(),
    color: z.object({ r: z.number(), g: z.number(), b: z.number() }).optional(),
  }).strict(),
  setup_environment: z.object({
    parent_path: z.string().optional().default("."),
    node_name: z.string().optional(),
    background_mode: z.number().int().optional(),
    background_color: z.object({ r: z.number(), g: z.number(), b: z.number() }).optional(),
    ambient_light_color: z.object({ r: z.number(), g: z.number(), b: z.number() }).optional(),
  }).strict(),
  add_gridmap: z.object({
    parent_path: z.string().optional().default("."),
    node_name: z.string().optional(),
    mesh_library: z.string().optional(),
  }).strict(),
  set_material_3d: z.object({
    node_path: z.string(),
    surface: z.number().int().optional().default(0),
    material_path: z.string().optional(),
    color: z.object({ r: z.number(), g: z.number(), b: z.number(), a: z.number().optional() }).optional(),
  }).strict(),
};

export function registerScene3dTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  const tools: Array<{ name: keyof typeof scene3dToolSchemas; description: string }> = [
    { name: "add_mesh_instance", description: "Add MeshInstance3D with a primitive mesh." },
    { name: "setup_camera_3d", description: "Add and configure Camera3D." },
    { name: "setup_lighting", description: "Add DirectionalLight3D, OmniLight3D, or SpotLight3D." },
    { name: "setup_environment", description: "Add WorldEnvironment with Environment resource." },
    { name: "add_gridmap", description: "Add GridMap node with optional MeshLibrary." },
    { name: "set_material_3d", description: "Set surface override material on MeshInstance3D." },
  ];
  for (const { name, description } of tools) {
    registerGodotTool(server, client, enabled, name, description, scene3dToolSchemas[name].shape);
  }
}
