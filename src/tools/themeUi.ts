import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const colorSchema = z.object({ r: z.number(), g: z.number(), b: z.number(), a: z.number().optional() });

export const themeUiToolSchemas = {
  create_theme: z.object({
    theme_path: z.string().optional().default("res://themes/mcp_theme.tres"),
    control_path: z.string().optional(),
  }).strict(),
  set_theme_color: z.object({
    theme_path: z.string(),
    data_type: z.string().optional().default("Button"),
    name: z.string().optional().default("font_color"),
    color: colorSchema,
  }).strict(),
  set_theme_constant: z.object({
    theme_path: z.string(),
    data_type: z.string().optional().default("Button"),
    name: z.string().optional().default("h_separation"),
    value: z.number().int(),
  }).strict(),
  set_theme_font_size: z.object({
    theme_path: z.string(),
    data_type: z.string().optional().default("Label"),
    name: z.string().optional().default("font_size"),
    value: z.number().int(),
  }).strict(),
  set_theme_stylebox: z.object({
    theme_path: z.string(),
    data_type: z.string().optional().default("Button"),
    name: z.string().optional().default("normal"),
    bg_color: colorSchema.optional(),
    corner_radius: z.number().int().optional(),
  }).strict(),
  get_theme_info: z.object({ theme_path: z.string() }).strict(),
};

export function registerThemeUiTools(server: McpServer, client: GodotClient, enabled: Set<string>): void {
  for (const name of Object.keys(themeUiToolSchemas) as Array<keyof typeof themeUiToolSchemas>) {
    registerGodotTool(server, client, enabled, name, `Theme tool: ${name}`, themeUiToolSchemas[name].shape);
  }
}
