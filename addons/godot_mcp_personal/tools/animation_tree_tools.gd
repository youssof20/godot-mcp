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


func set_tree_parameter(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var param_name := str(params.get("parameter", "")).strip_edges()
	if param_name.is_empty() or not params.has("value"):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"'parameter' and 'value' are required.",
			"Use names like 'parameters/conditions/idle' or 'parameters/TimeScale/scale'.",
		)

	if not param_name.begins_with("parameters/"):
		param_name = "parameters/" + param_name

	if not tree.has_method("set") and not param_name in tree:
		pass

	var new_value := MCPTypeParser.parse_value(params["value"])
	var old_value = tree.get(param_name)
	tree.set(param_name, new_value)
	_notify_tree_changed(tree)

	return {
		"node_path": _ctx.node_path_relative(tree),
		"parameter": param_name,
		"old_value": str(old_value),
		"new_value": str(tree.get(param_name)),
	}


func add_state_machine_state(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var sm := tree.tree_root
	if not sm is AnimationNodeStateMachine:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"AnimationTree tree_root is not an AnimationNodeStateMachine.",
			"Create the tree with use_state_machine=true or set tree_root manually.",
		)

	var state_name := str(params.get("state_name", "")).strip_edges()
	if state_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'state_name' is required.")

	var sm_node := sm as AnimationNodeStateMachine
	if sm_node.has_node(StringName(state_name)):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "State already exists: %s" % state_name)

	var node_type := str(params.get("node_type", "AnimationNodeAnimation")).strip_edges()
	var anim_node := _instantiate_animation_node(node_type)
	if anim_node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_NODE_TYPE, "Unsupported node_type: %s" % node_type)

	if anim_node is AnimationNodeAnimation:
		var animation := str(params.get("animation", "")).strip_edges()
		if not animation.is_empty():
			(anim_node as AnimationNodeAnimation).animation = animation

	var pos := _parse_position(params.get("position", {"x": 0, "y": 0}))
	sm_node.add_node(StringName(state_name), anim_node, pos)
	_notify_tree_changed(tree)

	return {
		"node_path": _ctx.node_path_relative(tree),
		"state_name": state_name,
		"node_type": anim_node.get_class(),
		"position": _vec2_dict(pos),
	}


func remove_state_machine_state(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var sm := tree.tree_root
	if not sm is AnimationNodeStateMachine:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "tree_root is not an AnimationNodeStateMachine.")

	var state_name := str(params.get("state_name", "")).strip_edges()
	if state_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'state_name' is required.")

	var sm_node := sm as AnimationNodeStateMachine
	if not sm_node.has_node(StringName(state_name)):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "State not found: %s" % state_name)

	sm_node.remove_node(StringName(state_name))
	_notify_tree_changed(tree)

	return {
		"node_path": _ctx.node_path_relative(tree),
		"removed_state": state_name,
	}


func add_state_machine_transition(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var sm := tree.tree_root
	if not sm is AnimationNodeStateMachine:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "tree_root is not an AnimationNodeStateMachine.")

	var from_state := str(params.get("from_state", "")).strip_edges()
	var to_state := str(params.get("to_state", "")).strip_edges()
	if from_state.is_empty() or to_state.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'from_state' and 'to_state' are required.")

	var sm_node := sm as AnimationNodeStateMachine
	if not sm_node.has_node(StringName(from_state)):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "From state not found: %s" % from_state)
	if not sm_node.has_node(StringName(to_state)):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "To state not found: %s" % to_state)
	if sm_node.has_transition(StringName(from_state), StringName(to_state)):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Transition already exists.")

	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = float(params.get("xfade_time", 0.2))
	if params.has("advance_condition"):
		transition.advance_condition = str(params.get("advance_condition", ""))
	if params.has("switch_mode"):
		transition.switch_mode = int(params.get("switch_mode", transition.switch_mode))

	sm_node.add_transition(StringName(from_state), StringName(to_state), transition)
	_notify_tree_changed(tree)

	return {
		"node_path": _ctx.node_path_relative(tree),
		"from_state": from_state,
		"to_state": to_state,
		"xfade_time": transition.xfade_time,
	}


func remove_state_machine_transition(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var sm := tree.tree_root
	if not sm is AnimationNodeStateMachine:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "tree_root is not an AnimationNodeStateMachine.")

	var from_state := str(params.get("from_state", "")).strip_edges()
	var to_state := str(params.get("to_state", "")).strip_edges()
	if from_state.is_empty() or to_state.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'from_state' and 'to_state' are required.")

	var sm_node := sm as AnimationNodeStateMachine
	if not sm_node.has_transition(StringName(from_state), StringName(to_state)):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Transition not found.")

	sm_node.remove_transition(StringName(from_state), StringName(to_state))
	_notify_tree_changed(tree)

	return {
		"node_path": _ctx.node_path_relative(tree),
		"from_state": from_state,
		"to_state": to_state,
	}


func set_blend_tree_node(params: Dictionary) -> Dictionary:
	var tree := _resolve_animation_tree(params)
	if tree == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationTree not found.")

	var blend := tree.tree_root
	if not blend is AnimationNodeBlendTree:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"AnimationTree tree_root is not an AnimationNodeBlendTree.",
			"Set tree_root to AnimationNodeBlendTree or use state machine tools.",
		)

	var blend_tree := blend as AnimationNodeBlendTree
	var action := str(params.get("action", "add")).strip_edges().to_lower()

	match action:
		"add":
			var node_name := str(params.get("node_name", "")).strip_edges()
			if node_name.is_empty():
				return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_name' is required for add.")
			if blend_tree.has_node(StringName(node_name)):
				return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Blend node already exists: %s" % node_name)

			var node_type := str(params.get("node_type", "AnimationNodeAnimation")).strip_edges()
			var anim_node := _instantiate_animation_node(node_type)
			if anim_node == null:
				return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_NODE_TYPE, "Unsupported node_type: %s" % node_type)

			if anim_node is AnimationNodeAnimation:
				var animation := str(params.get("animation", "")).strip_edges()
				if not animation.is_empty():
					(anim_node as AnimationNodeAnimation).animation = animation

			var pos := _parse_position(params.get("position", {"x": 0, "y": 0}))
			blend_tree.add_node(StringName(node_name), anim_node, pos)
			_notify_tree_changed(tree)
			return {
				"node_path": _ctx.node_path_relative(tree),
				"action": "add",
				"node_name": node_name,
				"node_type": anim_node.get_class(),
			}
		"remove":
			var remove_name := str(params.get("node_name", "")).strip_edges()
			if remove_name.is_empty():
				return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_name' is required for remove.")
			if not blend_tree.has_node(StringName(remove_name)):
				return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Blend node not found: %s" % remove_name)
			blend_tree.remove_node(StringName(remove_name))
			_notify_tree_changed(tree)
			return {"node_path": _ctx.node_path_relative(tree), "action": "remove", "node_name": remove_name}
		"connect":
			var input_node := str(params.get("input_node", params.get("to_node", ""))).strip_edges()
			var output_node := str(params.get("output_node", params.get("from_node", ""))).strip_edges()
			if input_node.is_empty() or output_node.is_empty():
				return MCPErrorCodes.make_error(
					MCPErrorCodes.INVALID_PARAMS,
					"'input_node' and 'output_node' are required (aliases: to_node, from_node).",
				)
			var input_index := int(params.get("input_index", params.get("to_port", 0)))
			# Godot 4.7 API: connect_node(input_node, input_index, output_node)
			var err := blend_tree.connect_node(StringName(input_node), input_index, StringName(output_node))
			if err != AnimationNodeBlendTree.CONNECTION_OK:
				return MCPErrorCodes.make_error(
					MCPErrorCodes.GODOT_API_ERROR,
					"connect_node failed with code %d." % err,
				)
			_notify_tree_changed(tree)
			return {
				"node_path": _ctx.node_path_relative(tree),
				"action": "connect",
				"input_node": input_node,
				"output_node": output_node,
				"input_index": input_index,
			}
		"set_parameter":
			var param_name := str(params.get("parameter", "")).strip_edges()
			if param_name.is_empty() or not params.has("value"):
				return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'parameter' and 'value' required.")
			if not param_name.begins_with("parameters/"):
				param_name = "parameters/" + param_name
			var blend_value := MCPTypeParser.parse_value(params["value"])
			tree.set(param_name, blend_value)
			_notify_tree_changed(tree)
			return {
				"node_path": _ctx.node_path_relative(tree),
				"action": "set_parameter",
				"parameter": param_name,
				"value": str(tree.get(param_name)),
			}
		_:
			return MCPErrorCodes.make_error(
				MCPErrorCodes.INVALID_PARAMS,
				"Unknown action: %s" % action,
				"Use add, remove, connect, or set_parameter.",
			)


func _resolve_state_machine(tree: AnimationTree) -> AnimationNodeStateMachine:
	var root := tree.tree_root
	if root is AnimationNodeStateMachine:
		return root as AnimationNodeStateMachine
	return null


func _instantiate_animation_node(type_name: String) -> AnimationNode:
	if not ClassDB.class_exists(type_name):
		return null
	if not ClassDB.is_parent_class(type_name, "AnimationNode"):
		return null
	return ClassDB.instantiate(type_name) as AnimationNode


func _parse_position(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
	return Vector2.ZERO


func _notify_tree_changed(tree: AnimationTree) -> void:
	var root := tree.tree_root
	if root != null and root.has_signal("tree_changed"):
		root.tree_changed.emit()
	tree.notify_property_list_changed()


func _vec2_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}
