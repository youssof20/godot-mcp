## Phase 2 project read tools.
class_name MCPProjectTools
extends RefCounted

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func get_project_info(_params: Dictionary) -> Dictionary:
	var version_info: Dictionary = Engine.get_version_info()
	return {
		"name": str(ProjectSettings.get_setting("application/config/name", "")),
		"project_path": ProjectSettings.globalize_path("res://"),
		"res_path": "res://",
		"godot_version": version_info.get("string", ""),
		"godot_version_info": version_info,
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"features": ProjectSettings.get_setting("application/config/features", PackedStringArray()),
	}


func get_filesystem_tree(params: Dictionary) -> Dictionary:
	var root_path := str(params.get("path", "res://"))
	root_path = MCPPathUtils.normalize_res_path(root_path)
	if not MCPPathUtils.is_inside_project(root_path):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"Path must be inside the project (res://).",
			"Use a path such as res:// or res://addons."
		)

	var max_depth := int(params.get("max_depth", 10))
	max_depth = clampi(max_depth, 1, 32)
	var include_files := bool(params.get("include_files", true))

	return {
		"root": root_path,
		"tree": _build_tree(root_path, 0, max_depth, include_files),
	}


func search_files(params: Dictionary) -> Dictionary:
	var query := str(params.get("query", "")).strip_edges()
	if query.is_empty():
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"'query' is required.",
			"Provide a filename substring or glob-like pattern (e.g. *.gd)."
		)

	var root_path := MCPPathUtils.normalize_res_path(str(params.get("path", "res://")))
	if not MCPPathUtils.is_inside_project(root_path):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"Path must be inside the project.",
		)

	var extensions: Array = params.get("extensions", [])
	var max_results := int(params.get("max_results", 200))
	max_results = clampi(max_results, 1, 2000)

	var matches: Array[Dictionary] = []
	_search_dir(root_path, query, extensions, matches, max_results)

	return {
		"query": query,
		"path": root_path,
		"matches": matches,
		"count": matches.size(),
	}


func get_project_settings(params: Dictionary) -> Dictionary:
	var keys: Array = params.get("keys", [])
	var prefix := str(params.get("prefix", "")).strip_edges()

	if not keys.is_empty():
		var result: Dictionary = {}
		for key in keys:
			var setting_key := str(key)
			if ProjectSettings.has_setting(setting_key):
				result[setting_key] = ProjectSettings.get_setting(setting_key)
			else:
				result[setting_key] = null
		return {"settings": result, "mode": "keys"}

	if not prefix.is_empty():
		var prefixed: Dictionary = {}
		for prop in ProjectSettings.get_property_list():
			var name := str(prop.get("name", ""))
			if name.begins_with(prefix):
				prefixed[name] = ProjectSettings.get_setting(name)
		return {"settings": prefixed, "mode": "prefix", "prefix": prefix}

	return MCPErrorCodes.make_error(
		MCPErrorCodes.INVALID_PARAMS,
		"Provide 'keys' array or 'prefix' string.",
		"Example keys: ['application/config/name'] or prefix: 'application/'"
	)


func uid_to_project_path(params: Dictionary) -> Dictionary:
	var uid := str(params.get("uid", "")).strip_edges()
	if uid.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'uid' is required.")

	if not uid.begins_with("uid://"):
		uid = "uid://" + uid.trim_prefix("uid:/")

	# Godot 4.4+ API: ResourceUID.text_to_id / uid_to_path
	var id := ResourceUID.text_to_id(uid)
	if id <= 0 or not ResourceUID.has_id(id):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"No project path for UID: %s" % uid,
			"Check the UID in the Godot FileSystem dock or .uid files."
		)

	var path := ResourceUID.uid_to_path(uid)
	return {"uid": uid, "path": path}


func project_path_to_uid(params: Dictionary) -> Dictionary:
	var path := MCPPathUtils.normalize_res_path(str(params.get("path", "")))
	if path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'path' is required.")

	if not MCPPathUtils.is_inside_project(path):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Path must be under res://.")

	if not MCPPathUtils.file_exists(path):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"File not found: %s" % path,
		)

	# Godot 4.4+ API: ResourceUID.path_to_uid
	var uid := ResourceUID.path_to_uid(path)
	if uid == path:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"No UID registered for path: %s" % path,
			"Open the project in Godot so UIDs are generated, or reimport the file."
		)

	return {"path": path, "uid": uid}


func _build_tree(path: String, depth: int, max_depth: int, include_files: bool) -> Dictionary:
	var global_path := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(path)
	var node: Dictionary = {
		"path": path,
		"name": path.get_file() if path != "res://" else "res://",
		"type": "directory",
		"children": [],
	}

	if dir == null:
		node["error"] = "Unable to open directory"
		return node

	if depth >= max_depth:
		node["truncated"] = true
		return node

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not MCPPathUtils.should_skip_dir(entry_name):
			var child_path := path.path_join(entry_name)
			if dir.current_is_dir():
				node["children"].append(_build_tree(child_path, depth + 1, max_depth, include_files))
			elif include_files:
				node["children"].append({
					"path": child_path,
					"name": entry_name,
					"type": "file",
				})
		entry_name = dir.get_next()
	dir.list_dir_end()

	node["children"].sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return node


func _search_dir(path: String, query: String, extensions: Array, matches: Array, max_results: int) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "" and matches.size() < max_results:
		if MCPPathUtils.should_skip_dir(entry_name):
			entry_name = dir.get_next()
			continue

		var child_path := path.path_join(entry_name)
		if dir.current_is_dir():
			_search_dir(child_path, query, extensions, matches, max_results)
		else:
			if _file_matches(entry_name, query, extensions):
				matches.append({"path": child_path, "name": entry_name})
		entry_name = dir.get_next()
	dir.list_dir_end()


func _file_matches(filename: String, query: String, extensions: Array) -> bool:
	if not extensions.is_empty():
		var matched_ext := false
		for ext in extensions:
			var e := str(ext).strip_edges().to_lower()
			if not e.begins_with("."):
				e = "." + e
			if filename.to_lower().ends_with(e):
				matched_ext = true
				break
		if not matched_ext:
			return false

	if query.contains("*") or query.contains("?"):
		return filename.match(query)

	return query.to_lower() in filename.to_lower()
