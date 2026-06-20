## Phase 9 shader tools.
class_name MCPShaderTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext

const DEFAULT_SHADER := "shader_type canvas_item;\n\nvoid fragment() {\n\tCOLOR = vec4(1.0, 0.2, 0.4, 1.0);\n}\n"


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func create_shader(params: Dictionary) -> Dictionary:
	var shader_path := MCPPathUtils.normalize_res_path(str(params.get("shader_path", "")))
	if shader_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'shader_path' is required.")
	if not shader_path.ends_with(".gdshader"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "shader_path must end with .gdshader")
	if MCPPathUtils.file_exists(shader_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Shader exists.")

	var content := str(params.get("content", DEFAULT_SHADER))
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create Shader")
	ur.add_do_method(self, "_write_file", shader_path, content)
	ur.add_undo_method(self, "_delete_file", shader_path)
	ur.commit_action()
	_ctx.iface().get_resource_filesystem().update_file(shader_path)
	return {"shader_path": shader_path, "created": true}


func read_shader(params: Dictionary) -> Dictionary:
	var shader_path := MCPPathUtils.normalize_res_path(str(params.get("shader_path", "")))
	if not MCPPathUtils.file_exists(shader_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Shader not found.")
	var content := MCPPathUtils.read_text_file(shader_path)
	return {"shader_path": shader_path, "content": content}


func edit_shader(params: Dictionary) -> Dictionary:
	var shader_path := MCPPathUtils.normalize_res_path(str(params.get("shader_path", "")))
	if not MCPPathUtils.file_exists(shader_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Shader not found.")
	if not params.has("content"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'content' required.")

	var new_content := str(params["content"])
	var old_content := MCPPathUtils.read_text_file(shader_path)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Edit Shader")
	ur.add_do_method(self, "_write_file", shader_path, new_content)
	ur.add_undo_method(self, "_write_file", shader_path, old_content)
	ur.commit_action()
	_ctx.iface().get_resource_filesystem().update_file(shader_path)
	return {"shader_path": shader_path, "size_bytes": new_content.length()}


func assign_shader_material(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var node := _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found.")

	var shader_path := MCPPathUtils.normalize_res_path(str(params.get("shader_path", "")))
	var shader: Shader = load(shader_path) if not shader_path.is_empty() else null
	if shader == null and shader_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'shader_path' required.")

	var mat := ShaderMaterial.new()
	mat.shader = shader
	var prev = node.get("material") if node.get("material") != null else node.get("material_override")
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Assign Shader Material")
	if node is CanvasItem:
		ur.add_do_property(node, "material", mat)
		ur.add_undo_property(node, "material", prev)
	elif node is MeshInstance3D:
		var surface := int(params.get("surface", 0))
		ur.add_do_method(node, "set_surface_override_material", surface, mat)
		ur.add_undo_method(node, "set_surface_override_material", surface, prev)
	else:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Node type does not support materials.")
	ur.commit_action()
	return {"node_path": node_path, "shader_path": shader_path}


func set_shader_param(params: Dictionary) -> Dictionary:
	var mat := _resolve_shader_material(params)
	if mat == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "ShaderMaterial not found.")

	var param := str(params.get("param", "")).strip_edges()
	if param.is_empty() or not params.has("value"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "param and value required.")

	var value := MCPTypeParser.parse_value(params.get("value"))
	mat.set_shader_parameter(param, value)
	return {"node_path": str(params.get("node_path", "")), "param": param}


func get_shader_params(params: Dictionary) -> Dictionary:
	var mat := _resolve_shader_material(params)
	if mat == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "ShaderMaterial not found.")

	var shader: Shader = mat.shader
	if shader == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No shader assigned.")

	var params_out: Dictionary = {}
	for uniform in shader.get_shader_uniform_list():
		var pname := str(uniform.get("name", ""))
		if pname.is_empty():
			continue
		params_out[pname] = str(mat.get_shader_parameter(pname))

	return {
		"node_path": str(params.get("node_path", "")),
		"shader_path": shader.resource_path,
		"params": params_out,
	}


func _resolve_shader_material(params: Dictionary) -> ShaderMaterial:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var node := _ctx.resolve_node(node_path)
	if node == null:
		return null
	var mat = node.get("material")
	if mat is ShaderMaterial:
		return mat
	if node is MeshInstance3D:
		var surface := int(params.get("surface", 0))
		var smat = (node as MeshInstance3D).get_surface_override_material(surface)
		if smat is ShaderMaterial:
			return smat
	return null


func _write_file(path: String, content: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	var dir_path := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(global_path, FileAccess.WRITE)
	if f:
		f.store_string(content)


func _delete_file(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
