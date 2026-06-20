## Path normalization and validation under res://
## Godot 4.4+ assumption: ProjectSettings.globalize_path, FileAccess.file_exists
class_name MCPPathUtils
extends RefCounted

const SKIP_DIRS: Array[String] = [".godot", ".git", "node_modules"]


static func normalize_res_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	if p.begins_with("uid://"):
		return p
	if p.begins_with("res://"):
		return p
	if p.begins_with("res:/"):
		return "res://" + p.trim_prefix("res:/")
	return "res://" + p.trim_prefix("./")


static func is_inside_project(path: String) -> bool:
	var normalized := normalize_res_path(path)
	if normalized.begins_with("uid://"):
		return true
	if not normalized.begins_with("res://"):
		return false
	var global_path := ProjectSettings.globalize_path(normalized)
	var project_root := ProjectSettings.globalize_path("res://")
	return global_path.begins_with(project_root)


static func resolve_readable_path(path: String) -> String:
	var normalized := normalize_res_path(path)
	if normalized.begins_with("uid://"):
		# Godot 4.4+ API: ResourceUID.uid_to_path
		return ResourceUID.uid_to_path(normalized)
	return normalized


static func file_exists(path: String) -> bool:
	var resolved := resolve_readable_path(path)
	if not resolved.begins_with("res://"):
		return false
	return FileAccess.file_exists(ProjectSettings.globalize_path(resolved))


static func read_text_file(path: String) -> String:
	var resolved := resolve_readable_path(path)
	if not is_inside_project(resolved):
		return ""
	if not FileAccess.file_exists(ProjectSettings.globalize_path(resolved)):
		return ""
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path(resolved))


static func should_skip_dir(name: String) -> bool:
	return name in SKIP_DIRS or name.begins_with(".")
