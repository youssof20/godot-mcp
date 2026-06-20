## Phase 4 batch analysis and reference search tools.
class_name MCPBatchRefactorTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func find_node_references(params: Dictionary) -> Dictionary:
	var node_name := str(params.get("node_name", "")).strip_edges()
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "res://")))
	if node_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_name' is required.")

	var patterns: Array[String] = [
		'node name="%s"' % node_name,
		'parent="%s"' % node_name,
		'NodePath("%s")' % node_name,
		"get_node(\"%s\")" % node_name,
	]

	return _search_patterns(scene_path, patterns, params)


func find_script_references(params: Dictionary) -> Dictionary:
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("script_path", "")))
	if script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'script_path' is required.")

	var patterns: Array[String] = [
		script_path,
		script_path.get_file(),
	]
	if script_path.ends_with(".gd"):
		patterns.append('path="%s"' % script_path)

	return _search_patterns("res://", patterns, params)


func find_resource_references(params: Dictionary) -> Dictionary:
	var resource_path := MCPPathUtils.normalize_res_path(str(params.get("resource_path", "")))
	if resource_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'resource_path' is required.")

	var patterns: Array[String] = [resource_path, resource_path.get_file()]
	var uid := ResourceUID.path_to_uid(resource_path)
	if uid.begins_with("uid://"):
		patterns.append(uid)

	return _search_patterns("res://", patterns, params)


func get_scene_dependencies(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")))
	if scene_path.is_empty():
		var root := _ctx.edited_root()
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No scene open; pass scene_path.")
		scene_path = root.scene_file_path
	if not MCPPathUtils.file_exists(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found.")

	var content := MCPPathUtils.read_text_file(scene_path)
	var deps: Array[String] = []
	for line in content.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("[ext_resource") or trimmed.begins_with('[ext_resource'):
			var path_idx := trimmed.find('path="')
			if path_idx >= 0:
				var start := path_idx + 6
				var end := trimmed.find('"', start)
				if end > start:
					deps.append(trimmed.substr(start, end - start))
		if trimmed.begins_with("[node") and 'instance=' in trimmed:
			var inst_idx := trimmed.find('ExtResource(')
			if inst_idx >= 0:
				deps.append(trimmed.strip_edges())

	return {
		"scene_path": scene_path,
		"dependencies": deps,
		"count": deps.size(),
	}


func detect_circular_dependencies(params: Dictionary) -> Dictionary:
	var root_path := MCPPathUtils.normalize_res_path(str(params.get("path", "res://")))
	var max_scenes := clampi(int(params.get("max_scenes", 200)), 1, 2000)

	var scene_files: Array[String] = []
	_collect_scenes(root_path, scene_files, max_scenes)

	var graph: Dictionary = {}
	for scene in scene_files:
		graph[scene] = _scene_deps(scene)

	var cycles: Array[Array] = []
	for scene in scene_files:
		var visited: Dictionary = {}
		var stack: Array[String] = []
		_find_cycles(scene, graph, visited, stack, cycles)

	return {
		"scenes_scanned": scene_files.size(),
		"cycles": cycles,
		"cycle_count": cycles.size(),
	}


func _search_patterns(root_path: String, patterns: Array[String], params: Dictionary) -> Dictionary:
	var max_results := clampi(int(params.get("max_results", 100)), 1, 1000)
	var extensions: Array = params.get("extensions", ["tscn", "gd", "tres", "scn"])
	var matches: Array[Dictionary] = []
	_search_patterns_dir(root_path, patterns, extensions, matches, max_results)
	return {"matches": matches, "count": matches.size(), "patterns": patterns}


func _search_patterns_dir(
	path: String,
	patterns: Array[String],
	extensions: Array,
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
			_search_patterns_dir(child, patterns, extensions, matches, max_results)
		else:
			var ok_ext := false
			for ext in extensions:
				if entry.to_lower().ends_with("." + str(ext).trim_prefix(".")):
					ok_ext = true
					break
			if not ok_ext:
				entry = dir.get_next()
				continue
			var text := MCPPathUtils.read_text_file(child)
			for pattern in patterns:
				if pattern.is_empty():
					continue
				if text.find(pattern) >= 0:
					matches.append({"path": child, "pattern": pattern})
					break
		entry = dir.get_next()
	dir.list_dir_end()


func _collect_scenes(path: String, out: Array[String], max_count: int) -> void:
	if out.size() >= max_count:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and out.size() < max_count:
		if MCPPathUtils.should_skip_dir(entry):
			entry = dir.get_next()
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_collect_scenes(child, out, max_count)
		elif entry.ends_with(".tscn") or entry.ends_with(".scn"):
			out.append(child)
		entry = dir.get_next()
	dir.list_dir_end()


func _scene_deps(scene_path: String) -> Array[String]:
	var result := get_scene_dependencies({"scene_path": scene_path})
	if result is Dictionary and result.get("ok") == false:
		return []
	return Array(result.get("dependencies", []))


func _find_cycles(
	node: String,
	graph: Dictionary,
	visited: Dictionary,
	stack: Array[String],
	cycles: Array
) -> void:
	if node in stack:
		var cycle: Array[String] = []
		var start_idx := stack.find(node)
		for i in range(start_idx, stack.size()):
			cycle.append(stack[i])
		cycle.append(node)
		cycles.append(cycle)
		return
	if visited.has(node):
		return
	visited[node] = true
	stack.append(node)
	for dep in graph.get(node, []):
		var dep_path := str(dep)
		if dep_path.begins_with("res://"):
			_find_cycles(dep_path, graph, visited, stack, cycles)
	stack.pop_back()
