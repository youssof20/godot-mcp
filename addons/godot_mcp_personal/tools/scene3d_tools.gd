## Phase 8 3D scene tools.
class_name MCPScene3DTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func add_mesh_instance(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var mesh := MeshInstance3D.new()
	mesh.name = str(params.get("node_name", "MeshInstance3D"))
	var mesh_type := str(params.get("mesh_type", "box")).to_lower()
	match mesh_type:
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = float(params.get("radius", 0.5))
			sm.height = float(params.get("height", 1.0))
			mesh.mesh = sm
		"plane":
			var pm := PlaneMesh.new()
			pm.size = Vector2(float(params.get("width", 2.0)), float(params.get("depth", 2.0)))
			mesh.mesh = pm
		_:
			var bm := BoxMesh.new()
			var size := MCPTypeParser.parse_value(params.get("size", {"x": 1, "y": 1, "z": 1}))
			bm.size = size if size is Vector3 else Vector3.ONE
			mesh.mesh = bm

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Add MeshInstance3D")
	ur.add_do_method(parent, "add_child", mesh)
	ur.add_do_method(mesh, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", mesh)
	ur.add_undo_method(mesh, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(mesh), "mesh_type": mesh_type}


func setup_camera_3d(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var cam := Camera3D.new()
	cam.name = str(params.get("node_name", "Camera3D"))
	if params.has("fov"):
		cam.fov = float(params.get("fov"))
	if params.has("position"):
		cam.position = MCPTypeParser.parse_value(params.get("position"))
	if params.has("rotation"):
		cam.rotation = MCPTypeParser.parse_value(params.get("rotation"))
	if bool(params.get("current", false)):
		cam.current = true

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Camera3D")
	ur.add_do_method(parent, "add_child", cam)
	ur.add_do_method(cam, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", cam)
	ur.add_undo_method(cam, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(cam), "current": cam.current}


func setup_lighting(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var light_type := str(params.get("light_type", "directional")).to_lower()
	var light: Node3D = null
	match light_type:
		"omni":
			light = OmniLight3D.new()
		"spot":
			light = SpotLight3D.new()
		_:
			light = DirectionalLight3D.new()
	light.name = str(params.get("node_name", light.get_class()))
	if params.has("energy"):
		light.set("light_energy", float(params.get("energy")))
	if params.has("color"):
		light.set("light_color", MCPTypeParser.parse_value(params.get("color")))

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Lighting")
	ur.add_do_method(parent, "add_child", light)
	ur.add_do_method(light, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", light)
	ur.add_undo_method(light, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(light), "light_type": light_type}


func setup_environment(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var env_node := WorldEnvironment.new()
	env_node.name = str(params.get("node_name", "WorldEnvironment"))
	var env := Environment.new()
	if params.has("background_mode"):
		env.background_mode = int(params.get("background_mode"))
	if params.has("background_color"):
		env.background_color = MCPTypeParser.parse_value(params.get("background_color"))
	if params.has("ambient_light_color"):
		env.ambient_light_color = MCPTypeParser.parse_value(params.get("ambient_light_color"))
	env_node.environment = env

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Setup Environment")
	ur.add_do_method(parent, "add_child", env_node)
	ur.add_do_method(env_node, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", env_node)
	ur.add_undo_method(env_node, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(env_node)}


func add_gridmap(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var grid := GridMap.new()
	grid.name = str(params.get("node_name", "GridMap"))
	var mesh_lib_path := str(params.get("mesh_library", "")).strip_edges()
	if not mesh_lib_path.is_empty():
		var lib: MeshLibrary = load(MCPPathUtils.normalize_res_path(mesh_lib_path))
		if lib != null:
			grid.mesh_library = lib

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Add GridMap")
	ur.add_do_method(parent, "add_child", grid)
	ur.add_do_method(grid, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", grid)
	ur.add_undo_method(grid, "queue_free")
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(grid),
		"mesh_library": grid.mesh_library.resource_path if grid.mesh_library else "",
	}


func set_material_3d(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var node := _ctx.resolve_node(node_path)
	if node == null or not node is MeshInstance3D:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "MeshInstance3D not found.")

	var mesh_inst := node as MeshInstance3D
	var mat: Material = null
	if params.has("material_path"):
		mat = load(MCPPathUtils.normalize_res_path(str(params.get("material_path"))))
	elif params.has("color"):
		var std := StandardMaterial3D.new()
		std.albedo_color = MCPTypeParser.parse_value(params.get("color"))
		mat = std
	else:
		mat = StandardMaterial3D.new()

	var surface := int(params.get("surface", 0))
	var prev := mesh_inst.get_surface_override_material(surface)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Set Material 3D")
	ur.add_do_method(mesh_inst, "set_surface_override_material", surface, mat)
	ur.add_undo_method(mesh_inst, "set_surface_override_material", surface, prev)
	ur.commit_action()

	return {
		"node_path": node_path,
		"surface": surface,
		"material_class": mat.get_class(),
	}
