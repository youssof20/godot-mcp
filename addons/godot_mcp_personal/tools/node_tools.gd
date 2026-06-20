## Phase 2+ node tools.
class_name MCPNodeTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func get_node_properties(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var scene_path := str(params.get("scene_path", "")).strip_edges()
	var root: Node = null
	var cleanup := false

	if scene_path.is_empty():
		root = _plugin.get_editor_interface().get_edited_scene_root()
		if root == null:
			return MCPErrorCodes.make_error(
				MCPErrorCodes.NOT_FOUND,
				"No edited scene open.",
				"Open a scene or pass scene_path."
			)
	else:
		scene_path = MCPPathUtils.normalize_res_path(scene_path)
		var packed: PackedScene = load(scene_path)
		if packed == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Failed to load scene.")
		root = packed.instantiate()
		cleanup = true

	var node: Node = null
	if node_path == "." or node_path == "/":
		node = root
	else:
		if node_path.begins_with("/"):
			node = root.get_node_or_null(node_path)
		else:
			node = root.get_node_or_null(NodePath(node_path))

	if node == null:
		if cleanup:
			root.free()
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"Node not found: %s" % node_path,
		)

	var requested: Array = params.get("properties", [])
	var include_groups := bool(params.get("include_groups", true))
	var include_signals := bool(params.get("include_signals", false))

	var props: Dictionary = {}
	if requested.is_empty():
		for info in node.get_property_list():
			var usage := int(info.get("usage", 0))
			if usage & PROPERTY_USAGE_EDITOR:
				var pname := str(info.get("name", ""))
				if not pname.is_empty():
					props[pname] = _serialize_value(node.get(pname))
	else:
		for prop_name in requested:
			var key := str(prop_name)
			props[key] = _serialize_value(node.get(key))

	var result: Dictionary = {
		"node_path": _ctx.node_path_relative(node),
		"name": node.name,
		"type": node.get_class(),
		"properties": props,
	}

	if include_groups:
		result["groups"] = node.get_groups()

	if include_signals:
		var signal_list: Array[Dictionary] = []
		for sig in node.get_signal_list():
			signal_list.append({
				"name": sig.get("name", ""),
				"args": sig.get("args", []),
			})
		result["signals"] = signal_list

	if cleanup:
		root.free()

	return result


func _serialize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Node:
				return {"type": "Node", "path": str(value.get_path())}
			if value is Resource:
				return {"type": "Resource", "path": value.resource_path, "class": value.get_class()}
			return {"type": "Object", "class": value.get_class()}
		TYPE_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_serialize_value(item))
			return arr
		TYPE_DICTIONARY:
			var dict: Dictionary = {}
			for k in value.keys():
				dict[str(k)] = _serialize_value(value[k])
			return dict
		_:
			return value


func add_node(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var node_type := str(params.get("node_type", "Node2D"))
	var node_name := str(params.get("node_name", node_type))
	var parent_path := str(params.get("parent_path", "."))

	var parent := _ctx.resolve_parent(parent_path)
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found: %s" % parent_path)

	if not _ctx.is_valid_node_type(node_type):
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_NODE_TYPE, "Unsupported type: %s" % node_type)

	var node := _ctx.instantiate_node(node_type)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to create node.")
	node.name = node_name

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Add Node: %s" % node_name)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", node)
	ur.add_undo_method(node, "queue_free")
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(node),
		"name": node.name,
		"type": node.get_class(),
		"parent_path": _ctx.node_path_relative(parent),
	}


func delete_node(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)

	var edited_root := _ctx.edited_root()
	if node == edited_root:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Cannot delete the scene root node.")

	var parent := node.get_parent()
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Node has no parent.")

	var idx := node.get_index()
	var saved_name := node.name
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Delete Node: %s" % saved_name)
	ur.add_do_method(parent, "remove_child", node)
	ur.add_undo_method(parent, "add_child", node)
	ur.add_undo_method(parent, "move_child", node, idx)
	ur.add_undo_method(node, "set_owner", edited_root)
	ur.add_do_reference(node)
	ur.commit_action()

	return {"deleted": true, "node_path": node_path, "name": saved_name}


func duplicate_node(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)

	var parent := node.get_parent()
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Node has no parent.")

	var dup := node.duplicate()
	if dup == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "duplicate() failed.")

	var edited_root := _ctx.edited_root()
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Duplicate Node: %s" % node.name)
	ur.add_do_method(parent, "add_child", dup)
	ur.add_do_method(dup, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", dup)
	ur.add_undo_method(dup, "queue_free")
	ur.commit_action()

	return {
		"source_path": _ctx.node_path_relative(node),
		"duplicate_path": _ctx.node_path_relative(dup),
		"name": dup.name,
		"type": dup.get_class(),
	}


func move_node(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var new_parent_path := str(params.get("new_parent_path", "")).strip_edges()
	if node_path.is_empty() or new_parent_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' and 'new_parent_path' are required.")

	var node := _ctx.resolve_node(node_path)
	var new_parent := _ctx.resolve_parent(new_parent_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)
	if new_parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "New parent not found: %s" % new_parent_path)

	var old_parent := node.get_parent()
	if old_parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.SCENE_ERROR, "Node has no parent.")
	if node == _ctx.edited_root():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Cannot reparent the scene root.")

	var old_index := node.get_index()
	var new_index := int(params.get("index", -1))
	var edited_root := _ctx.edited_root()

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Move Node: %s" % node.name)
	ur.add_do_method(self, "_reparent_node", node, new_parent, new_index, edited_root)
	ur.add_undo_method(self, "_reparent_node", node, old_parent, old_index, edited_root)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(node),
		"new_parent_path": _ctx.node_path_relative(new_parent),
	}


func rename_node(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var new_name := str(params.get("new_name", "")).strip_edges()
	if node_path.is_empty() or new_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' and 'new_name' are required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)

	var old_name := node.name
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Rename Node")
	ur.add_do_method(node, "set_name", new_name)
	ur.add_undo_method(node, "set_name", old_name)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(node),
		"old_name": old_name,
		"new_name": new_name,
	}


func update_property(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var property := str(params.get("property", "")).strip_edges()
	if node_path.is_empty() or property.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' and 'property' are required.")
	if not params.has("value"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'value' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)

	var new_value := MCPTypeParser.coerce_for_property(node, property, params["value"])
	var old_value = node.get(property)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Set %s.%s" % [node.name, property])
	ur.add_do_property(node, property, new_value)
	ur.add_undo_property(node, property, old_value)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(node),
		"property": property,
		"old_value": _serialize_value(old_value),
		"new_value": _serialize_value(new_value),
	}


func add_resource(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var property := str(params.get("property", "")).strip_edges()
	var resource_path := MCPPathUtils.normalize_res_path(str(params.get("resource_path", "")))
	if node_path.is_empty() or property.is_empty() or resource_path.is_empty():
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"'node_path', 'property', and 'resource_path' are required.",
		)

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)
	if not MCPPathUtils.file_exists(resource_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Resource not found: %s" % resource_path)

	var resource: Resource = load(resource_path)
	if resource == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_RESOURCE_TYPE, "Failed to load: %s" % resource_path)

	var old_value = node.get(property)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Assign %s" % property)
	ur.add_do_property(node, property, resource)
	ur.add_undo_property(node, property, old_value)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(node),
		"property": property,
		"resource_path": resource_path,
	}


func set_anchor_preset(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)
	if not node is Control:
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_NODE_TYPE, "Node is not a Control.")

	var control := node as Control
	var preset := MCPTypeParser.anchor_preset_from_param(params.get("preset", Control.PRESET_FULL_RECT))
	if preset < 0:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Invalid anchor preset.")

	var layout_before := _snapshot_control_layout(control)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Anchor Preset")
	ur.add_do_method(control, "set_anchors_and_offsets_preset", preset)
	ur.add_undo_method(self, "_apply_control_layout", control, layout_before)
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(control), "preset": preset}


func _snapshot_control_layout(control: Control) -> Dictionary:
	return {
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"offset_left": control.offset_left,
		"offset_top": control.offset_top,
		"offset_right": control.offset_right,
		"offset_bottom": control.offset_bottom,
	}


func _apply_control_layout(control: Control, layout: Dictionary) -> void:
	control.anchor_left = float(layout.get("anchor_left", 0))
	control.anchor_top = float(layout.get("anchor_top", 0))
	control.anchor_right = float(layout.get("anchor_right", 0))
	control.anchor_bottom = float(layout.get("anchor_bottom", 0))
	control.offset_left = float(layout.get("offset_left", 0))
	control.offset_top = float(layout.get("offset_top", 0))
	control.offset_right = float(layout.get("offset_right", 0))
	control.offset_bottom = float(layout.get("offset_bottom", 0))


func _reparent_node(node: Node, parent: Node, index: int, owner: Node) -> void:
	var current_parent := node.get_parent()
	if current_parent:
		current_parent.remove_child(node)
	parent.add_child(node)
	if index >= 0:
		parent.move_child(node, index)
	node.set_owner(owner)


func connect_signal(params: Dictionary) -> Dictionary:
	var source_path := str(params.get("source_path", "")).strip_edges()
	var signal_name := str(params.get("signal", "")).strip_edges()
	var target_path := str(params.get("target_path", "")).strip_edges()
	var method_name := str(params.get("method", "")).strip_edges()

	if source_path.is_empty() or signal_name.is_empty() or target_path.is_empty():
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"'source_path', 'signal', and 'target_path' are required.",
		)

	var source := _ctx.resolve_node(source_path)
	var target := _ctx.resolve_node(target_path)
	if source == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Source not found: %s" % source_path)
	if target == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Target not found: %s" % target_path)

	if not source.has_signal(signal_name):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Signal '%s' not found on source." % signal_name)

	if method_name.is_empty():
		method_name = "_on_%s" % signal_name

	var callable := Callable(target, method_name)
	# Godot 4.7+: connect() default flags is 0 (CONNECT_DEFAULT removed)
	var flags := int(params.get("flags", 0))

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Connect %s.%s" % [source.name, signal_name])
	ur.add_do_method(source, "connect", signal_name, callable, flags)
	ur.add_undo_method(source, "disconnect", signal_name, callable)
	ur.commit_action()

	return {
		"source_path": _ctx.node_path_relative(source),
		"target_path": _ctx.node_path_relative(target),
		"signal": signal_name,
		"method": method_name,
	}


func disconnect_signal(params: Dictionary) -> Dictionary:
	var source_path := str(params.get("source_path", "")).strip_edges()
	var signal_name := str(params.get("signal", "")).strip_edges()
	var target_path := str(params.get("target_path", "")).strip_edges()
	var method_name := str(params.get("method", "")).strip_edges()

	if source_path.is_empty() or signal_name.is_empty() or target_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "source_path, signal, target_path required.")

	var source := _ctx.resolve_node(source_path)
	var target := _ctx.resolve_node(target_path)
	if source == null or target == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Source or target node not found.")

	if method_name.is_empty():
		method_name = "_on_%s" % signal_name

	var callable := Callable(target, method_name)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Disconnect %s.%s" % [source.name, signal_name])
	ur.add_do_method(source, "disconnect", signal_name, callable)
	ur.add_undo_method(source, "connect", signal_name, callable, 0)
	ur.commit_action()

	return {
		"source_path": _ctx.node_path_relative(source),
		"target_path": _ctx.node_path_relative(target),
		"signal": signal_name,
		"method": method_name,
	}


func get_signals(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found: %s" % node_path)

	var signals_out: Array[Dictionary] = []
	for sig in node.get_signal_list():
		var sig_name := str(sig.get("name", ""))
		var connections: Array[Dictionary] = []
		for conn in node.get_signal_connection_list(sig_name):
			var target_obj: Object = conn.get("callable", Callable()).get_object()
			var method := str(conn.get("callable", Callable()).get_method())
			var target_path := ""
			if target_obj is Node:
				target_path = _ctx.node_path_relative(target_obj as Node)
			connections.append({
				"target_path": target_path,
				"method": method,
				"flags": conn.get("flags", 0),
			})
		signals_out.append({
			"name": sig_name,
			"args": sig.get("args", []),
			"connections": connections,
		})

	return {"node_path": _ctx.node_path_relative(node), "signals": signals_out}


func get_node_groups(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found.")

	return {"node_path": _ctx.node_path_relative(node), "groups": node.get_groups()}


func set_node_groups(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var groups: Array = params.get("groups", [])
	var mode := str(params.get("mode", "replace")).strip_edges().to_lower()

	if node_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'node_path' is required.")

	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found.")

	var old_groups := node.get_groups()
	var new_groups: PackedStringArray = PackedStringArray()

	match mode:
		"add":
			new_groups = old_groups.duplicate()
			for g in groups:
				if str(g) not in new_groups:
					new_groups.append(str(g))
		"remove":
			new_groups = old_groups.duplicate()
			for g in groups:
				new_groups.erase(str(g))
		"replace", _:
			for g in groups:
				new_groups.append(str(g))

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Set Groups")
	ur.add_do_method(self, "_apply_groups", node, new_groups)
	ur.add_undo_method(self, "_apply_groups", node, old_groups)
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(node), "groups": Array(new_groups), "mode": mode}


func find_nodes_in_group(params: Dictionary) -> Dictionary:
	var group := str(params.get("group", "")).strip_edges()
	if group.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'group' is required.")

	var root := _ctx.edited_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No edited scene.")

	var nodes: Array[Dictionary] = []
	_collect_group_nodes(root, group, nodes)

	return {"group": group, "nodes": nodes, "count": nodes.size()}


func _collect_group_nodes(node: Node, group: String, out: Array) -> void:
	if node.is_in_group(group):
		out.append({
			"path": _ctx.node_path_relative(node),
			"name": node.name,
			"type": node.get_class(),
		})
	for child in node.get_children():
		_collect_group_nodes(child, group, out)


func _apply_groups(node: Node, groups: PackedStringArray) -> void:
	for g in node.get_groups():
		node.remove_from_group(g)
	for g in groups:
		node.add_to_group(g)


