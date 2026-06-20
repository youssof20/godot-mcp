## Phase 9 project analysis tools.
class_name MCPAnalysisTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func analyze_scene_complexity(params: Dictionary) -> Dictionary:
	var root: Node = null
	var scene_path := str(params.get("scene_path", "")).strip_edges()
	if scene_path.is_empty():
		root = _ctx.edited_root()
	else:
		scene_path = MCPPathUtils.normalize_res_path(scene_path)
		var packed: PackedScene = load(scene_path)
		if packed == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Scene not found.")
		root = packed.instantiate()

	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No scene to analyze.")

	var stats := _analyze_node(root, 0, {})
	if not scene_path.is_empty():
		root.free()

	return {
		"scene_path": scene_path if not scene_path.is_empty() else (root.scene_file_path if root else ""),
		"node_count": stats.get("node_count", 0),
		"max_depth": stats.get("max_depth", 0),
		"type_counts": stats.get("type_counts", {}),
		"scripted_nodes": stats.get("scripted_nodes", 0),
	}


func analyze_signal_flow(params: Dictionary) -> Dictionary:
	var root := _ctx.edited_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No edited scene.")

	var connections: Array[Dictionary] = []
	_collect_signals(root, root, connections)
	return {"connections": connections, "count": connections.size()}


func find_unused_resources(params: Dictionary) -> Dictionary:
	var root_path := MCPPathUtils.normalize_res_path(str(params.get("path", "res://")))
	var limit := clampi(int(params.get("limit", 100)), 1, 1000)
	var extensions: Array = params.get("extensions", ["tres", "png", "wav", "ogg", "gdshader"])

	var all_files: Array[String] = []
	var referenced: Dictionary = {}
	_collect_files(root_path, extensions, all_files, limit * 10)
	_scan_references(root_path, referenced)

	var unused: Array[String] = []
	for f in all_files:
		if unused.size() >= limit:
			break
		if not referenced.has(f):
			unused.append(f)

	return {"unused": unused, "count": unused.size(), "scanned_files": all_files.size()}


func get_project_statistics(_params: Dictionary) -> Dictionary:
	var counts := {"gd": 0, "tscn": 0, "tres": 0, "png": 0, "cs": 0, "gdshader": 0, "other": 0}
	_count_by_extension("res://", counts)
	var total := 0
	for k in counts.keys():
		total += int(counts[k])
	return {"file_counts": counts, "total_files": total}


func audit_project_health(_params: Dictionary) -> Dictionary:
	var complexity := analyze_scene_complexity({})
	var stats := get_project_statistics({})
	var unused := find_unused_resources({"limit": 20})

	var issues: Array[Dictionary] = []
	if int(complexity.get("node_count", 0)) > 500:
		issues.append({"severity": "warning", "message": "Edited scene has high node count."})

	return {
		"scene_complexity": complexity,
		"project_statistics": stats,
		"sample_unused_resources": unused.get("unused", []),
		"issues": issues,
		"health_score": maxi(0, 100 - issues.size() * 10),
	}


func _analyze_node(node: Node, depth: int, stats: Dictionary) -> Dictionary:
	stats["node_count"] = int(stats.get("node_count", 0)) + 1
	stats["max_depth"] = maxi(int(stats.get("max_depth", 0)), depth)
	if node.get_script() != null:
		stats["scripted_nodes"] = int(stats.get("scripted_nodes", 0)) + 1
	var type_counts: Dictionary = stats.get("type_counts", {})
	var cls := node.get_class()
	type_counts[cls] = int(type_counts.get(cls, 0)) + 1
	stats["type_counts"] = type_counts
	for child in node.get_children():
		_analyze_node(child, depth + 1, stats)
	return stats


func _collect_signals(node: Node, root: Node, out: Array) -> void:
	for sig in node.get_signal_list():
		var sig_name := str(sig.get("name", ""))
		for conn in node.get_signal_connection_list(sig_name):
			out.append({
				"from_node": _ctx.node_path_relative_to(node, root),
				"signal": sig_name,
				"to_node": str(conn.get("callable", "")),
			})
	for child in node.get_children():
		_collect_signals(child, root, out)


func _collect_files(path: String, extensions: Array, files: Array, max_files: int) -> void:
	if files.size() >= max_files:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and files.size() < max_files:
		if MCPPathUtils.should_skip_dir(entry):
			entry = dir.get_next()
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_collect_files(child, extensions, files, max_files)
		else:
			for ext in extensions:
				if entry.to_lower().ends_with("." + str(ext).trim_prefix(".")):
					files.append(child)
					break
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_references(path: String, referenced: Dictionary) -> void:
	var text_ext := ["gd", "tscn", "tres", "import", "cfg", "godot"]
	var files: Array[String] = []
	_collect_files(path, text_ext, files, 5000)
	for f in files:
		var content := MCPPathUtils.read_text_file(f)
		if content.is_empty():
			continue
		for other in files:
			if other == f:
				continue
			var short := other.get_file()
			if content.find(other) >= 0 or content.find(short) >= 0:
				referenced[other] = true


func _count_by_extension(path: String, counts: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if MCPPathUtils.should_skip_dir(entry):
			entry = dir.get_next()
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_count_by_extension(child, counts)
		else:
			var ext := entry.get_extension().to_lower()
			if counts.has(ext):
				counts[ext] = int(counts[ext]) + 1
			else:
				counts["other"] = int(counts["other"]) + 1
		entry = dir.get_next()
	dir.list_dir_end()
