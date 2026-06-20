## Phase 10 get_tool_help — tool metadata and categories.
class_name MCPToolHelpTools
extends RefCounted

const CATEGORIES: Dictionary = {
	"godot_ping": "utility",
	"get_connection_status": "utility",
	"list_available_tools": "utility",
	"get_tool_help": "utility",
	"get_project_info": "project",
	"get_filesystem_tree": "project",
	"search_files": "project",
	"get_project_settings": "project",
	"play_scene": "runtime",
	"stop_scene": "runtime",
	"export_project": "export",
	"create_shader": "shader",
	"create_theme": "theme",
}


func get_tool_help(params: Dictionary, implemented: Array) -> Dictionary:
	var tool := str(params.get("tool", "")).strip_edges()
	if tool.is_empty():
		var entries: Array[Dictionary] = []
		for t in implemented:
			entries.append(_entry(str(t), implemented))
		return {"tools": entries, "count": entries.size()}

	if tool not in implemented:
		return MCPErrorCodes.make_error(
			MCPErrorCodes.NOT_FOUND,
			"Tool not implemented: %s" % tool,
			"Use list_available_tools or omit 'tool' to list working tools.",
		)

	return _entry(tool, implemented)


func _entry(tool: String, implemented: Array) -> Dictionary:
	return {
		"tool": tool,
		"implemented": true,
		"category": _category_for(tool),
		"description": _description_for(tool),
		"dangerous": tool in ["execute_game_script", "execute_editor_script", "export_project"],
	}


func _category_for(tool: String) -> String:
	if CATEGORIES.has(tool):
		return str(CATEGORIES[tool])
	if tool.begins_with("tilemap_"):
		return "tilemap"
	if tool.begins_with("get_") or tool.begins_with("list_") or tool.begins_with("read_") or tool.begins_with("find_") or tool.begins_with("analyze_") or tool.begins_with("audit_"):
		return "read"
	if tool.begins_with("create_") or tool.begins_with("add_") or tool.begins_with("setup_") or tool.begins_with("set_") or tool.begins_with("edit_"):
		return "mutation"
	if tool.begins_with("simulate_"):
		return "input"
	if tool.contains("animation") or tool.contains("anim"):
		return "animation"
	if tool.contains("shader"):
		return "shader"
	if tool.contains("theme"):
		return "theme"
	if tool.contains("audio"):
		return "audio"
	if tool.contains("navigation") or tool.contains("nav"):
		return "navigation"
	if tool.contains("particle"):
		return "particles"
	if tool.contains("physics") or tool.contains("collision") or tool.contains("raycast"):
		return "physics"
	return "general"


func _description_for(tool: String) -> String:
	return tool.replace("_", " ").capitalize()
