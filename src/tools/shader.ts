import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const shaderToolSchemas = {
  create_shader: z.object({
    shader_path: z.string(),
    content: z.string().optional(),
  }).strict(),
  read_shader: z.object({ shader_path: z.string() }).strict(),
  edit_shader: z.object({ shader_path: z.string(), content: z.string() }).strict(),
  assign_shader_material: z.object({
    node_path: z.string(),
    shader_path: z.string(),
    surface: z.number().int().optional().default(0),
  }).strict(),
  set_shader_param: z.object({
    node_path: z.string(),
    param: z.string(),
    value: z.unknown(),
    surface: z.number().int().optional().default(0),
  }).strict(),
  get_shader_params: z.object({
    node_path: z.string(),
    surface: z.number().int().optional().default(0),
  }).strict(),
};

export function registerShaderTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  for (const name of Object.keys(shaderToolSchemas) as Array<keyof typeof shaderToolSchemas>) {
    registerGodotTool(server, client, enabled, name, `Shader tool: ${name}`, shaderToolSchemas[name].shape);
  }
}
