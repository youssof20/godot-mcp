## Locates the running game scene root during editor play mode.
## Godot 4.7+: EditorInterface.is_playing_scene(), get_playing_scene()
class_name MCPRuntimeHelper
extends RefCounted

var _ctx: MCPEditorContext


func setup(ctx: MCPEditorContext) -> void:
	_ctx = ctx


func is_playing() -> bool:
	return _ctx.iface().is_playing_scene()


func playing_scene_path() -> String:
	return _ctx.iface().get_playing_scene()


func find_runtime_root() -> Node:
	if not is_playing():
		return null

	var playing_path := playing_scene_path()
	var edited := _ctx.edited_root()

	# Strategy 1: node in editor tree whose scene_file_path matches the playing scene
	# but is not the edited-scene dock root (embedded runtime instance).
	if not playing_path.is_empty():
		var match := _find_by_scene_path(_ctx.iface().get_base_control(), playing_path, edited)
		if match != null:
			return match

	# Strategy 2: deepest SubViewport child tree that looks like a game root
	var viewport_root := _find_subviewport_game_root(_ctx.iface().get_base_control())
	if viewport_root != null:
		return viewport_root

	return null


func resolve_runtime_node(node_path: String) -> Node:
	var root := find_runtime_root()
	if root == null:
		return null
	var p := node_path.strip_edges()
	if p.is_empty() or p == "." or p == "root":
		return root
	if p.begins_with("/"):
		return root.get_node_or_null(p)
	return root.get_node_or_null(NodePath(p))


func node_to_tree(node: Node, depth: int, max_depth: int, scene_root: Node) -> Dictionary:
	var entry: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": _ctx.node_path_relative_to(node, scene_root),
	}
	if node.get_script():
		var script: Script = node.get_script()
		entry["script"] = script.resource_path if script.resource_path else script.get_class()
	if depth >= max_depth:
		entry["truncated"] = true
		entry["child_count"] = node.get_child_count()
		return entry
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(node_to_tree(child, depth + 1, max_depth, scene_root))
	entry["children"] = children
	return entry


func _find_by_scene_path(node: Node, scene_path: String, exclude: Node) -> Node:
	if node != exclude and node.scene_file_path == scene_path:
		return node
	for child in node.get_children():
		var found := _find_by_scene_path(child, scene_path, exclude)
		if found != null:
			return found
	return null


func _find_subviewport_game_root(node: Node) -> Node:
	if node is SubViewport:
		for child in node.get_children():
			if child is Node2D or child is Node3D or child is Control:
				return child
	for child in node.get_children():
		var found := _find_subviewport_game_root(child)
		if found != null:
			return found
	return null
