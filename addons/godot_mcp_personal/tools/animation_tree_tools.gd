## Phase 7 AnimationTree tools.
class_name MCPAnimationTreeTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func create_animation_tree(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var parent_path := str(params.get("parent_path", "."))
	var node_name := str(params.get("node_name", "AnimationTree"))
	var anim_player_path := str(params.get("anim_player_path", "")).strip_edges()
	var use_state_machine := bool(params.get("use_state_machine", true))

	var parent := _ctx.resolve_parent(parent_path)
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found: %s" % parent_path)

	var tree := AnimationTree.new()
	tree.name = node_name
	if use_state_machine:
		tree.tree_root = AnimationNodeStateMachine.new()
	tree.active = false

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create AnimationTree: %s" % node_name)
	ur.add_do_method(parent, "add_child", tree)
	ur.add_do_method(tree, "set_owner", edited_root)
	if not anim_player_path.is_empty():
		ur.add_do_method(tree, "set", "anim_player", NodePath(anim_player_path))
	ur.add_undo_method(parent, "remove_child", tree)
	ur.add_undo_method(tree, "queue_free")
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(tree),
		"name": tree.name,
		"anim_player": str(tree.anim_player),
		"tree_root_type": tree.tree_root.get_class() if tree.tree_root else "",
	}


func get_animation_tree_structure(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var root := tree.tree_root
	var structure: Dictionary = {
		"node_path": _ctx.node_path_relative(tree),
		"active": tree.active,
		"anim_player": str(tree.anim_player),
		"tree_root_type": root.get_class() if root else "",
	}

	if root is AnimationNodeStateMachine:
		var sm := root as AnimationNodeStateMachine
		var states: Array[String] = []
		var transitions: Array[Dictionary] = []
		# Godot 4.7+ API: get_node_list() replaces removed get_state_count()/get_state_name().
		for state_name in sm.get_node_list():
			states.append(str(state_name))
		for i in range(sm.get_transition_count()):
			var from_name := str(sm.get_transition_from(i))
			var to_name := str(sm.get_transition_to(i))
			transitions.append({
				"from": from_name,
				"to": to_name,
				"from_position": _vec2_dict(sm.get_node_position(StringName(from_name))),
				"to_position": _vec2_dict(sm.get_node_position(StringName(to_name))),
			})
		structure["states"] = states
		structure["transitions"] = transitions

	var parameters: Array[Dictionary] = []
	for info in tree.get_property_list():
		var name := str(info.get("name", ""))
		if name.begins_with("parameters/"):
			parameters.append({
				"name": name,
				"value": str(tree.get(name)),
			})
	structure["parameters"] = parameters

	return structure


func _resolve_animation_tree(params: Dictionary) -> AnimationTree:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return null
	var node := _ctx.resolve_node(node_path)
	if node is AnimationTree:
		return node as AnimationTree
	return null


func _vec2_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}
