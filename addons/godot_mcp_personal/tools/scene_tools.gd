## Phase 2+ scene tools.
class_name MCPSceneTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func get_scene_tree(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", "")).strip_edges()
	var max_depth := int(params.get("max_depth", 12))
	max_depth = clampi(max_depth, 1, 64)

	var root: Node = null
	var source := "edited"

	if scene_path.is_empty():
		# Godot 4.4+ API: EditorInterface.get_edited_scene_root()
		root = _plugin.get_editor_interface().get_edited_scene_root()
		if root == null:
			return MCPErrorCodes.make_error(
				MCPErrorCodes.NOT_FOUND,
				"No scene is currently open in the editor.",
				"Open a scene in Godot or pass scene_path."
			)
	else:
		scene_path = MCPPathUtils.normalize_res_path(scene_path)
		if not MCPPathUtils.file_exists(scene_path):
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)

		var packed: PackedScene = load(scene_path)
		if packed == null:
			return MCPErrorCodes.make_error(
				MCPErrorCodes.SCENE_ERROR,
				"Failed to load scene: %s" % scene_path,
			)
		root = packed.instantiate()
		source = "file"
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to instantiate scene.")

	var tree := _node_to_dict(root, 0, max_depth, source == "edited", root)
	var result := {
		"source": source,
		"tree": tree,
	}
	if source == "file":
		result["scene_path"] = scene_path
		root.free()
	else:
		result["scene_path"] = root.scene_file_path

	return result


func get_scene_file_content(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")))
	if scene_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'scene_path' is required.")

	if not scene_path.ends_with(".tscn") and not scene_path.ends_with(".scn"):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"Scene path must end with .tscn or .scn",
		)

	if not MCPPathUtils.file_exists(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)

	var content := MCPPathUtils.read_text_file(scene_path)
	return {
		"scene_path": scene_path,
		"content": content,
		"size_bytes": content.length(),
	}


func _node_to_dict(node: Node, depth: int, max_depth: int, relative: bool = false, scene_root: Node = null) -> Dictionary:
	var path_str := _ctx.node_path_relative(node) if relative and scene_root else str(node.get_path())
	var entry: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": path_str,
	}
	if node.scene_file_path:
		entry["scene_file_path"] = node.scene_file_path
	if node.get_script():
		var script: Script = node.get_script()
		entry["script"] = script.resource_path if script.resource_path else str(script)

	if depth >= max_depth:
		entry["truncated"] = true
		entry["child_count"] = node.get_child_count()
		return entry

	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_node_to_dict(child, depth + 1, max_depth, relative, scene_root))
	entry["children"] = children
	return entry


func create_scene(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")))
	var root_type := str(params.get("root_type", "Node2D"))
	var root_name := str(params.get("root_name", "Root"))
	var open_after := bool(params.get("open", true))

	if scene_path.is_empty() or not scene_path.ends_with(".tscn"):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"'scene_path' must be a .tscn path under res://.",
		)
	if not MCPPathUtils.is_inside_project(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.PERMISSION_DENIED, "Path outside project.")
	if MCPPathUtils.file_exists(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Scene already exists: %s" % scene_path)

	if not _ctx.is_valid_node_type(root_type):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.UNSUPPORTED_NODE_TYPE,
			"Unsupported root node type: %s" % root_type,
		)

	var root := _ctx.instantiate_node(root_type)
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to instantiate %s" % root_type)
	root.name = root_name

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to pack scene (error %d)" % pack_err)

	_ensure_parent_dir(scene_path)
	var save_err := ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to save scene (error %d)" % save_err)

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create Scene: %s" % scene_path.get_file())
	ur.add_do_method(self, "_restore_scene_file", scene_path, packed)
	ur.add_undo_method(self, "_delete_scene_file", scene_path)
	ur.commit_action()

	if open_after:
		_ctx.iface().open_scene_from_path(scene_path)

	return {
		"scene_path": scene_path,
		"root_type": root_type,
		"root_name": root_name,
		"opened": open_after,
	}


func open_scene(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")))
	if scene_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'scene_path' is required.")
	if not MCPPathUtils.file_exists(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)

	# Godot 4.4+ API: EditorInterface.open_scene_from_path
	_ctx.iface().open_scene_from_path(scene_path)
	return {"scene_path": scene_path, "opened": true}


func save_scene(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", "")).strip_edges()
	if scene_path.is_empty():
		# Godot 4.4+ API: EditorInterface.save_scene()
		var err := _ctx.iface().save_scene()
		if err != OK:
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "save_scene failed (error %d)" % err)
		var root := _ctx.edited_root()
		return {
			"saved": true,
			"scene_path": root.scene_file_path if root else "",
		}

	scene_path = MCPPathUtils.normalize_res_path(scene_path)
	# Godot 4.4+ API: EditorInterface.save_scene_as (void)
	_ctx.iface().save_scene_as(scene_path)
	return {"saved": true, "scene_path": scene_path}


func delete_scene(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")))
	if scene_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'scene_path' is required.")
	if not MCPPathUtils.file_exists(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)

	for open_root in _ctx.iface().get_open_scene_roots():
		if open_root.scene_file_path == scene_path:
			return MCPErrorCodes.make_error(
				MCPErrorCodes.SCENE_ERROR,
				"Scene is open in the editor. Close it before deleting.",
			)

	var backup := MCPPathUtils.read_text_file(scene_path)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Delete Scene: %s" % scene_path.get_file())
	ur.add_do_method(self, "_delete_scene_file", scene_path)
	ur.add_undo_method(self, "_write_text_file", scene_path, backup)
	ur.commit_action()

	return {"deleted": true, "scene_path": scene_path}


func _ensure_parent_dir(scene_path: String) -> void:
	var dir_path := scene_path.get_base_dir()
	var global_dir := ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(global_dir)


func _restore_scene_file(scene_path: String, packed: PackedScene) -> void:
	_ensure_parent_dir(scene_path)
	ResourceSaver.save(packed, scene_path)


func _delete_scene_file(scene_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(scene_path)
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
	var uid_path := global_path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)


func _write_text_file(path: String, content: String) -> void:
	_ensure_parent_dir(path)
	var global_path := ProjectSettings.globalize_path(path)
	var f := FileAccess.open(global_path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()

