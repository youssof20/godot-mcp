import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { GodotClient } from "../godotClient.js";
import { registerGodotTool } from "./helpers.js";

const nodePathSchema = z.string().describe("TileMapLayer path, or TileMap with layer child");
const coordsSchema = z.object({ x: z.number().int(), y: z.number().int() });

export const tilemapToolSchemas = {
  tilemap_set_cell: z
    .object({
      node_path: nodePathSchema,
      coords: coordsSchema,
      source_id: z.number().int().optional().default(-1),
      atlas_coords: coordsSchema.optional().default({ x: -1, y: -1 }),
      alternative_tile: z.number().int().optional().default(0),
      layer_index: z.number().int().min(0).optional(),
    })
    .strict(),
  tilemap_fill_rect: z
    .object({
      node_path: nodePathSchema,
      from: coordsSchema,
      to: coordsSchema,
      source_id: z.number().int().optional().default(-1),
      atlas_coords: coordsSchema.optional().default({ x: -1, y: -1 }),
      alternative_tile: z.number().int().optional().default(0),
      layer_index: z.number().int().min(0).optional(),
    })
    .strict(),
  tilemap_get_cell: z
    .object({
      node_path: nodePathSchema,
      coords: coordsSchema,
      layer_index: z.number().int().min(0).optional(),
    })
    .strict(),
  tilemap_clear: z
    .object({
      node_path: nodePathSchema,
      from: coordsSchema.optional(),
      to: coordsSchema.optional(),
      layer_index: z.number().int().min(0).optional(),
    })
    .strict(),
  tilemap_get_info: z
    .object({
      node_path: nodePathSchema,
      layer_index: z.number().int().min(0).optional(),
    })
    .strict(),
  tilemap_get_used_cells: z
    .object({
      node_path: nodePathSchema,
      limit: z.number().int().min(1).max(5000).optional().default(500),
      layer_index: z.number().int().min(0).optional(),
    })
    .strict(),
};

export function registerTilemapTools(
  server: McpServer,
  client: GodotClient,
  enabled: Set<string>,
): void {
  const tools: Array<{ name: keyof typeof tilemapToolSchemas; description: string }> = [
    { name: "tilemap_set_cell", description: "Set a tile cell on a TileMapLayer." },
    { name: "tilemap_fill_rect", description: "Fill a rectangle of cells on a TileMapLayer." },
    { name: "tilemap_get_cell", description: "Read a tile cell from a TileMapLayer." },
    { name: "tilemap_clear", description: "Clear cells in a region or entire layer." },
    { name: "tilemap_get_info", description: "Get TileMapLayer and TileSet metadata." },
    { name: "tilemap_get_used_cells", description: "List used cells on a TileMapLayer." },
  ];

  for (const { name, description } of tools) {
    registerGodotTool(
      server,
      client,
      enabled,
      name,
      description,
      tilemapToolSchemas[name].shape,
    );
  }
}
