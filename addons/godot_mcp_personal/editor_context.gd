## Shared editor context: edited scene, node lookup, undo/redo.
## Godot 4.4+ API: EditorPlugin.get_undo_redo(), EditorInterface
class_name MCPEditorContext
extends RefCounted

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func undo_redo() -> EditorUndoRedoManager:
	return _plugin.get_undo_redo()


func iface() -> EditorInterface:
	return _plugin.get_editor_interface()


func edited_root() -> Node:
	return iface().get_edited_scene_root()


func require_edited_root() -> Variant:
	var root := edited_root()
	if root == null:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"No scene is open in the editor.",
			"Use open_scene or create_scene first."
		)
	return root


func resolve_node(node_path: String) -> Node:
	var root := edited_root()
	if root == null:
		return null
	var p := node_path.strip_edges()
	if p.is_empty() or p == "." or p == "root":
		return root
	if p.begins_with("/"):
		return root.get_node_or_null(p)
	return root.get_node_or_null(NodePath(p))


func resolve_parent(parent_path: String) -> Node:
	var p := parent_path.strip_edges()
	if p.is_empty() or p == "." or p == "root":
		return edited_root()
	return resolve_node(p)


func is_valid_node_type(type_name: String) -> bool:
	if not ClassDB.class_exists(type_name):
		return false
	return ClassDB.is_parent_class(type_name, "Node")


func instantiate_node(type_name: String) -> Node:
	if not is_valid_node_type(type_name):
		return null
	return ClassDB.instantiate(type_name) as Node


func node_path_relative(node: Node) -> String:
	var root := edited_root()
	if root == null or node == null:
		return str(node.get_path()) if node else ""
	if node == root:
		return "."
	return str(root.get_path_to(node))


func node_path_relative_to(node: Node, scene_root: Node) -> String:
	if scene_root == null or node == null:
		return str(node.get_path()) if node else ""
	if node == scene_root:
		return "."
	return str(scene_root.get_path_to(node))
