## Phase 8 physics tools.
class_name MCPPhysicsTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func setup_physics_body(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var body_type := str(params.get("body_type", "RigidBody2D"))
	if not _ctx.is_valid_node_type(body_type):
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_NODE_TYPE, "Unsupported body: %s" % body_type)

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var node_name := str(params.get("node_name", body_type))
	var body := _ctx.instantiate_node(body_type)
	body.name = node_name

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Physics Body: %s" % node_name)
	ur.add_do_method(parent, "add_child", body)
	ur.add_do_method(body, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", body)
	ur.add_undo_method(body, "queue_free")
	ur.commit_action()

	var props: Dictionary = params.get("properties", {})
	for key in props.keys():
		body.set(str(key), MCPTypeParser.coerce_for_property(body, str(key), props[key]))

	return {
		"node_path": _ctx.node_path_relative(body),
		"type": body.get_class(),
		"collision_layer": body.get("collision_layer") if body.get("collision_layer") != null else null,
		"collision_mask": body.get("collision_mask") if body.get("collision_mask") != null else null,
	}


func setup_collision(params: Dictionary) -> Dictionary:
	var body := _resolve_physics_body(params)
	if body == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Physics body not found.")

	var shape_type := str(params.get("shape_type", "rectangle")).to_lower()
	var shape: Shape2D = null
	var shape3d: Shape3D = null
	var is_3d := body is Node3D and not body is Node2D

	match shape_type:
		"circle":
			if is_3d:
				var s := SphereShape3D.new()
				s.radius = float(params.get("radius", 16.0))
				shape3d = s
			else:
				var s := CircleShape2D.new()
				s.radius = float(params.get("radius", 16.0))
				shape = s
		"capsule":
			if is_3d:
				var s := CapsuleShape3D.new()
				s.radius = float(params.get("radius", 8.0))
				s.height = float(params.get("height", 32.0))
				shape3d = s
			else:
				var s := CapsuleShape2D.new()
				s.radius = float(params.get("radius", 8.0))
				s.height = float(params.get("height", 32.0))
				shape = s
		_:
			if is_3d:
				var s := BoxShape3D.new()
				var size := MCPTypeParser.parse_value(params.get("size", {"x": 32, "y": 32, "z": 32}))
				s.size = size if size is Vector3 else Vector3(32, 32, 32)
				shape3d = s
			else:
				var s := RectangleShape2D.new()
				var size2 := MCPTypeParser.parse_value(params.get("size", {"x": 32, "y": 32}))
				s.size = size2 if size2 is Vector2 else Vector2(32, 32)
				shape = s

	var collision_node: Node = null
	if is_3d:
		collision_node = CollisionShape3D.new()
		(collision_node as CollisionShape3D).shape = shape3d
	else:
		collision_node = CollisionShape2D.new()
		(collision_node as CollisionShape2D).shape = shape

	collision_node.name = str(params.get("node_name", "CollisionShape"))

	var edited_root := _ctx.edited_root()
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Collision")
	ur.add_do_method(body, "add_child", collision_node)
	ur.add_do_method(collision_node, "set_owner", edited_root)
	ur.add_undo_method(body, "remove_child", collision_node)
	ur.add_undo_method(collision_node, "queue_free")
	ur.commit_action()

	return {
		"body_path": _ctx.node_path_relative(body),
		"collision_path": _ctx.node_path_relative(collision_node),
		"shape_type": shape_type,
	}


func set_physics_layers(params: Dictionary) -> Dictionary:
	var node := _resolve_physics_body(params)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Physics body not found.")

	if not params.has("collision_layer") and not params.has("collision_mask"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "collision_layer or collision_mask required.")

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Set Physics Layers")
	if params.has("collision_layer"):
		var layer := int(params.get("collision_layer"))
		ur.add_do_property(node, "collision_layer", layer)
		ur.add_undo_property(node, "collision_layer", node.collision_layer)
	if params.has("collision_mask"):
		var mask := int(params.get("collision_mask"))
		ur.add_do_property(node, "collision_mask", mask)
		ur.add_undo_property(node, "collision_mask", node.collision_mask)
	ur.commit_action()

	return get_physics_layers({"node_path": _ctx.node_path_relative(node)})


func get_physics_layers(params: Dictionary) -> Dictionary:
	var node := _resolve_physics_body(params)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Physics body not found.")

	return {
		"node_path": _ctx.node_path_relative(node),
		"type": node.get_class(),
		"collision_layer": int(node.get("collision_layer")),
		"collision_mask": int(node.get("collision_mask")),
	}


func get_collision_info(params: Dictionary) -> Dictionary:
	var node := _resolve_physics_body(params)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Physics body not found.")

	var shapes: Array[Dictionary] = []
	for child in node.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			shapes.append({
				"path": _ctx.node_path_relative(cs),
				"type": "CollisionShape2D",
				"shape": cs.shape.get_class() if cs.shape else "",
				"disabled": cs.disabled,
			})
		elif child is CollisionShape3D:
			var cs := child as CollisionShape3D
			shapes.append({
				"path": _ctx.node_path_relative(cs),
				"type": "CollisionShape3D",
				"shape": cs.shape.get_class() if cs.shape else "",
				"disabled": cs.disabled,
			})

	return {"node_path": _ctx.node_path_relative(node), "shapes": shapes, "count": shapes.size()}


func add_raycast(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var dim := str(params.get("dimension", "2d")).to_lower()
	var node_type := "RayCast3D" if dim == "3d" else "RayCast2D"
	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var ray := _ctx.instantiate_node(node_type)
	ray.name = str(params.get("node_name", node_type))
	if params.has("target_position"):
		ray.set("target_position", MCPTypeParser.parse_value(params.get("target_position")))
	if params.has("collision_mask"):
		ray.set("collision_mask", int(params.get("collision_mask")))

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Add Raycast")
	ur.add_do_method(parent, "add_child", ray)
	ur.add_do_method(ray, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", ray)
	ur.add_undo_method(ray, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(ray), "type": ray.get_class()}


func _resolve_physics_body(params: Dictionary) -> Node:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return null
	var node := _ctx.resolve_node(node_path)
	if node == null:
		return null
	if node is CollisionObject2D or node is CollisionObject3D or node is PhysicsBody2D or node is PhysicsBody3D:
		return node
	if node is StaticBody2D or node is RigidBody2D or node is CharacterBody2D or node is AnimatableBody2D:
		return node
	if node is StaticBody3D or node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D:
		return node
	return null
