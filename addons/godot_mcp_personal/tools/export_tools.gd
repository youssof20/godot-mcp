## Phase 9 export tools.
class_name MCPExportTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func list_export_presets(_params: Dictionary) -> Dictionary:
	var presets := _load_presets()
	return {"presets": presets, "count": presets.size()}


func get_export_info(params: Dictionary) -> Dictionary:
	var presets := _load_presets()
	var index := int(params.get("preset_index", 0))
	if presets.is_empty():
		return {
			"presets_found": false,
			"message": "No export_presets.cfg found. Create export presets in Project > Export.",
		}
	if index < 0 or index >= presets.size():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Invalid preset_index.")

	var cfg := _open_export_config()
	var section := "preset.%d" % index
	return {
		"presets_found": true,
		"preset": presets[index],
		"options": cfg.get_section_keys(section) if cfg != null else [],
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
	}


func export_project(params: Dictionary) -> Dictionary:
	var preset := str(params.get("preset", "")).strip_edges()
	var export_path := str(params.get("export_path", "")).strip_edges()
	if preset.is_empty() or export_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'preset' and 'export_path' required.")

	var debug := bool(params.get("debug", false))
	var flag := "--export-debug" if debug else "--export-release"
	var project_path := ProjectSettings.globalize_path("res://")
	var global_export := export_path
	if export_path.begins_with("res://"):
		global_export = ProjectSettings.globalize_path(export_path)

	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		["--headless", "--path", project_path, flag, preset, global_export],
		output,
		true,
		false
	)

	return {
		"exit_code": exit_code,
		"output": output,
		"preset": preset,
		"export_path": global_export,
		"success": exit_code == 0,
	}


func _load_presets() -> Array[Dictionary]:
	var cfg := _open_export_config()
	if cfg == null:
		return []
	var presets: Array[Dictionary] = []
	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		var section := "preset.%d" % idx
		presets.append({
			"index": idx,
			"name": str(cfg.get_value(section, "name", "")),
			"platform": str(cfg.get_value(section, "platform", "")),
			"runnable": bool(cfg.get_value(section, "runnable", false)),
		})
		idx += 1
	return presets


func _open_export_config() -> ConfigFile:
	var path := ProjectSettings.globalize_path("res://export_presets.cfg")
	if not FileAccess.file_exists(path):
		return null
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return null
	return cfg
