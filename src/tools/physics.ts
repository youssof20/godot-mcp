import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const nodePathSchema = z.string();

export const physicsToolSchemas = {
  setup_physics_body: z.object({
    parent_path: z.string().optional().default("."),
    body_type: z.string().optional().default("RigidBody2D"),
    node_name: z.string().optional(),
    properties: z.record(z.unknown()).optional(),
  }).strict(),
  setup_collision: z.object({
    node_path: nodePathSchema,
    shape_type: z.enum(["rectangle", "circle", "capsule"]).optional().default("rectangle"),
    size: z.object({ x: z.number(), y: z.number(), z: z.number().optional() }).optional(),
    radius: z.number().optional(),
    height: z.number().optional(),
    node_name: z.string().optional(),
  }).strict(),
  set_physics_layers: z.object({
    node_path: nodePathSchema,
    collision_layer: z.number().int().optional(),
    collision_mask: z.number().int().optional(),
  }).strict(),
  get_physics_layers: z.object({ node_path: nodePathSchema }).strict(),
  get_collision_info: z.object({ node_path: nodePathSchema }).strict(),
  add_raycast: z.object({
    parent_path: z.string().optional().default("."),
    dimension: z.enum(["2d", "3d"]).optional().default("2d"),
    node_name: z.string().optional(),
    target_position: z.object({ x: z.number(), y: z.number(), z: z.number().optional() }).optional(),
    collision_mask: z.number().int().optional(),
  }).strict(),
};

export function registerPhysicsTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  const tools: Array<{ name: keyof typeof physicsToolSchemas; description: string }> = [
    { name: "setup_physics_body", description: "Add a physics body (RigidBody2D/3D, CharacterBody, etc.)." },
    { name: "setup_collision", description: "Add a collision shape to a physics body." },
    { name: "set_physics_layers", description: "Set collision_layer and/or collision_mask." },
    { name: "get_physics_layers", description: "Read collision layers on a physics body." },
    { name: "get_collision_info", description: "List collision shapes on a physics body." },
    { name: "add_raycast", description: "Add RayCast2D or RayCast3D to the scene." },
  ];
  for (const { name, description } of tools) {
    registerGodotTool(server, client, enabled, name, description, physicsToolSchemas[name].shape);
  }
}
