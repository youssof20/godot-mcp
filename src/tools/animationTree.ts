import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const nodePathSchema = z.string().describe("Scene-relative node path");

export const animationTreeToolSchemas = {
  create_animation_tree: z
    .object({
      parent_path: z.string().optional().default("."),
      node_name: z.string().optional().default("AnimationTree"),
      anim_player_path: z.string().optional(),
      use_state_machine: z.boolean().optional().default(true),
    })
    .strict(),
  get_animation_tree_structure: z.object({ node_path: nodePathSchema }).strict(),
};

export function registerAnimationTreeTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  registerGodotTool(
    server,
    client,
    enabled,
    "create_animation_tree",
    "Create an AnimationTree node with optional state machine root.",
    animationTreeToolSchemas.create_animation_tree.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_animation_tree_structure",
    "Inspect AnimationTree root, states, transitions, and parameters.",
    animationTreeToolSchemas.get_animation_tree_structure.shape,
  );
}
