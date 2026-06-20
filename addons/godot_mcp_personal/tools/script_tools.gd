## Phase 2+ script tools.
class_name MCPScriptTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext

const SCRIPT_EXTENSIONS: Array[String] = ["gd", "cs", "gdshader", "shader"]
const DEFAULT_GDSCRIPT_TEMPLATE := "extends %s\n\n\nfunc _ready() -> void:\n\tpass\n"


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func list_scripts(params: Dictionary) -> Dictionary:
	var root_path := MCPPathUtils.normalize_res_path(str(params.get("path", "res://")))
	if not MCPPathUtils.is_inside_project(root_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Path must be under res://.")

	var extensions: Array = params.get("extensions", SCRIPT_EXTENSIONS)
	var max_results := int(params.get("max_results", 500))
	max_results = clampi(max_results, 1, 5000)

	var scripts: Array[Dictionary] = []
	_collect_scripts(root_path, extensions, scripts, max_results)

	return {
		"path": root_path,
		"scripts": scripts,
		"count": scripts.size(),
	}


func read_script(params: Dictionary) -> Dictionary:
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	if script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'script_path' is required.")

	if not MCPPathUtils.is_inside_project(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.PERMISSION_DENIED, "Path outside project.")

	if not MCPPathUtils.file_exists(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Script not found: %s" % script_path)

	var content := MCPPathUtils.read_text_file(script_path)
	return {
		"script_path": script_path,
		"content": content,
		"size_bytes": content.length(),
	}


func get_open_scripts(_params: Dictionary) -> Dictionary:
	# Godot 4.4+ API: EditorInterface.get_script_editor().get_open_scripts()
	var script_editor = _plugin.get_editor_interface().get_script_editor()
	var open_scripts: Array[Dictionary] = []
	for script in script_editor.get_open_scripts():
		if script:
			open_scripts.append({
				"path": script.resource_path,
				"class": script.get_class(),
			})
	return {"scripts": open_scripts, "count": open_scripts.size()}


func _collect_scripts(path: String, extensions: Array, scripts: Array, max_results: int) -> void:
	if scripts.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "" and scripts.size() < max_results:
		if MCPPathUtils.should_skip_dir(entry_name):
			entry_name = dir.get_next()
			continue

		var child_path := path.path_join(entry_name)
		if dir.current_is_dir():
			_collect_scripts(child_path, extensions, scripts, max_results)
		else:
			for ext in extensions:
				var e := str(ext).strip_edges().to_lower().trim_prefix(".")
				if entry_name.to_lower().ends_with("." + e):
					scripts.append({"path": child_path, "name": entry_name})
					break
		entry_name = dir.get_next()
	dir.list_dir_end()


func create_script(params: Dictionary) -> Dictionary:
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	if script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'script_path' is required.")
	if not script_path.ends_with(".gd") and not script_path.ends_with(".cs"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Only .gd and .cs supported for create_script.")
	if not MCPPathUtils.is_inside_project(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.PERMISSION_DENIED, "Path outside project.")
	if MCPPathUtils.file_exists(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Script exists: %s" % script_path)

	var content := str(params.get("content", ""))
	if content.is_empty():
		var base := str(params.get("extends_class", "Node"))
		content = DEFAULT_GDSCRIPT_TEMPLATE % base

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create Script: %s" % script_path.get_file())
	ur.add_do_method(self, "_write_script_file", script_path, content)
	ur.add_undo_method(self, "_delete_script_file", script_path)
	ur.commit_action()

	if bool(params.get("attach_to_node", false)):
		var node_path := str(params.get("node_path", ""))
		if not node_path.is_empty():
			var attach_result: Variant = attach_script({
				"node_path": node_path,
				"script_path": script_path,
			})
			if attach_result is Dictionary and attach_result.get("ok") == false:
				return attach_result

	return {"script_path": script_path, "created": true, "size_bytes": content.length()}


func edit_script(params: Dictionary) -> Dictionary:
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	if script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'script_path' is required.")
	if not MCPPathUtils.file_exists(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Script not found: %s" % script_path)

	if not params.has("content"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'content' is required.")

	var new_content := str(params["content"])
	var old_content := MCPPathUtils.read_text_file(script_path)

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Edit Script: %s" % script_path.get_file())
	ur.add_do_method(self, "_write_script_file", script_path, new_content)
	ur.add_undo_method(self, "_write_script_file", script_path, old_content)
	ur.commit_action()

	_ctx.iface().get_resource_filesystem().update_file(script_path)

	return {
		"script_path": script_path,
		"size_bytes": new_content.length(),
		"previous_size_bytes": old_content.length(),
	}


func attach_script(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	if node_path.is_empty() or script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' and 'script_path' are required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)
	if not MCPPathUtils.file_exists(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Script not found: %s" % script_path)

	var script: Script = load(script_path)
	if script == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCRIPT_ERROR, "Failed to load script.")

	var old_script = node.get_script()
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Attach Script")
	ur.add_do_property(node, "script", script)
	ur.add_undo_property(node, "script", old_script)
	ur.commit_action()

	return {
		"node_path": str(node.get_path()),
		"script_path": script_path,
	}


func validate_script(params: Dictionary) -> Dictionary:
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	var source := str(params.get("content", ""))

	if source.is_empty():
		if script_path.is_empty():
			return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Provide 'script_path' or 'content'.")
		if not MCPPathUtils.file_exists(script_path):
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Script not found.")
		source = MCPPathUtils.read_text_file(script_path)

	if not script_path.ends_with(".gd"):
		return {
			"valid": true,
			"message": "Non-GDScript validation is limited to file existence.",
			"script_path": script_path,
		}

	var gd := GDScript.new()
	gd.source_code = source
	var err := gd.reload()
	return {
		"valid": err == OK,
		"error_code": err,
		"script_path": script_path,
	}


func search_in_files(params: Dictionary) -> Dictionary:
	var query := str(params.get("query", "")).strip_edges()
	if query.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'query' is required.")

	var root_path := MCPPathUtils.normalize_res_path(str(params.get("path", "res://")))
	var case_sensitive := bool(params.get("case_sensitive", false))
	var max_results := clampi(int(params.get("max_results", 100)), 1, 1000)
	var extensions: Array = params.get("extensions", ["gd", "tscn", "cs"])

	var matches: Array[Dictionary] = []
	_search_content_dir(root_path, query, extensions, case_sensitive, matches, max_results)

	return {
		"query": query,
		"path": root_path,
		"matches": matches,
		"count": matches.size(),
	}


func _write_script_file(path: String, content: String) -> void:
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()


func _delete_script_file(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)


func _search_content_dir(
	path: String,
	query: String,
	extensions: Array,
	case_sensitive: bool,
	matches: Array,
	max_results: int
) -> void:
	if matches.size() >= max_results:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and matches.size() < max_results:
		if MCPPathUtils.should_skip_dir(entry):
			entry = dir.get_next()
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_search_content_dir(child, query, extensions, case_sensitive, matches, max_results)
		else:
			if _has_allowed_extension(entry, extensions):
				var text := MCPPathUtils.read_text_file(child)
				if text.is_empty():
					entry = dir.get_next()
					continue
				var haystack := text if case_sensitive else text.to_lower()
				var needle := query if case_sensitive else query.to_lower()
				var idx := haystack.find(needle)
				if idx >= 0:
					var line := haystack.substr(0, idx).split("\n").size()
					matches.append({
						"path": child,
						"line": line,
						"preview": _line_at(text, line),
					})
		entry = dir.get_next()
	dir.list_dir_end()


func _has_allowed_extension(filename: String, extensions: Array) -> bool:
	if extensions.is_empty():
		return true
	for ext in extensions:
		var e := str(ext).strip_edges().to_lower().trim_prefix(".")
		if filename.to_lower().ends_with("." + e):
			return true
	return false


func _line_at(text: String, line_no: int) -> String:
	var lines := text.split("\n")
	if line_no <= 0 or line_no > lines.size():
		return ""
	return lines[line_no - 1].strip_edges()
