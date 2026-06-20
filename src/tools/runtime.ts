import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const runtimeToolSchemas = {
  play_scene: z.object({
    scene_path: z.string().optional().describe("Omit to play current edited scene"),
  }),
  stop_scene: z.object({}).strict(),
  get_runtime_status: z.object({}).strict(),
  get_game_scene_tree: z.object({
    max_depth: z.number().int().optional().default(12),
  }),
  get_game_node_properties: z.object({
    node_path: z.string().optional(),
    properties: z.array(z.string()).optional(),
  }),
  set_game_node_property: z.object({
    node_path: z.string().min(1),
    property: z.string().min(1),
    value: z.unknown(),
  }),
  execute_game_script: z.object({
    source: z.string().min(1),
    node_path: z.string().optional().default("."),
    mode: z.enum(["expression", "block"]).optional().default("expression"),
  }),
  batch_get_properties: z.object({
    requests: z.array(
      z.object({
        node_path: z.string(),
        properties: z.array(z.string()),
      }),
    ),
  }),
  find_nodes_by_script: z.object({
    script_path: z.string().min(1),
    runtime: z.boolean().optional().default(true),
  }),
  get_autoload: z.object({}).strict(),
  find_ui_elements: z.object({
    type: z.string().optional().default("Control"),
    max_results: z.number().int().optional().default(100),
  }),
  click_button_by_text: z.object({
    text: z.string().min(1),
  }),
  wait_for_node: z.object({
    node_path: z.string().min(1),
    timeout_ms: z.number().int().optional().default(5000),
    poll_interval_ms: z.number().int().optional().default(100),
  }),
  find_nearby_nodes: z.object({
    node_path: z.string().min(1),
    radius: z.number().optional().default(100),
  }),
  navigate_to: z.object({
    node_path: z.string().min(1),
    position: z.object({ x: z.number(), y: z.number() }),
  }),
  move_to: z.object({
    node_path: z.string().min(1),
    position: z.object({ x: z.number(), y: z.number() }),
  }),
};

export function registerRuntimeTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  for (const [name, schema] of Object.entries(runtimeToolSchemas)) {
    const desc =
      name === "execute_game_script"
        ? "DANGEROUS: Execute GDScript in running game (requires ALLOW_GODOT_MCP_DANGEROUS=1)."
        : `Runtime tool: ${name}`;
    registerGodotTool(server, client, enabled, name, desc, schema.shape);
  }
}
