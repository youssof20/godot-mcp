import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const resPathSchema = z
  .string()
  .describe("Project path such as res://addons or res://scenes/main.tscn");

export const projectToolSchemas = {
  get_project_info: z.object({}).strict(),
  get_filesystem_tree: z.object({
    path: resPathSchema.optional().default("res://"),
    max_depth: z.number().int().min(1).max(32).optional().default(10),
    include_files: z.boolean().optional().default(true),
  }),
  search_files: z.object({
    query: z.string().min(1).describe("Filename substring or glob (e.g. *.gd)"),
    path: resPathSchema.optional().default("res://"),
    extensions: z.array(z.string()).optional(),
    max_results: z.number().int().min(1).max(2000).optional().default(200),
  }),
  get_project_settings: z.object({
    keys: z.array(z.string()).optional(),
    prefix: z.string().optional(),
  }),
  uid_to_project_path: z.object({
    uid: z.string().min(1).describe("UID string, with or without uid:// prefix"),
  }),
  project_path_to_uid: z.object({
    path: resPathSchema,
  }),
};

export function registerProjectTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  registerGodotTool(
    server,
    client,
    enabled,
    "get_project_info",
    "Get Godot project name, paths, version, and main scene.",
    projectToolSchemas.get_project_info.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_filesystem_tree",
    "Get a directory tree under a res:// path.",
    projectToolSchemas.get_filesystem_tree.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "search_files",
    "Search project files by name/glob under a res:// path.",
    projectToolSchemas.search_files.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_project_settings",
    "Read project settings by keys or prefix from project.godot.",
    projectToolSchemas.get_project_settings.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "uid_to_project_path",
    "Convert a resource UID to a res:// project path.",
    projectToolSchemas.uid_to_project_path.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "project_path_to_uid",
    "Convert a res:// project path to its resource UID.",
    projectToolSchemas.project_path_to_uid.shape,
  );
}
