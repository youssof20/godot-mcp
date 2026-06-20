## Phase 4 resource read/write and autoload tools.
class_name MCPResourceTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func read_resource(params: Dictionary) -> Dictionary:
	var resource_path := MCPPathUtils.normalize_res_path(str(params.get("resource_path", "")))
	if resource_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'resource_path' is required.")
	if not MCPPathUtils.file_exists(resource_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Resource not found: %s" % resource_path)

	var as_text := bool(params.get("as_text", false))
	if as_text or resource_path.ends_with(".tres") or resource_path.ends_with(".tscn"):
		var content := MCPPathUtils.read_text_file(resource_path)
		return {
			"resource_path": resource_path,
			"format": "text",
			"content": content,
			"size_bytes": content.length(),
		}

	var resource: Resource = load(resource_path)
	if resource == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_RESOURCE_TYPE, "Failed to load resource.")

	var props: Dictionary = {}
	for info in resource.get_property_list():
		var usage := int(info.get("usage", 0))
		if usage & PROPERTY_USAGE_EDITOR:
			var pname := str(info.get("name", ""))
			if not pname.is_empty():
				props[pname] = _serialize(resource.get(pname))

	return {
		"resource_path": resource_path,
		"format": "object",
		"class": resource.get_class(),
		"properties": props,
	}


func edit_resource(params: Dictionary) -> Dictionary:
	var resource_path := MCPPathUtils.normalize_res_path(str(params.get("resource_path", "")))
	var properties: Dictionary = params.get("properties", {})
	if resource_path.is_empty() or properties.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'resource_path' and 'properties' required.")
	if not MCPPathUtils.file_exists(resource_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Resource not found.")

	var resource: Resource = load(resource_path)
	if resource == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_RESOURCE_TYPE, "Failed to load resource.")

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Edit Resource: %s" % resource_path.get_file())
	for key in properties.keys():
		var prop := str(key)
		var old_val = resource.get(prop)
		var new_val = MCPTypeParser.parse_value(properties[key])
		ur.add_do_property(resource, prop, new_val)
		ur.add_undo_property(resource, prop, old_val)
	ur.add_do_method(ResourceSaver, "save", resource, resource_path)
	ur.commit_action()

	return {"resource_path": resource_path, "updated_properties": properties.keys()}


func create_resource(params: Dictionary) -> Dictionary:
	var resource_path := MCPPathUtils.normalize_res_path(str(params.get("resource_path", "")))
	var class_name_str := str(params.get("class", "Resource"))
	if resource_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'resource_path' is required.")
	if MCPPathUtils.file_exists(resource_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Resource already exists.")
	if not ClassDB.class_exists(class_name_str) or not ClassDB.is_parent_class(class_name_str, "Resource"):
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_RESOURCE_TYPE, "Invalid resource class.")

	var resource: Resource = ClassDB.instantiate(class_name_str) as Resource
	if resource == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to instantiate resource.")

	var properties: Dictionary = params.get("properties", {})
	for key in properties.keys():
		resource.set(str(key), MCPTypeParser.parse_value(properties[key]))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resource_path.get_base_dir()))
	var err := ResourceSaver.save(resource, resource_path)
	if err != OK:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Save failed (error %d)" % err)

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create Resource")
	ur.add_do_method(ResourceSaver, "save", resource, resource_path)
	ur.add_undo_method(self, "_delete_file", resource_path)
	ur.commit_action()

	return {"resource_path": resource_path, "class": class_name_str, "created": true}


func get_resource_preview(params: Dictionary) -> Dictionary:
	var resource_path := MCPPathUtils.normalize_res_path(str(params.get("resource_path", "")))
	if resource_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'resource_path' is required.")
	if not MCPPathUtils.file_exists(resource_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Resource not found.")

	var resource: Resource = load(resource_path)
	if resource == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.UNSUPPORTED_RESOURCE_TYPE, "Failed to load.")

	# Godot 4.4+: preview metadata from known resource types (no fake image bytes)
	if resource is Texture2D:
		var tex := resource as Texture2D
		return {
			"resource_path": resource_path,
			"class": resource.get_class(),
			"preview_available": true,
			"width": tex.get_width(),
			"height": tex.get_height(),
			"type": "Texture2D",
		}

	return {
		"resource_path": resource_path,
		"class": resource.get_class(),
		"preview_available": false,
		"message": "No preview metadata for this resource type. Use read_resource.",
	}


func add_autoload(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", "")).strip_edges()
	var script_path := MCPPathUtils.normalize_res_path(str(params.get("path", "")))
	if name.is_empty() or script_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'name' and 'path' are required.")
	if not MCPPathUtils.file_exists(script_path):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Script not found.")

	var key := "autoload/%s" % name
	if ProjectSettings.has_setting(key):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Autoload '%s' already exists." % name)

	var value := "*%s" % script_path
	var old_val = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Add Autoload: %s" % name)
	ur.add_do_method(self, "_set_autoload", key, value)
	ur.add_undo_method(self, "_clear_autoload", key, old_val)
	ur.commit_action()

	return {"name": name, "path": script_path, "added": true}


func remove_autoload(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", "")).strip_edges()
	if name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'name' is required.")

	var key := "autoload/%s" % name
	if not ProjectSettings.has_setting(key):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Autoload not found: %s" % name)

	var old_val = ProjectSettings.get_setting(key)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Remove Autoload: %s" % name)
	ur.add_do_method(self, "_clear_autoload", key, null)
	ur.add_undo_method(self, "_set_autoload", key, old_val)
	ur.commit_action()

	return {"name": name, "removed": true}


func _set_autoload(key: String, value: Variant) -> void:
	ProjectSettings.set_setting(key, value)
	ProjectSettings.save()


func _clear_autoload(key: String, _old: Variant) -> void:
	ProjectSettings.set_setting(key, null)
	ProjectSettings.save()


func _delete_file(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)


func _serialize(value: Variant) -> Variant:
	if value is Resource:
		return {"class": value.get_class(), "path": value.resource_path}
	return value
