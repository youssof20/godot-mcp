## Phase 8 particle tools.
class_name MCPParticleTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func create_particles(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var dim := str(params.get("dimension", "2d")).to_lower()
	var node_type := "GPUParticles3D" if dim == "3d" else "GPUParticles2D"
	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var particles := _ctx.instantiate_node(node_type)
	particles.name = str(params.get("node_name", node_type))
	if params.has("amount"):
		particles.set("amount", int(params.get("amount")))
	if params.has("lifetime"):
		particles.set("lifetime", float(params.get("lifetime")))
	if params.has("emitting"):
		particles.set("emitting", bool(params.get("emitting")))

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create Particles")
	ur.add_do_method(parent, "add_child", particles)
	ur.add_do_method(particles, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", particles)
	ur.add_undo_method(particles, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(particles), "type": particles.get_class()}


func set_particle_material(params: Dictionary) -> Dictionary:
	var node := _resolve_particles(params)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Particle node not found.")

	var mat: Material = node.process_material
	if mat == null:
		mat = ParticleProcessMaterial.new()
		node.process_material = mat

	if mat is ParticleProcessMaterial:
		var ppm := mat as ParticleProcessMaterial
		if params.has("direction"):
			ppm.direction = MCPTypeParser.parse_value(params.get("direction"))
		if params.has("spread"):
			ppm.spread = float(params.get("spread"))
		if params.has("initial_velocity_min"):
			ppm.initial_velocity_min = float(params.get("initial_velocity_min"))
		if params.has("initial_velocity_max"):
			ppm.initial_velocity_max = float(params.get("initial_velocity_max"))
		if params.has("gravity"):
			ppm.gravity = MCPTypeParser.parse_value(params.get("gravity"))

	return {"node_path": _ctx.node_path_relative(node), "material_class": mat.get_class()}


func set_particle_color_gradient(params: Dictionary) -> Dictionary:
	var node := _resolve_particles(params)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Particle node not found.")

	var mat: Material = node.process_material
	if mat == null or not mat is ParticleProcessMaterial:
		mat = ParticleProcessMaterial.new()
		node.process_material = mat

	var ppm := mat as ParticleProcessMaterial
	var gradient := Gradient.new()
	var colors: Array = params.get("colors", [{"r": 1, "g": 1, "b": 1, "a": 1}])
	for i in range(colors.size()):
		var c := MCPTypeParser.parse_value(colors[i])
		gradient.add_point(float(i) / maxf(float(colors.size() - 1), 1.0), c if c is Color else Color.WHITE)
	# Godot 4.7+ API: ParticleProcessMaterial.color_ramp is GradientTexture1D (Texture2D).
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	ppm.color_ramp = grad_tex

	return {"node_path": _ctx.node_path_relative(node), "color_points": colors.size()}


func apply_particle_preset(params: Dictionary) -> Dictionary:
	var preset := str(params.get("preset", "spark")).to_lower()
	var merged: Dictionary = params.duplicate()
	match preset:
		"smoke":
			merged["amount"] = merged.get("amount", 64)
			merged["lifetime"] = merged.get("lifetime", 2.0)
			merged["direction"] = {"x": 0, "y": -1, "z": 0}
			merged["spread"] = 15.0
			merged["colors"] = [{"r": 0.5, "g": 0.5, "b": 0.5, "a": 0.8}, {"r": 0.2, "g": 0.2, "b": 0.2, "a": 0.0}]
		"fire":
			merged["amount"] = merged.get("amount", 128)
			merged["lifetime"] = merged.get("lifetime", 1.0)
			merged["direction"] = {"x": 0, "y": -1, "z": 0}
			merged["spread"] = 25.0
			merged["colors"] = [{"r": 1, "g": 0.6, "b": 0.1, "a": 1}, {"r": 0.2, "g": 0.0, "b": 0.0, "a": 0}]
		_:
			merged["amount"] = merged.get("amount", 32)
			merged["lifetime"] = merged.get("lifetime", 0.6)
			merged["spread"] = 180.0
			merged["initial_velocity_min"] = 80.0
			merged["initial_velocity_max"] = 160.0

	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		var created := create_particles(merged)
		node_path = str(created.get("node_path", ""))
		if node_path.is_empty():
			return created

	var mat_params := {"node_path": node_path}
	for key in ["direction", "spread", "initial_velocity_min", "initial_velocity_max", "gravity"]:
		if merged.has(key):
			mat_params[key] = merged[key]
	set_particle_material(mat_params)
	if merged.has("colors"):
		set_particle_color_gradient({"node_path": node_path, "colors": merged["colors"]})
	return get_particle_info({"node_path": node_path})


func get_particle_info(params: Dictionary) -> Dictionary:
	var node := _resolve_particles(params)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Particle node not found.")

	var mat: Material = node.process_material as Material
	return {
		"node_path": _ctx.node_path_relative(node),
		"type": node.get_class(),
		"amount": int(node.get("amount")),
		"lifetime": float(node.get("lifetime")),
		"emitting": bool(node.get("emitting")),
		"process_material": mat.get_class() if mat else "",
	}


func _resolve_particles(params: Dictionary) -> Node:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return null
	var node := _ctx.resolve_node(node_path)
	if node is GPUParticles2D or node is GPUParticles3D or node is CPUParticles2D or node is CPUParticles3D:
		return node
	return null
