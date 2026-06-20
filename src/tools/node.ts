import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

export const nodeToolSchemas = {
  get_node_properties: z.object({
    node_path: z.string().min(1),
    scene_path: z.string().optional(),
    properties: z.array(z.string()).optional(),
    include_groups: z.boolean().optional().default(true),
    include_signals: z.boolean().optional().default(false),
  }),
  add_node: z.object({
    node_type: z.string().default("Node2D"),
    node_name: z.string().optional(),
    parent_path: z.string().optional().default("."),
  }),
  delete_node: z.object({
    node_path: z.string().min(1),
  }),
  duplicate_node: z.object({
    node_path: z.string().min(1),
  }),
  move_node: z.object({
    node_path: z.string().min(1),
    new_parent_path: z.string().min(1),
    index: z.number().int().optional().default(-1),
  }),
  rename_node: z.object({
    node_path: z.string().min(1),
    new_name: z.string().min(1),
  }),
  update_property: z.object({
    node_path: z.string().min(1),
    property: z.string().min(1),
    value: z.unknown(),
  }),
  add_resource: z.object({
    node_path: z.string().min(1),
    property: z.string().min(1),
    resource_path: z.string().min(1),
  }),
  set_anchor_preset: z.object({
    node_path: z.string().min(1),
    preset: z.union([z.string(), z.number()]),
  }),
  connect_signal: z.object({
    source_path: z.string().min(1),
    signal: z.string().min(1),
    target_path: z.string().min(1),
    method: z.string().optional(),
    flags: z.number().int().optional(),
  }),
  disconnect_signal: z.object({
    source_path: z.string().min(1),
    signal: z.string().min(1),
    target_path: z.string().min(1),
    method: z.string().optional(),
  }),
  get_signals: z.object({
    node_path: z.string().min(1),
  }),
  get_node_groups: z.object({
    node_path: z.string().min(1),
  }),
  set_node_groups: z.object({
    node_path: z.string().min(1),
    groups: z.array(z.string()),
    mode: z.enum(["replace", "add", "remove"]).optional().default("replace"),
  }),
  find_nodes_in_group: z.object({
    group: z.string().min(1),
  }),
};

export function registerNodeTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  registerGodotTool(
    server,
    client,
    enabled,
    "get_node_properties",
    "Read properties from a node in the edited scene or a scene file.",
    nodeToolSchemas.get_node_properties.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "add_node",
    "Add a child node to the edited scene (undoable).",
    nodeToolSchemas.add_node.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "delete_node",
    "Remove a node from the edited scene (undoable).",
    nodeToolSchemas.delete_node.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "duplicate_node",
    "Duplicate a node in the edited scene (undoable).",
    nodeToolSchemas.duplicate_node.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "move_node",
    "Reparent a node in the edited scene (undoable).",
    nodeToolSchemas.move_node.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "rename_node",
    "Rename a node in the edited scene (undoable).",
    nodeToolSchemas.rename_node.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "update_property",
    "Set a node property in the edited scene (undoable).",
    nodeToolSchemas.update_property.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "add_resource",
    "Assign a loaded resource to a node property (undoable).",
    nodeToolSchemas.add_resource.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "set_anchor_preset",
    "Apply a Control anchor preset (undoable).",
    nodeToolSchemas.set_anchor_preset.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "connect_signal",
    "Connect a signal between nodes (undoable).",
    nodeToolSchemas.connect_signal.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "disconnect_signal",
    "Disconnect a signal between nodes (undoable).",
    nodeToolSchemas.disconnect_signal.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_signals",
    "List signals and connections on a node.",
    nodeToolSchemas.get_signals.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "get_node_groups",
    "Get groups for a node.",
    nodeToolSchemas.get_node_groups.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "set_node_groups",
    "Set node groups replace/add/remove (undoable).",
    nodeToolSchemas.set_node_groups.shape,
  );

  registerGodotTool(
    server,
    client,
    enabled,
    "find_nodes_in_group",
    "Find nodes in a group in the edited scene.",
    nodeToolSchemas.find_nodes_in_group.shape,
  );
}
