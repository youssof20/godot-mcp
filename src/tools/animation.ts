import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const nodePathSchema = z.string().describe("Scene-relative node path");

export const animationToolSchemas = {
  list_animations: z.object({ node_path: nodePathSchema }).strict(),
  create_animation: z
    .object({
      node_path: nodePathSchema,
      animation_name: z.string(),
      library: z.string().optional().default(""),
      length: z.number().min(0.01).optional().default(1),
    })
    .strict(),
  add_animation_track: z
    .object({
      node_path: nodePathSchema,
      animation_name: z.string(),
      track_type: z
        .enum([
          "value",
          "position_3d",
          "rotation_3d",
          "scale_3d",
          "method",
          "bezier",
          "audio",
          "animation",
        ])
        .optional()
        .default("value"),
      path: z.string().describe("NodePath for the track, e.g. Sprite2D:position:x"),
    })
    .strict(),
  set_animation_keyframe: z
    .object({
      node_path: nodePathSchema,
      animation_name: z.string(),
      track_index: z.number().int().min(0),
      time: z.number().min(0),
      value: z.unknown(),
      transition: z.number().optional().default(1),
      length: z.number().min(0.01).optional(),
    })
    .strict(),
  get_animation_info: z
    .object({
      node_path: nodePathSchema,
      animation_name: z.string().optional(),
    })
    .strict(),
  remove_animation: z
    .object({
      node_path: nodePathSchema,
      animation_name: z.string(),
      library: z.string().optional().default(""),
    })
    .strict(),
};

export function registerAnimationTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  const tools: Array<{ name: keyof typeof animationToolSchemas; description: string }> = [
    { name: "list_animations", description: "List animations on an AnimationPlayer." },
    { name: "create_animation", description: "Create a new animation on an AnimationPlayer." },
    { name: "add_animation_track", description: "Add a track to an animation." },
    { name: "set_animation_keyframe", description: "Insert a keyframe on an animation track." },
    { name: "get_animation_info", description: "Get animation libraries, tracks, and metadata." },
    { name: "remove_animation", description: "Remove an animation from an AnimationPlayer." },
  ];

  for (const { name, description } of tools) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      description,
      animationToolSchemas[name].shape,
    );
  }
}
