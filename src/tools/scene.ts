import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const resPathSchema = z.string().describe("res:// path");

export const sceneToolSchemas = {
  get_scene_tree: z.object({
    scene_path: resPathSchema.optional().describe("If omitted, uses the edited scene"),
    max_depth: z.number().int().min(1).max(64).optional().default(12),
  }),
  get_scene_file_content: z.object({
    scene_path: resPathSchema,
  }),
  create_scene: z.object({
    scene_path: resPathSchema.describe("New .tscn path, e.g. res://scenes/main.tscn"),
    root_type: z.string().optional().default("Node2D"),
    root_name: z.string().optional().default("Root"),
    open: z.boolean().optional().default(true),
  }),
  open_scene: z.object({
    scene_path: resPathSchema,
  }),
  save_scene: z.object({
    scene_path: resPathSchema.optional().describe("Omit to save the current scene to its existing path"),
  }),
  delete_scene: z.object({
    scene_path: resPathSchema,
  }),
};

export function registerSceneTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  registerGodotTool(
    server,
    client,
    enabled,
    "get_scene_tree",
    "Get the node hierarchy of the edited scene or a scene file.",
    sceneToolSchemas.get_scene_tree.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_scene_file_content",
    "Read raw .tscn/.scn text from the project.",
    sceneToolSchemas.get_scene_file_content.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "create_scene",
    "Create a new .tscn file and optionally open it in the editor (undoable).",
    sceneToolSchemas.create_scene.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "open_scene",
    "Open a scene in the Godot editor.",
    sceneToolSchemas.open_scene.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "save_scene",
    "Save the edited scene (or save as a new path).",
    sceneToolSchemas.save_scene.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "delete_scene",
    "Delete a scene file from the project (undoable). Scene must not be open.",
    sceneToolSchemas.delete_scene.shape,
  );
}
