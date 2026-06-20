## Phase 2+ editor tools.
class_name MCPEditorTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext
var _log_capture: MCPLogCapture


func setup(plugin: EditorPlugin, ctx: MCPEditorContext, log_capture: MCPLogCapture) -> void:
	_plugin = plugin
	_ctx = ctx
	_log_capture = log_capture


func get_editor_errors(params: Dictionary) -> Dictionary:
	var include_open_scripts := bool(params.get("include_open_scripts", true))
	var include_scene_validation := bool(params.get("include_scene_validation", true))
	var errors: Array[Dictionary] = []

	if include_open_scripts:
		errors.append_array(_validate_open_scripts())

	if include_scene_validation:
		errors.append_array(_validate_edited_scene())

	var fs := _plugin.get_editor_interface().get_resource_filesystem()
	if fs.is_scanning():
		errors.append({
			"source": "filesystem",
			"severity": "info",
			"message": "Editor filesystem scan in progress; error list may be incomplete.",
		})

	return {
		"errors": errors,
		"count": errors.size(),
	}


func get_output_log(params: Dictionary) -> Dictionary:
	if _log_capture == null:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INTERNAL_ERROR,
			"Log capture is not initialized.",
            "Disable and re-enable the Godot MCP plugin."
		)

	var limit := int(params.get("limit", 100))
	limit = clampi(limit, 1, 500)
	var kind_filter := str(params.get("kind", "")).strip_edges()
	return _log_capture.get_entries(limit, kind_filter)


func reload_project(_params: Dictionary) -> Dictionary:
	var fs := _ctx.iface().get_resource_filesystem()
	fs.scan()

	var reloaded_scene := ""
	var root := _ctx.edited_root()
	if root and not root.scene_file_path.is_empty():
		# Godot 4.4+ API: EditorInterface.reload_scene_from_path
		_ctx.iface().reload_scene_from_path(root.scene_file_path)
		reloaded_scene = root.scene_file_path

	return {
		"filesystem_scan_started": true,
		"reloaded_scene": reloaded_scene,
	}


func clear_output(_params: Dictionary) -> Dictionary:
	if _log_capture == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.INTERNAL_ERROR, "Log capture is not initialized.")
	_log_capture.clear()
	return {"cleared": true}


func reload_plugin(_params: Dictionary) -> Dictionary:
	var plugin_path := "res://addons/godot_mcp_personal/plugin.cfg"
	var iface := _ctx.iface()
	iface.set_plugin_enabled(plugin_path, false)
	iface.set_plugin_enabled(plugin_path, true)
	return {
		"reloaded": true,
		"plugin_path": plugin_path,
		"note": "WebSocket server restarts; reconnect MCP client if needed.",
	}


func get_editor_state(_params: Dictionary) -> Dictionary:
	var iface := _ctx.iface()
	var root := _ctx.edited_root()
	var script_editor := iface.get_script_editor()

	var open_scripts: Array[String] = []
	for script in script_editor.get_open_scripts():
		if script and not script.resource_path.is_empty():
			open_scripts.append(script.resource_path)

	var selected: Array[String] = []
	for node in iface.get_selection().get_selected_nodes():
		selected.append(_ctx.node_path_relative(node))

	var errors_result := get_editor_errors({
		"include_open_scripts": true,
		"include_scene_validation": true,
	})
	var error_count := 0
	if errors_result is Dictionary and errors_result.has("count"):
		error_count = int(errors_result.get("count", 0))

	return {
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"godot_version": Engine.get_version_info().get("string", ""),
		"edited_scene_path": root.scene_file_path if root else "",
		"edited_scene_root_type": root.get_class() if root else "",
		"is_playing": iface.is_playing_scene(),
		"playing_scene_path": iface.get_playing_scene(),
		"open_scripts": open_scripts,
		"open_script_count": open_scripts.size(),
		"selected_nodes": selected,
		"validation_issue_count": error_count,
		"mcp_plugin_active": true,
	}


func get_selected_nodes(_params: Dictionary) -> Dictionary:
	var selected: Array[Dictionary] = []
	for node in _ctx.iface().get_selection().get_selected_nodes():
		selected.append({
			"path": _ctx.node_path_relative(node),
			"name": node.name,
			"type": node.get_class(),
		})
	return {"nodes": selected, "count": selected.size()}


func list_node_types(params: Dictionary) -> Dictionary:
	var category := str(params.get("category", "")).strip_edges().to_lower()
	var search := str(params.get("search", "")).strip_edges().to_lower()

	var catalog: Dictionary = {
		"2d": [
			"Node2D", "Sprite2D", "AnimatedSprite2D", "Camera2D", "TileMapLayer",
			"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D", "CollisionShape2D",
			"Path2D", "Line2D", "Polygon2D", "Light2D", "AudioStreamPlayer2D",
		],
		"3d": [
			"Node3D", "MeshInstance3D", "Camera3D", "DirectionalLight3D", "OmniLight3D",
			"CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D", "CollisionShape3D",
			"NavigationRegion3D", "GPUParticles3D", "WorldEnvironment",
		],
		"ui": [
			"Control", "Label", "Button", "TextureRect", "Panel", "VBoxContainer",
			"HBoxContainer", "MarginContainer", "ScrollContainer", "ProgressBar",
			"LineEdit", "TextEdit", "RichTextLabel", "TabContainer", "Tree",
		],
		"animation": [
			"AnimationPlayer", "AnimationTree", "AnimationMixer", "Skeleton2D", "Skeleton3D",
		],
		"audio": ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"],
		"general": ["Node", "Timer", "HTTPRequest", "ResourcePreloader"],
	}

	if not category.is_empty() and catalog.has(category):
		var types: Array[String] = []
		for t in catalog[category]:
			if search.is_empty() or str(t).to_lower().contains(search):
				types.append(str(t))
		return {"category": category, "types": types, "count": types.size()}

	if not search.is_empty():
		var matches: Array[String] = []
		for key in catalog.keys():
			for t in catalog[key]:
				if str(t).to_lower().contains(search):
					matches.append(str(t))
		matches.sort()
		return {"search": search, "types": matches, "count": matches.size()}

	var categories: Array[String] = []
	for key in catalog.keys():
		categories.append(str(key))
	return {"categories": categories, "catalog": catalog}


func execute_editor_script(params: Dictionary) -> Dictionary:
	if OS.get_environment("ALLOW_GODOT_MCP_DANGEROUS") != "1":
		return MCPErrorCodes.make_error(
			MCPErrorCodes.DANGEROUS_TOOL_DISABLED,
			"execute_editor_script is disabled.",
			"Set ALLOW_GODOT_MCP_DANGEROUS=1 in Godot and MCP server env.",
		)

	var source := str(params.get("source", "")).strip_edges()
	if source.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'source' is required.")

	var mode := str(params.get("mode", "expression")).strip_edges().to_lower()
	if mode == "expression":
		var expression := Expression.new()
		var err := expression.parse(source)
		if err != OK:
			return MCPErrorCodes.make_error(
				MCPErrorCodes.INVALID_PARAMS,
				"Expression parse failed: %s" % expression.get_error_text(),
			)
		var result := expression.execute([], _McpEditorScriptContext.new(_ctx))
		if expression.has_execute_failed():
			return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Expression execution failed.")
		return {"mode": "expression", "result": str(result), "result_type": typeof(result)}

	var script := GDScript.new()
	script.source_code = "extends RefCounted\n\nvar ctx: MCPEditorContext\n\nfunc _init(editor_ctx: MCPEditorContext) -> void:\n\tctx = editor_ctx\n\nfunc run() -> Variant:\n%s\n" % _indent_lines(source, 1)
	var reload_err := script.reload()
	if reload_err != OK:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"Script compile failed with error code %d." % reload_err,
		)

	var runner = script.new(_ctx)
	if runner == null or not runner.has_method("run"):
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to create script runner.")

	var block_result = runner.run()
	return {"mode": "block", "result": str(block_result), "result_type": typeof(block_result)}


func _indent_lines(text: String, tabs: int) -> String:
	var prefix := "\t".repeat(tabs)
	var lines: PackedStringArray = []
	for line in text.split("\n"):
		lines.append(prefix + line)
	return "\n".join(lines)


class _McpEditorScriptContext extends RefCounted:
	var _ctx: MCPEditorContext

	func _init(ctx: MCPEditorContext) -> void:
		_ctx = ctx

	func edited_root() -> Node:
		return _ctx.edited_root()

	func resolve_node(path: String) -> Node:
		return _ctx.resolve_node(path)

	func editor() -> EditorInterface:
		return _ctx.iface()


func _validate_open_scripts() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var script_editor = _plugin.get_editor_interface().get_script_editor()
	for script in script_editor.get_open_scripts():
		if script == null:
			continue
		var path := script.resource_path
		if path.is_empty() or not path.ends_with(".gd"):
			continue

		var source := MCPPathUtils.read_text_file(path)
		if source.is_empty():
			continue

		var gd := GDScript.new()
		gd.source_code = source
		var err := gd.reload()
		if err != OK:
			results.append({
				"source": "script",
				"severity": "error",
				"path": path,
				"message": "GDScript parse/compile failed with error code %d" % err,
			})
	return results


func _validate_edited_scene() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var root := _plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return results

	_check_node_recursive(root, results)
	return results


func _check_node_recursive(node: Node, results: Array) -> void:
	if node.get_script() == null and node.get_class() == "Node":
		pass

	for child in node.get_children():
		if child.owner == null and child != node and node == _plugin.get_editor_interface().get_edited_scene_root():
			results.append({
				"source": "scene",
				"severity": "warning",
				"path": str(child.get_path()),
				"message": "Node has no owner (may not be saved in scene).",
			})
		_check_node_recursive(child, results)
