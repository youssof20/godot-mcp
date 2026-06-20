import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const nodePathSchema = z.string().describe("Scene-relative path to AnimationTree node");
const positionSchema = z.object({ x: z.number(), y: z.number() }).optional();

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
  set_tree_parameter: z
    .object({
      node_path: nodePathSchema,
      parameter: z.string().min(1),
      value: z.unknown(),
    })
    .strict(),
  add_state_machine_state: z
    .object({
      node_path: nodePathSchema,
      state_name: z.string().min(1),
      node_type: z.string().optional().default("AnimationNodeAnimation"),
      animation: z.string().optional(),
      position: positionSchema,
    })
    .strict(),
  remove_state_machine_state: z
    .object({
      node_path: nodePathSchema,
      state_name: z.string().min(1),
    })
    .strict(),
  add_state_machine_transition: z
    .object({
      node_path: nodePathSchema,
      from_state: z.string().min(1),
      to_state: z.string().min(1),
      xfade_time: z.number().optional().default(0.2),
      advance_condition: z.string().optional(),
      switch_mode: z.number().int().optional(),
    })
    .strict(),
  remove_state_machine_transition: z
    .object({
      node_path: nodePathSchema,
      from_state: z.string().min(1),
      to_state: z.string().min(1),
    })
    .strict(),
  set_blend_tree_node: z
    .object({
      node_path: nodePathSchema,
      action: z.enum(["add", "remove", "connect", "set_parameter"]).optional().default("add"),
      node_name: z.string().optional(),
      node_type: z.string().optional().default("AnimationNodeAnimation"),
      animation: z.string().optional(),
      position: positionSchema,
      from_node: z.string().optional().describe("Alias for output_node"),
      to_node: z.string().optional().describe("Alias for input_node"),
      input_node: z.string().optional(),
      output_node: z.string().optional(),
      input_index: z.number().int().optional().default(0),
      from_port: z.number().int().optional(),
      to_port: z.number().int().optional(),
      parameter: z.string().optional(),
      value: z.unknown().optional(),
    })
    .strict(),
};

const descriptions: Record<keyof typeof animationTreeToolSchemas, string> = {
  create_animation_tree: "Create an AnimationTree node with optional state machine root.",
  get_animation_tree_structure: "Inspect AnimationTree root, states, transitions, and parameters.",
  set_tree_parameter: "Set an AnimationTree parameter (e.g. parameters/conditions/name).",
  add_state_machine_state: "Add a state to an AnimationNodeStateMachine root.",
  remove_state_machine_state: "Remove a state from an AnimationNodeStateMachine root.",
  add_state_machine_transition: "Add a transition between two states in a state machine.",
  remove_state_machine_transition: "Remove a transition between two states.",
  set_blend_tree_node: "Add, remove, connect, or set parameters on an AnimationNodeBlendTree root.",
};

export function registerAnimationTreeTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  for (const [name, schema] of Object.entries(animationTreeToolSchemas)) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      descriptions[name as keyof typeof animationTreeToolSchemas],
      schema.shape,
    );
  }
}
