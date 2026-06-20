## Phase 8 navigation tools.
class_name MCPNavigationTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func setup_navigation_region(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var dim := str(params.get("dimension", "3d")).to_lower()
	var node_type := "NavigationRegion3D" if dim == "3d" else "NavigationRegion2D"
	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var region := _ctx.instantiate_node(node_type)
	region.name = str(params.get("node_name", node_type))
	if params.has("navigation_layers"):
		region.set("navigation_layers", int(params.get("navigation_layers")))

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Navigation Region")
	ur.add_do_method(parent, "add_child", region)
	ur.add_do_method(region, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", region)
	ur.add_undo_method(region, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(region), "type": region.get_class()}


func setup_navigation_agent(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var dim := str(params.get("dimension", "3d")).to_lower()
	var node_type := "NavigationAgent3D" if dim == "3d" else "NavigationAgent2D"
	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var agent := _ctx.instantiate_node(node_type)
	agent.name = str(params.get("node_name", node_type))
	if params.has("target_desired_distance"):
		agent.set("target_desired_distance", float(params.get("target_desired_distance")))
	if params.has("path_desired_distance"):
		agent.set("path_desired_distance", float(params.get("path_desired_distance")))

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Navigation Agent")
	ur.add_do_method(parent, "add_child", agent)
	ur.add_do_method(agent, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", agent)
	ur.add_undo_method(agent, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(agent), "type": agent.get_class()}


func bake_navigation_mesh(params: Dictionary) -> Dictionary:
	var region := _resolve_navigation_region(params)
	if region == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "NavigationRegion not found.")

	if region is NavigationRegion3D:
		(region as NavigationRegion3D).bake_navigation_mesh()
	elif region is NavigationRegion2D:
		(region as NavigationRegion2D).bake_navigation_mesh()

	return {
		"node_path": _ctx.node_path_relative(region),
		"baked": true,
		"type": region.get_class(),
	}


func set_navigation_layers(params: Dictionary) -> Dictionary:
	var region := _resolve_navigation_region(params)
	if region == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "NavigationRegion not found.")

	if not params.has("navigation_layers"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "navigation_layers required.")

	var layers := int(params.get("navigation_layers"))
	var prev := int(region.get("navigation_layers"))
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Set Navigation Layers")
	ur.add_do_property(region, "navigation_layers", layers)
	ur.add_undo_property(region, "navigation_layers", prev)
	ur.commit_action()

	return get_navigation_info({"node_path": _ctx.node_path_relative(region)})


func get_navigation_info(params: Dictionary) -> Dictionary:
	var region := _resolve_navigation_region(params)
	if region == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "NavigationRegion not found.")

	var info := {
		"node_path": _ctx.node_path_relative(region),
		"type": region.get_class(),
		"navigation_layers": int(region.get("navigation_layers")),
	}

	if region is NavigationRegion3D:
		var r3 := region as NavigationRegion3D
		info["enabled"] = r3.enabled
		info["has_nav_mesh"] = r3.navigation_mesh != null
	elif region is NavigationRegion2D:
		var r2 := region as NavigationRegion2D
		info["enabled"] = r2.enabled
		info["has_nav_mesh"] = r2.navigation_polygon != null

	return info


func get_navigation_path_preview(params: Dictionary) -> Dictionary:
	var dim := str(params.get("dimension", "3d")).to_lower()
	var from_pos := _to_vector3(params.get("from", {"x": 0, "y": 0, "z": 0}))
	var to_pos := _to_vector3(params.get("to", {"x": 1, "y": 0, "z": 0}))

	if dim == "2d":
		var map_rid := NavigationServer2D.get_maps()[0] if NavigationServer2D.get_maps().size() > 0 else RID()
		if map_rid == RID():
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No 2D navigation map. Bake a NavigationRegion2D first.")
		var path: PackedVector2Array = NavigationServer2D.map_get_path(
			map_rid,
			Vector2(from_pos.x, from_pos.y),
			Vector2(to_pos.x, to_pos.y),
			true
		)
		var points: Array[Dictionary] = []
		for p in path:
			points.append({"x": p.x, "y": p.y})
		return {"dimension": "2d", "points": points, "count": points.size()}

	var map_rid3 := NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
	if map_rid3 == RID():
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No 3D navigation map. Bake a NavigationRegion3D first.")
	var path3: PackedVector3Array = NavigationServer3D.map_get_path(map_rid3, from_pos, to_pos, true)
	var points3: Array[Dictionary] = []
	for p in path3:
		points3.append({"x": p.x, "y": p.y, "z": p.z})
	return {"dimension": "3d", "points": points3, "count": points3.size()}


func _resolve_navigation_region(params: Dictionary) -> Node:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return null
	var node := _ctx.resolve_node(node_path)
	if node is NavigationRegion2D or node is NavigationRegion3D:
		return node
	return null


func _to_vector3(value: Variant) -> Vector3:
	var parsed := MCPTypeParser.parse_value(value)
	if parsed is Vector3:
		return parsed
	if parsed is Vector2:
		return Vector3(parsed.x, parsed.y, 0.0)
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
	return Vector3.ZERO
