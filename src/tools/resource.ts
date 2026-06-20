import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const resourceToolSchemas = {
  read_resource: z.object({
    resource_path: z.string().min(1),
    as_text: z.boolean().optional().default(false),
  }),
  edit_resource: z.object({
    resource_path: z.string().min(1),
    properties: z.record(z.unknown()),
  }),
  create_resource: z.object({
    resource_path: z.string().min(1),
    class: z.string().default("Resource"),
    properties: z.record(z.unknown()).optional(),
  }),
  get_resource_preview: z.object({
    resource_path: z.string().min(1),
  }),
  add_autoload: z.object({
    name: z.string().min(1),
    path: z.string().min(1),
  }),
  remove_autoload: z.object({
    name: z.string().min(1),
  }),
};

export function registerResourceTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  for (const [name, schema] of Object.entries(resourceToolSchemas)) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      `Resource tool: ${name}`,
      schema.shape,
    );
  }
}
