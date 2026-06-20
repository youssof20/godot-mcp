import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const inputToolSchemas = {
  simulate_key: z.object({
    key: z.string().optional(),
    keycode: z.number().int().optional(),
    pressed: z.boolean().optional().default(true),
    shift: z.boolean().optional(),
    ctrl: z.boolean().optional(),
    alt: z.boolean().optional(),
  }),
  simulate_mouse_click: z.object({
    x: z.number(),
    y: z.number(),
    button: z.number().int().optional().default(1),
    pressed: z.boolean().optional().default(true),
  }),
  simulate_mouse_move: z.object({
    x: z.number(),
    y: z.number(),
  }),
  simulate_action: z.object({
    action: z.string().min(1),
    pressed: z.boolean().optional().default(true),
  }),
  simulate_sequence: z.object({
    steps: z.array(z.record(z.unknown())),
  }),
  get_input_actions: z.object({}).strict(),
  set_input_action: z.object({
    action: z.string().min(1),
    create: z.boolean().optional().default(true),
    deadzone: z.number().optional(),
    replace_events: z.boolean().optional(),
    events: z.array(z.record(z.unknown())).optional(),
  }),
};

export function registerInputTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  for (const [name, schema] of Object.entries(inputToolSchemas)) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      `Input tool: ${name}`,
      schema.shape,
    );
  }
}
