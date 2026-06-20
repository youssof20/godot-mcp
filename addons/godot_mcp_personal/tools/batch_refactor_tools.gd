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


func find_nodes_by_type(params: Dictionary) -> Dictionary:
	var type_name := str(params.get("type", "")).strip_edges()
	if type_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'type' is required.")

	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")).strip_edges())
	var max_results := clampi(int(params.get("max_results", 100)), 1, 1000)
	var use_runtime := bool(params.get("runtime", false))

	var root: Node = null
	var cleanup := false
	if use_runtime:
		var runtime := MCPRuntimeHelper.new()
		runtime.setup(_ctx)
		root = runtime.find_runtime_root()
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")
	elif scene_path.is_empty():
		root = _ctx.edited_root()
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No edited scene; pass scene_path.")
	else:
		if not MCPPathUtils.file_exists(scene_path):
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)
		var packed: PackedScene = load(scene_path)
		if packed == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to load scene.")
		root = packed.instantiate()
		cleanup = true

	var matches: Array[Dictionary] = []
	_find_type_recursive(root, type_name, root, matches, max_results)

	if cleanup and root:
		root.free()

	return {"matches": matches, "count": matches.size(), "type": type_name}


func find_signal_connections(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")).strip_edges())
	var node_filter := str(params.get("node_path", "")).strip_edges()
	var signal_filter := str(params.get("signal", "")).strip_edges()
	var max_results := clampi(int(params.get("max_results", 200)), 1, 2000)

	var root: Node = null
	var cleanup := false
	if scene_path.is_empty():
		root = _ctx.edited_root()
		if root == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No edited scene; pass scene_path.")
	else:
		if not MCPPathUtils.file_exists(scene_path):
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found.")
		var packed: PackedScene = load(scene_path)
		if packed == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to load scene.")
		root = packed.instantiate()
		cleanup = true

	var origin := root
	if not node_filter.is_empty():
		origin = root.get_node_or_null(NodePath(node_filter)) if not node_filter.begins_with("/") else root.get_node_or_null(node_filter)
		if origin == null:
			if cleanup:
				root.free()
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_filter)

	var connections: Array[Dictionary] = []
	_collect_signal_connections(origin, root, signal_filter, connections, max_results)

	if cleanup and root:
		root.free()

	return {"connections": connections, "count": connections.size()}


func batch_set_property(params: Dictionary) -> Dictionary:
	var changes: Array = params.get("changes", [])
	if changes.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'changes' array required.")

	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Batch Set Properties")
	var applied: Array[Dictionary] = []

	for change in changes:
		if typeof(change) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = change
		var node_path := str(d.get("node_path", "")).strip_edges()
		var property := str(d.get("property", "")).strip_edges()
		if node_path.is_empty() or property.is_empty() or not d.has("value"):
			continue

		var node := _ctx.resolve_node(node_path)
		if node == null:
			applied.append({"node_path": node_path, "error": "not_found"})
			continue

		var new_value := MCPTypeParser.coerce_for_property(node, property, d["value"])
		var old_value = node.get(property)
		ur.add_do_method(node, "set", property, new_value)
		ur.add_undo_method(node, "set", property, old_value)
		applied.append({
			"node_path": _ctx.node_path_relative(node),
			"property": property,
			"old_value": str(old_value),
			"new_value": str(new_value),
		})

	if applied.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "No valid changes in 'changes' array.")

	ur.commit_action()
	return {"applied": applied, "count": applied.size()}


func cross_scene_set_property(params: Dictionary) -> Dictionary:
	var scene_path := MCPPathUtils.normalize_res_path(str(params.get("scene_path", "")).strip_edges())
	var node_path := str(params.get("node_path", "")).strip_edges()
	var property := str(params.get("property", "")).strip_edges()
	if scene_path.is_empty() or node_path.is_empty() or property.is_empty() or not params.has("value"):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"scene_path, node_path, property, and value are required.",
		)

	if not MCPPathUtils.file_exists(scene_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found: %s" % scene_path)

	var edited := _ctx.edited_root()
	if edited and edited.scene_file_path == scene_path:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"Scene is currently open in the editor.",
			"Use update_property on the edited scene or close it first.",
		)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to load scene.")

	var root := packed.instantiate()
	var node := root.get_node_or_null(NodePath(node_path)) if not node_path.begins_with("/") else root.get_node_or_null(node_path)
	if node == null:
		root.free()
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found in scene: %s" % node_path)

	var new_value := MCPTypeParser.coerce_for_property(node, property, params["value"])
	var old_value = node.get(property)
	node.set(property, new_value)

	var save := bool(params.get("save", true))
	var saved := false
	if save:
		var out := PackedScene.new()
		var pack_err := out.pack(root)
		if pack_err != OK:
			root.free()
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to pack scene (error %d)" % pack_err)
		var save_err := ResourceSaver.save(out, scene_path)
		if save_err != OK:
			root.free()
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to save scene (error %d)" % save_err)
		saved = true

	root.free()
	return {
		"scene_path": scene_path,
		"node_path": node_path,
		"property": property,
		"old_value": str(old_value),
		"new_value": str(new_value),
		"saved": saved,
	}


func _find_type_recursive(node: Node, type_name: String, root: Node, out: Array, max_count: int) -> void:
	if out.size() >= max_count:
		return
	if node.is_class(type_name) or node.get_class() == type_name:
		out.append({
			"path": _ctx.node_path_relative_to(node, root),
			"name": node.name,
			"type": node.get_class(),
		})
	for child in node.get_children():
		_find_type_recursive(child, type_name, root, out, max_count)


func _collect_signal_connections(
	node: Node,
	scene_root: Node,
	signal_filter: String,
	out: Array,
	max_count: int
) -> void:
	if out.size() >= max_count:
		return

	for sig in node.get_signal_list():
		var sig_name := str(sig.get("name", ""))
		if not signal_filter.is_empty() and sig_name != signal_filter:
			continue
		for conn in node.get_signal_connection_list(sig_name):
			var callable_obj: Callable = conn.get("callable", Callable())
			var target_obj: Object = callable_obj.get_object()
			var target_path := ""
			if target_obj is Node:
				target_path = _ctx.node_path_relative_to(target_obj as Node, scene_root)
			out.append({
				"source_path": _ctx.node_path_relative_to(node, scene_root),
				"signal": sig_name,
				"target_path": target_path,
				"method": str(callable_obj.get_method()),
				"flags": conn.get("flags", 0),
			})

	for child in node.get_children():
		_collect_signal_connections(child, scene_root, signal_filter, out, max_count)
