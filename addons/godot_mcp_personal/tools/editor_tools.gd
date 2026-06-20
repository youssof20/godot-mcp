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
