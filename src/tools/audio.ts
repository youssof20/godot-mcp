import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const audioToolSchemas = {
  add_audio_player: z.object({
    parent_path: z.string().optional().default("."),
    dimension: z.enum(["2d", "3d"]).optional().default("2d"),
    ui: z.boolean().optional().default(false),
    node_name: z.string().optional(),
    stream_path: z.string().optional(),
    volume_db: z.number().optional(),
    autoplay: z.boolean().optional(),
  }).strict(),
  add_audio_bus: z.object({
    bus_name: z.string(),
    at_position: z.number().int().optional(),
  }).strict(),
  add_audio_bus_effect: z.object({
    bus_name: z.string().optional().default("Master"),
    effect_type: z.enum(["reverb", "eq", "compressor", "delay"]).optional().default("reverb"),
  }).strict(),
  set_audio_bus: z.object({
    bus_name: z.string().optional().default("Master"),
    volume_db: z.number().optional(),
    mute: z.boolean().optional(),
    solo: z.boolean().optional(),
  }).strict(),
  get_audio_bus_layout: z.object({}).strict(),
  get_audio_info: z.object({
    node_path: z.string().optional(),
    bus_name: z.string().optional(),
  }).strict(),
};

export function registerAudioTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  const tools: Array<{ name: keyof typeof audioToolSchemas; description: string }> = [
    { name: "add_audio_player", description: "Add AudioStreamPlayer2D/3D or AudioStreamPlayer." },
    { name: "add_audio_bus", description: "Add a new audio bus." },
    { name: "add_audio_bus_effect", description: "Add an effect to an audio bus." },
    { name: "set_audio_bus", description: "Set bus volume, mute, or solo." },
    { name: "get_audio_bus_layout", description: "List all audio buses and effects." },
    { name: "get_audio_info", description: "Read audio player or bus info." },
  ];
  for (const { name, description } of tools) {
    registerGodotTool(server, client, enabled, name, description, audioToolSchemas[name].shape);
  }
}
