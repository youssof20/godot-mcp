## Phase 9 theme and UI tools.
class_name MCPThemeUiTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func create_theme(params: Dictionary) -> Dictionary:
	var theme_path := MCPPathUtils.normalize_res_path(str(params.get("theme_path", "res://themes/mcp_theme.tres")))
	if not theme_path.ends_with(".tres"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "theme_path must end with .tres")
	if MCPPathUtils.file_exists(theme_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Theme already exists.")

	var theme := Theme.new()
	var global_path := ProjectSettings.globalize_path(theme_path)
	var dir_path := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var err := ResourceSaver.save(theme, theme_path)
	if err != OK:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to save theme.")

	var control_path := str(params.get("control_path", "")).strip_edges()
	if not control_path.is_empty():
		var control := _ctx.resolve_node(control_path)
		if control is Control:
			(control as Control).theme = theme

	_ctx.iface().get_resource_filesystem().scan()
	return {"theme_path": theme_path, "created": true}


func set_theme_color(params: Dictionary) -> Dictionary:
	var theme := _resolve_theme(params)
	if theme == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Theme not found.")

	var data_type := str(params.get("data_type", "Button"))
	var name := str(params.get("name", "font_color"))
	var color := MCPTypeParser.parse_value(params.get("color", {"r": 1, "g": 1, "b": 1, "a": 1}))
	if not color is Color:
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Invalid color.")

	theme.set_color(name, data_type, color)
	_save_theme(theme, params)
	return {"theme_path": str(params.get("theme_path", "")), "data_type": data_type, "name": name}


func set_theme_constant(params: Dictionary) -> Dictionary:
	var theme := _resolve_theme(params)
	if theme == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Theme not found.")

	var data_type := str(params.get("data_type", "Button"))
	var name := str(params.get("name", "h_separation"))
	var value := int(params.get("value", 4))
	theme.set_constant(name, data_type, value)
	_save_theme(theme, params)
	return {"theme_path": str(params.get("theme_path", "")), "data_type": data_type, "name": name, "value": value}


func set_theme_font_size(params: Dictionary) -> Dictionary:
	var theme := _resolve_theme(params)
	if theme == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Theme not found.")

	var data_type := str(params.get("data_type", "Label"))
	var name := str(params.get("name", "font_size"))
	var value := int(params.get("value", 16))
	theme.set_font_size(name, data_type, value)
	_save_theme(theme, params)
	return {"theme_path": str(params.get("theme_path", "")), "data_type": data_type, "name": name, "value": value}


func set_theme_stylebox(params: Dictionary) -> Dictionary:
	var theme := _resolve_theme(params)
	if theme == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Theme not found.")

	var data_type := str(params.get("data_type", "Button"))
	var name := str(params.get("name", "normal"))
	var box := StyleBoxFlat.new()
	if params.has("bg_color"):
		box.bg_color = MCPTypeParser.parse_value(params.get("bg_color"))
	if params.has("corner_radius"):
		var r := int(params.get("corner_radius"))
		box.set_corner_radius_all(r)
	theme.set_stylebox(name, data_type, box)
	_save_theme(theme, params)
	return {"theme_path": str(params.get("theme_path", "")), "data_type": data_type, "name": name}


func get_theme_info(params: Dictionary) -> Dictionary:
	var theme := _resolve_theme(params)
	if theme == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Theme not found.")

	return {
		"theme_path": str(params.get("theme_path", "")),
		"color_types": theme.get_color_type_list(),
		"color_count": theme.get_color_list("").size(),
		"constant_types": theme.get_constant_type_list(),
		"font_size_types": theme.get_font_size_type_list(),
		"stylebox_types": theme.get_stylebox_type_list(),
	}


func _resolve_theme(params: Dictionary) -> Theme:
	var theme_path := MCPPathUtils.normalize_res_path(str(params.get("theme_path", "")))
	if theme_path.is_empty() or not MCPPathUtils.file_exists(theme_path):
		return null
	var theme: Theme = load(theme_path)
	return theme


func _save_theme(theme: Theme, params: Dictionary) -> void:
	var theme_path := MCPPathUtils.normalize_res_path(str(params.get("theme_path", "")))
	if not theme_path.is_empty():
		ResourceSaver.save(theme, theme_path)
		_ctx.iface().get_resource_filesystem().update_file(theme_path)
