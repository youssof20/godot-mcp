@tool
extends Node

var editor_plugin: EditorPlugin


## Override in subclasses: return {"method_name": Callable}
func get_commands() -> Dictionary:
	return {}


## Helper: return a success result
func success(data: Dictionary = {}) -> Dictionary:
	return {"result": data}


## Helper: return an error
func error(code: int, message: String, data: Dictionary = {}) -> Dictionary:
	var err := {"code": code, "message": message}
	if not data.is_empty():
		err["data"] = data
	return {"error": err}


## Error codes
func error_not_found(what: String, suggestion: String = "") -> Dictionary:
	var data := {}
	if suggestion:
		data["suggestion"] = suggestion
	return error(-32001, "%s not found" % what, data)


func error_invalid_params(message: String) -> Dictionary:
	return error(-32602, message)


func error_no_scene(extra: Dictionary = {}) -> Dictionary:
	var data := {
		"suggestion": "Open a .tscn in the editor (FileSystem dock) or call open_scene. Set Project → Project Settings → Application → Run → Main Scene for F5 / play_scene mode main.",
		"open_scenes": get_open_scene_paths(),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
	}
	data.merge(extra, true)
	return error(-32000, "No scene is currently open in the editor", data)


## Open application/run/main_scene in the editor if configured. Returns true when edited root exists after.
func try_open_main_scene() -> bool:
	if get_edited_root() != null:
		return true
	var main: Variant = ProjectSettings.get_setting("application/run/main_scene", "")
	if typeof(main) != TYPE_STRING:
		return false
	var path := (main as String).strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	EditorInterface.open_scene_from_path(path)
	return get_edited_root() != null


func error_internal(message: String) -> Dictionary:
	return error(-32603, "Internal error: %s" % message)


func error_conflict(message: String, data: Dictionary = {}) -> Dictionary:
	var payload := data.duplicate(true)
	if not payload.has("plain_english"):
		var plain := message
		if payload.has("suggestion"):
			plain = "%s %s" % [message, payload["suggestion"]]
		payload["plain_english"] = plain
	payload["error_kind"] = "editor_state_conflict"
	return error(-32009, message, payload)


## Get required string param
func require_string(params: Dictionary, key: String) -> Array:
	if not params.has(key) or not params[key] is String or (params[key] as String).is_empty():
		return [null, error_invalid_params("Missing required parameter: %s" % key)]
	return [params[key] as String, null]


## Get optional string param with default
func optional_string(params: Dictionary, key: String, default: String = "") -> String:
	if params.has(key) and params[key] is String:
		return params[key] as String
	return default


## Get optional bool param with default
func optional_bool(params: Dictionary, key: String, default: bool = false) -> bool:
	if params.has(key) and params[key] is bool:
		return params[key] as bool
	return default


## Get optional int param with default
func optional_int(params: Dictionary, key: String, default: int = 0) -> int:
	if params.has(key):
		return int(params[key])
	return default


## Get the game process's user data directory.
## OS.get_user_data_dir() is cached at editor startup and won't reflect
## project name changes made to project.godot while the editor is running.
## The game process reads the name from disk, so we must do the same.
func get_game_user_dir() -> String:
	var cached_dir := OS.get_user_data_dir()
	var cfg := ConfigFile.new()
	var err := cfg.load(ProjectSettings.globalize_path("res://project.godot"))
	if err != OK:
		return cached_dir
	# When use_custom_user_dir=true, editor and game share the same dir
	# (OS.get_user_data_dir() already resolves to the custom path).
	if cfg.get_value("application", "config/use_custom_user_dir", false):
		return cached_dir
	var disk_name = cfg.get_value("application", "config/name", "")
	if typeof(disk_name) != TYPE_STRING or (disk_name as String).is_empty():
		return cached_dir
	# Sanitize exactly like Godot does when computing the default user dir
	# (core/config/project_settings.cpp ProjectSettings::_init).
	var sanitized := (disk_name as String).xml_unescape().validate_filename().replace(".", "_")
	if sanitized.is_empty():
		return cached_dir
	var base_dir := cached_dir.get_base_dir()
	var game_dir := base_dir.path_join(sanitized)
	# Ensure the directory exists (game may not have created it yet)
	if not DirAccess.dir_exists_absolute(game_dir):
		DirAccess.make_dir_recursive_absolute(game_dir)
	return game_dir


## Get EditorInterface
func get_editor() -> EditorInterface:
	return editor_plugin.get_editor_interface()


## Get the edited scene root
func get_edited_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## Get UndoRedo
func get_undo_redo() -> EditorUndoRedoManager:
	return editor_plugin.get_undo_redo()


func normalize_project_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	return ProjectSettings.localize_path(path).simplify_path()


func is_scene_resource_path(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "tscn" or ext == "scn"


func get_open_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	for scene_path: String in open_scenes:
		var normalized := normalize_project_path(scene_path)
		if not normalized.is_empty() and normalized not in paths:
			paths.append(normalized)

	var root := get_edited_root()
	if root != null and not root.scene_file_path.is_empty():
		var active_path := normalize_project_path(root.scene_file_path)
		if active_path not in paths:
			paths.append(active_path)
	return paths


func is_scene_path_open(path: String) -> bool:
	var normalized := normalize_project_path(path)
	if normalized.is_empty():
		return false
	return normalized in get_open_scene_paths()


func is_active_scene_path(path: String) -> bool:
	var root := get_edited_root()
	if root == null:
		return false
	return normalize_project_path(root.scene_file_path) == normalize_project_path(path)


func guard_offline_scene_save(path: String) -> Dictionary:
	if is_scene_resource_path(path) and is_scene_path_open(path):
		var norm := normalize_project_path(path)
		return error_conflict(
			"Cannot patch open scene file '%s' from MCP — the scene is loaded in the Godot editor." % norm,
			{
				"path": norm,
				"open_scenes": get_open_scene_paths(),
				"plain_english":
					"Refused to overwrite '%s' because that .tscn is open in Godot. " % norm +
					"Use add_node, update_property, and save_scene on the live editor scene instead of editing the file on disk. " +
					"Or close the scene tab in Godot first, or pass force=true only if you accept corruption risk.",
				"suggestion": "Use live editor tools (add_node, update_property, save_scene) instead of offline file edits.",
			}
		)
	return {}


func is_shader_resource_path(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "gdshader" or ext == "gdshaderinc" or ext == "shader"


func is_text_resource_open_in_script_editor(path: String) -> bool:
	var target := normalize_project_path(path)
	if target.is_empty():
		return false
	if is_shader_resource_path(target) and ResourceLoader.has_cached(target):
		return true
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return false
	for open_resource in script_editor.get_open_scripts():
		if open_resource is Resource:
			var resource_path := normalize_project_path((open_resource as Resource).resource_path)
			if resource_path == target:
				return true
	return false


func guard_text_resource_write(path: String, force: bool) -> Dictionary:
	if not force and is_text_resource_open_in_script_editor(path):
		var norm := normalize_project_path(path)
		return error_conflict(
			"Cannot overwrite '%s' while it is open in Godot's script editor." % norm,
			{
				"path": norm,
				"plain_english":
					"Refused to write '%s' because that file is open in the Godot script editor. " % norm +
					"Use edit_script (which goes through the editor) or close the script tab first. " +
					"Pass force=true only if you deliberately want to overwrite from disk.",
				"suggestion": "Close the script in Godot or use edit_script instead of raw file writes.",
			}
		)
	return {}


func mark_current_scene_unsaved() -> void:
	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()


func add_child_with_undo(parent: Node, child: Node, root: Node, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", child)
	undo_redo.add_do_method(child, "set_owner", root)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(parent, "remove_child", child)
	undo_redo.commit_action()


func set_property_with_undo(target: Object, property: String, new_value: Variant, action_name: String) -> void:
	var old_value: Variant = target.get(property)
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(target, property, new_value)
	if new_value is Resource:
		undo_redo.add_do_reference(new_value)
	undo_redo.add_undo_property(target, property, old_value)
	if old_value is Resource:
		undo_redo.add_undo_reference(old_value)
	undo_redo.commit_action()


## Find node by path in edited scene
func find_node_by_path(node_path: String) -> Node:
	var root := get_edited_root()
	if root == null:
		return null
	if node_path == "." or node_path == root.name:
		return root
	# Try relative from root
	if root.has_node(node_path):
		return root.get_node(node_path)
	# Try with root name prefix stripped
	if node_path.begins_with(root.name + "/"):
		var rel := node_path.substr(root.name.length() + 1)
		if root.has_node(rel):
			return root.get_node(rel)
	return null
