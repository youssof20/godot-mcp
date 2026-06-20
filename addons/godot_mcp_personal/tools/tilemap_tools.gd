## Phase 7 TileMapLayer tools (Godot 4.3+ layered TileMap).
class_name MCPTilemapTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func tilemap_set_cell(params: Dictionary) -> Dictionary:
	var layer := _resolve_tilemap_layer(params)
	if layer == null:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"TileMapLayer not found.",
			"Pass node_path to a TileMapLayer or TileMap with a layer child.",
		)

	var coords := _coords_from_param(params.get("coords"))
	if coords == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'coords' {x,y} required.")

	var source_id := int(params.get("source_id", -1))
	var atlas_coords := _coords_from_param(params.get("atlas_coords", {"x": -1, "y": -1}))
	var alternative_tile := int(params.get("alternative_tile", 0))

	var prev_source := layer.get_cell_source_id(coords)
	var prev_atlas := layer.get_cell_atlas_coords(coords)
	var prev_alt := layer.get_cell_alternative_tile(coords)

	var ur := _ctx.undo_redo()
	ur.create_action("MCP TileMap Set Cell")
	ur.add_do_method(layer, "set_cell", coords, source_id, atlas_coords, alternative_tile)
	ur.add_undo_method(layer, "set_cell", coords, prev_source, prev_atlas, prev_alt)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(layer),
		"coords": {"x": coords.x, "y": coords.y},
		"source_id": source_id,
		"atlas_coords": {"x": atlas_coords.x, "y": atlas_coords.y},
		"alternative_tile": alternative_tile,
	}


func tilemap_fill_rect(params: Dictionary) -> Dictionary:
	var layer := _resolve_tilemap_layer(params)
	if layer == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "TileMapLayer not found.")

	var from_coords := _coords_from_param(params.get("from"))
	var to_coords := _coords_from_param(params.get("to"))
	if from_coords == null or to_coords == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'from' and 'to' {x,y} required.")

	var source_id := int(params.get("source_id", -1))
	var atlas_coords := _coords_from_param(params.get("atlas_coords", {"x": -1, "y": -1}))
	var alternative_tile := int(params.get("alternative_tile", 0))

	var x0 := mini(from_coords.x, to_coords.x)
	var x1 := maxi(from_coords.x, to_coords.x)
	var y0 := mini(from_coords.y, to_coords.y)
	var y1 := maxi(from_coords.y, to_coords.y)

	var changed := 0
	var ur := _ctx.undo_redo()
	ur.create_action("MCP TileMap Fill Rect")
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			var prev_source := layer.get_cell_source_id(c)
			var prev_atlas := layer.get_cell_atlas_coords(c)
			var prev_alt := layer.get_cell_alternative_tile(c)
			ur.add_do_method(layer, "set_cell", c, source_id, atlas_coords, alternative_tile)
			ur.add_undo_method(layer, "set_cell", c, prev_source, prev_atlas, prev_alt)
			changed += 1
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(layer),
		"cells_changed": changed,
		"from": {"x": from_coords.x, "y": from_coords.y},
		"to": {"x": to_coords.x, "y": to_coords.y},
	}


func tilemap_get_cell(params: Dictionary) -> Dictionary:
	var layer := _resolve_tilemap_layer(params)
	if layer == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "TileMapLayer not found.")

	var coords := _coords_from_param(params.get("coords"))
	if coords == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'coords' {x,y} required.")

	var source_id := layer.get_cell_source_id(coords)
	return {
		"node_path": _ctx.node_path_relative(layer),
		"coords": {"x": coords.x, "y": coords.y},
		"source_id": source_id,
		"atlas_coords": _coords_dict(layer.get_cell_atlas_coords(coords)),
		"alternative_tile": layer.get_cell_alternative_tile(coords),
		"empty": source_id == -1,
	}


func tilemap_clear(params: Dictionary) -> Dictionary:
	var layer := _resolve_tilemap_layer(params)
	if layer == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "TileMapLayer not found.")

	var from_coords := _coords_from_param(params.get("from"))
	var to_coords := _coords_from_param(params.get("to"))
	var cleared := 0
	var ur := _ctx.undo_redo()
	ur.create_action("MCP TileMap Clear")

	if from_coords != null and to_coords != null:
		var x0 := mini(from_coords.x, to_coords.x)
		var x1 := maxi(from_coords.x, to_coords.x)
		var y0 := mini(from_coords.y, to_coords.y)
		var y1 := maxi(from_coords.y, to_coords.y)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := Vector2i(x, y)
				var prev_source := layer.get_cell_source_id(c)
				var prev_atlas := layer.get_cell_atlas_coords(c)
				var prev_alt := layer.get_cell_alternative_tile(c)
				ur.add_do_method(layer, "erase_cell", c)
				ur.add_undo_method(layer, "set_cell", c, prev_source, prev_atlas, prev_alt)
				cleared += 1
	else:
		for c in layer.get_used_cells():
			var prev_source := layer.get_cell_source_id(c)
			var prev_atlas := layer.get_cell_atlas_coords(c)
			var prev_alt := layer.get_cell_alternative_tile(c)
			ur.add_do_method(layer, "erase_cell", c)
			ur.add_undo_method(layer, "set_cell", c, prev_source, prev_atlas, prev_alt)
			cleared += 1
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(layer), "cleared": cleared}


func tilemap_get_info(params: Dictionary) -> Dictionary:
	var layer := _resolve_tilemap_layer(params)
	if layer == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "TileMapLayer not found.")

	var tile_set: TileSet = layer.tile_set
	var info := {
		"node_path": _ctx.node_path_relative(layer),
		"name": layer.name,
		"enabled": layer.enabled,
		"used_cell_count": layer.get_used_cells().size(),
		"tile_set_path": tile_set.resource_path if tile_set else "",
		"tile_set_class": tile_set.get_class() if tile_set else "",
	}

	if tile_set != null:
		info["source_count"] = tile_set.get_source_count()
		var sources: Array[Dictionary] = []
		for i in range(tile_set.get_source_count()):
			var source_id := tile_set.get_source_id(i)
			var source := tile_set.get_source(source_id)
			sources.append({
				"source_id": source_id,
				"type": source.get_class() if source else "",
			})
		info["sources"] = sources

	return info


func tilemap_get_used_cells(params: Dictionary) -> Dictionary:
	var layer := _resolve_tilemap_layer(params)
	if layer == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "TileMapLayer not found.")

	var limit := clampi(int(params.get("limit", 500)), 1, 5000)
	var cells: Array[Dictionary] = []
	for c in layer.get_used_cells():
		if cells.size() >= limit:
			break
		cells.append({
			"coords": _coords_dict(c),
			"source_id": layer.get_cell_source_id(c),
			"atlas_coords": _coords_dict(layer.get_cell_atlas_coords(c)),
			"alternative_tile": layer.get_cell_alternative_tile(c),
		})

	return {
		"node_path": _ctx.node_path_relative(layer),
		"cells": cells,
		"count": cells.size(),
		"truncated": layer.get_used_cells().size() > limit,
	}


func _resolve_tilemap_layer(params: Dictionary) -> TileMapLayer:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return null
	var node := _ctx.resolve_node(node_path)
	if node is TileMapLayer:
		return node as TileMapLayer
	if node is TileMap:
		var layer_index := int(params.get("layer_index", 0))
		var layer_node := (node as TileMap).get_child(layer_index) if node.get_child_count() > layer_index else null
		if layer_node is TileMapLayer:
			return layer_node as TileMapLayer
		for child in node.get_children():
			if child is TileMapLayer:
				return child as TileMapLayer
	return null


func _coords_from_param(value: Variant) -> Variant:
	if value == null:
		return null
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		if d.has("x") and d.has("y"):
			return Vector2i(int(d["x"]), int(d["y"]))
	return null


func _coords_dict(coords: Vector2i) -> Dictionary:
	return {"x": coords.x, "y": coords.y}
