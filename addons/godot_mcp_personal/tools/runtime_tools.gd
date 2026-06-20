## Phase 5 runtime tools.
class_name MCPRuntimeTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext
var _runtime: MCPRuntimeHelper


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx
	_runtime = MCPRuntimeHelper.new()
	_runtime.setup(ctx)


func play_scene(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", "")).strip_edges()
	if scene_path.is_empty():
		# Godot 4.4+ API: EditorInterface.play_current_scene()
		_ctx.iface().play_current_scene()
	else:
		scene_path = MCPPathUtils.normalize_res_path(scene_path)
		if not MCPPathUtils.file_exists(scene_path):
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)
		_ctx.iface().play_custom_scene(scene_path)

	return {
		"playing": _ctx.iface().is_playing_scene(),
		"scene_path": _ctx.iface().get_playing_scene(),
	}


func stop_scene(_params: Dictionary) -> Dictionary:
	if not _ctx.iface().is_playing_scene():
		return {"stopped": false, "message": "No scene was playing."}
	_ctx.iface().stop_playing_scene()
	return {"stopped": true}


func get_runtime_status(_params: Dictionary) -> Dictionary:
	var edited := _ctx.edited_root()
	return {
		"is_playing": _ctx.iface().is_playing_scene(),
		"playing_scene_path": _ctx.iface().get_playing_scene(),
		"edited_scene_path": edited.scene_file_path if edited else "",
		"runtime_root_found": _runtime.find_runtime_root() != null,
	}


func get_game_scene_tree(params: Dictionary) -> Dictionary:
	var root := _runtime.find_runtime_root()
	if root == null:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.RUNTIME_NOT_RUNNING,
			"Game is not running or runtime root could not be located.",
			"Press F6 to play the current scene (embedded game view recommended).",
		)
	var max_depth := clampi(int(params.get("max_depth", 12)), 1, 64)
	return {
		"playing_scene_path": _runtime.playing_scene_path(),
		"tree": _runtime.node_to_tree(root, 0, max_depth, root),
	}


func get_game_node_properties(params: Dictionary) -> Dictionary:
	var root := _runtime.find_runtime_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var node_path := str(params.get("node_path", "")).strip_edges()
	var node := _runtime.resolve_runtime_node(node_path) if not node_path.is_empty() else root
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Runtime node not found: %s" % node_path)

	return _serialize_node_props(node, params, root)


func set_game_node_property(params: Dictionary) -> Dictionary:
	if not _runtime.is_playing():
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var node_path := str(params.get("node_path", "")).strip_edges()
	var property := str(params.get("property", "")).strip_edges()
	if node_path.is_empty() or property.is_empty() or not params.has("value"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "node_path, property, value required.")

	var node := _runtime.resolve_runtime_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Runtime node not found.")

	var new_val := MCPTypeParser.coerce_for_property(node, property, params["value"])
	var old_val = node.get(property)
	node.set(property, new_val)

	return {
		"node_path": _ctx.node_path_relative_to(node, _runtime.find_runtime_root()),
		"property": property,
		"old_value": str(old_val),
		"new_value": str(new_val),
		"note": "Runtime property changes are not undoable and reset when play stops.",
	}


func batch_get_properties(params: Dictionary) -> Dictionary:
	var requests: Array = params.get("requests", [])
	if requests.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'requests' array required.")

	var root := _runtime.find_runtime_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var results: Array[Dictionary] = []
	for req in requests:
		if typeof(req) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = req
		var node := _runtime.resolve_runtime_node(str(d.get("node_path", "")))
		if node == null:
			results.append({"node_path": d.get("node_path", ""), "error": "not_found"})
			continue
		var props: Array = d.get("properties", [])
		var values: Dictionary = {}
		for p in props:
			values[str(p)] = str(node.get(str(p)))
		results.append({"node_path": _ctx.node_path_relative_to(node, root), "properties": values})

	return {"results": results, "count": results.size()}


func get_autoload(_params: Dictionary) -> Dictionary:
	var autoloads: Array[Dictionary] = []
	for prop in ProjectSettings.get_property_list():
		var name := str(prop.get("name", ""))
		if name.begins_with("autoload/"):
			autoloads.append({
				"name": name.trim_prefix("autoload/"),
				"path": str(ProjectSettings.get_setting(name, "")),
			})
	return {"autoloads": autoloads, "count": autoloads.size()}


func find_nodes_by_script(params: Dictionary) -> Dictionary:
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	if script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'script_path' required.")

	var use_runtime := bool(params.get("runtime", true))
	var root: Node = null
	if use_runtime:
		root = _runtime.find_runtime_root()
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")
	else:
		root = _ctx.edited_root()
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No edited scene.")

	var matches: Array[Dictionary] = []
	_find_script_recursive(root, script_path, root, matches)
	return {"matches": matches, "count": matches.size()}


func wait_for_node(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var timeout_ms := clampi(int(params.get("timeout_ms", 5000)), 100, 60000)
	var interval_ms := clampi(int(params.get("poll_interval_ms", 100)), 50, 1000)

	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' required.")

	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var node := _runtime.resolve_runtime_node(node_path)
		if node != null:
			return {
				"found": true,
				"node_path": _ctx.node_path_relative_to(node, _runtime.find_runtime_root()),
				"type": node.get_class(),
				"elapsed_ms": timeout_ms - (deadline - Time.get_ticks_msec()),
			}
		OS.delay_msec(interval_ms)

	return MCPErrorCodes.make_error(
		MCPErrorCodes.TIMEOUT,
		"Node '%s' not found within %dms." % [node_path, timeout_ms],
	)


func find_ui_elements(params: Dictionary) -> Dictionary:
	var root := _runtime.find_runtime_root()
	if root == null:
		root = _ctx.edited_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No scene available.")

	var type_filter := str(params.get("type", "Control")).strip_edges()
	var matches: Array[Dictionary] = []
	_find_type_recursive(root, type_filter, root, matches, int(params.get("max_results", 100)))
	return {"elements": matches, "count": matches.size()}


func click_button_by_text(params: Dictionary) -> Dictionary:
	var text := str(params.get("text", "")).strip_edges()
	if text.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'text' required.")

	var root := _runtime.find_runtime_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var button := _find_button_by_text(root, text)
	if button == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No button with text '%s'." % text)

	if button.has_signal("pressed"):
		button.emit_signal("pressed")
	return {
		"clicked": true,
		"node_path": _ctx.node_path_relative_to(button, root),
		"text": text,
	}


func find_nearby_nodes(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var radius := float(params.get("radius", 100.0))
	var root := _runtime.find_runtime_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var origin := _runtime.resolve_runtime_node(node_path)
	if origin == null or not origin is Node2D:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "node_path must be a Node2D.")

	var origin_2d := origin as Node2D
	var nearby: Array[Dictionary] = []
	for node in root.find_children("*", "Node2D", true, false):
		if node == origin_2d:
			continue
		var n2d := node as Node2D
		if origin_2d.global_position.distance_to(n2d.global_position) <= radius:
			nearby.append({
				"path": _ctx.node_path_relative_to(n2d, root),
				"distance": origin_2d.global_position.distance_to(n2d.global_position),
			})

	return {"origin": _ctx.node_path_relative_to(origin_2d, root), "nearby": nearby, "count": nearby.size()}


func navigate_to(params: Dictionary) -> Dictionary:
	params["property"] = "global_position"
	return move_to(params)


func move_to(params: Dictionary) -> Dictionary:
	if not _runtime.is_playing():
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var node_path := str(params.get("node_path", "")).strip_edges()
	var node := _runtime.resolve_runtime_node(node_path)
	if node == null or not node is Node2D:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "node_path must be Node2D.")

	var pos_dict: Dictionary = params.get("position", {})
	if not pos_dict.has("x") or not pos_dict.has("y"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'position' with x,y required.")

	var target := Vector2(float(pos_dict["x"]), float(pos_dict["y"]))
	var n2d := node as Node2D
	var old := n2d.global_position
	n2d.global_position = target
	return {
		"node_path": _ctx.node_path_relative_to(n2d, _runtime.find_runtime_root()),
		"old_position": str(old),
		"new_position": str(target),
	}


func execute_game_script(params: Dictionary) -> Dictionary:
	if OS.get_environment("ALLOW_GODOT_MCP_DANGEROUS") != "1":
		return MCPErrorCodes.make_error(
			MCPErrorCodes.DANGEROUS_TOOL_DISABLED,
			"execute_game_script is disabled.",
			"Set ALLOW_GODOT_MCP_DANGEROUS=1 in Godot and MCP server env.",
		)
	if not _runtime.is_playing():
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	return MCPErrorCodes.make_error(
		MCPErrorCodes.NOT_IMPLEMENTED,
		"execute_game_script requires a debugger eval bridge (planned).",
		"Use set_game_node_property or update_property for now.",
	)


func _serialize_node_props(node: Node, params: Dictionary, scene_root: Node) -> Dictionary:
	var requested: Array = params.get("properties", [])
	var props: Dictionary = {}
	if requested.is_empty():
		for info in node.get_property_list():
			if int(info.get("usage", 0)) & PROPERTY_USAGE_EDITOR:
				var pname := str(info.get("name", ""))
				if not pname.is_empty():
					props[pname] = str(node.get(pname))
	else:
		for p in requested:
			props[str(p)] = str(node.get(str(p)))
	return {
		"node_path": _ctx.node_path_relative_to(node, scene_root),
		"type": node.get_class(),
		"properties": props,
	}


func _find_script_recursive(node: Node, script_path: String, root: Node, out: Array) -> void:
	if node.get_script():
		var s: Script = node.get_script()
		if s.resource_path == script_path:
			out.append({
				"path": _ctx.node_path_relative_to(node, root),
				"name": node.name,
				"type": node.get_class(),
			})
	for child in node.get_children():
		_find_script_recursive(child, script_path, root, out)


func _find_type_recursive(node: Node, type_name: String, root: Node, out: Array, max_count: int) -> void:
	if out.size() >= max_count:
		return
	if node.is_class(type_name) or node.get_class() == type_name:
		out.append({
			"path": _ctx.node_path_relative_to(node, root),
			"type": node.get_class(),
			"name": node.name,
		})
	for child in node.get_children():
		_find_type_recursive(child, type_name, root, out, max_count)


func _find_button_by_text(node: Node, text: String) -> BaseButton:
	if node is BaseButton:
		var btn := node as BaseButton
		if btn.text == text:
			return btn
	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null
