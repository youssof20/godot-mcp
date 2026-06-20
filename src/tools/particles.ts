import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const particlesToolSchemas = {
  create_particles: z.object({
    parent_path: z.string().optional().default("."),
    dimension: z.enum(["2d", "3d"]).optional().default("2d"),
    node_name: z.string().optional(),
    amount: z.number().int().optional(),
    lifetime: z.number().optional(),
    emitting: z.boolean().optional(),
  }).strict(),
  set_particle_material: z.object({
    node_path: z.string(),
    direction: z.object({ x: z.number(), y: z.number(), z: z.number().optional() }).optional(),
    spread: z.number().optional(),
    initial_velocity_min: z.number().optional(),
    initial_velocity_max: z.number().optional(),
    gravity: z.object({ x: z.number(), y: z.number(), z: z.number().optional() }).optional(),
  }).strict(),
  set_particle_color_gradient: z.object({
    node_path: z.string(),
    colors: z.array(z.object({ r: z.number(), g: z.number(), b: z.number(), a: z.number().optional() })),
  }).strict(),
  apply_particle_preset: z.object({
    parent_path: z.string().optional().default("."),
    node_path: z.string().optional(),
    preset: z.enum(["spark", "smoke", "fire"]).optional().default("spark"),
    dimension: z.enum(["2d", "3d"]).optional().default("2d"),
  }).strict(),
  get_particle_info: z.object({ node_path: z.string() }).strict(),
};

export function registerParticlesTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  const tools: Array<{ name: keyof typeof particlesToolSchemas; description: string }> = [
    { name: "create_particles", description: "Add GPUParticles2D or GPUParticles3D." },
    { name: "set_particle_material", description: "Configure ParticleProcessMaterial on a particle node." },
    { name: "set_particle_color_gradient", description: "Set particle color ramp gradient." },
    { name: "apply_particle_preset", description: "Create particles with spark/smoke/fire preset." },
    { name: "get_particle_info", description: "Read particle node settings." },
  ];
  for (const { name, description } of tools) {
    registerGodotTool(server, client, enabled, name, description, particlesToolSchemas[name].shape);
  }
}
