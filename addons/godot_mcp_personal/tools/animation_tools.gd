## Phase 7 AnimationPlayer tools.
class_name MCPAnimationTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func list_animations(params: Dictionary) -> Dictionary:
	var player := _resolve_animation_player(params)
	if player == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationPlayer not found.")

	var names: Array[String] = []
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			names.append("%s/%s" % [lib_name, anim_name] if not lib_name.is_empty() else str(anim_name))

	return {
		"node_path": _ctx.node_path_relative(player),
		"animations": names,
		"count": names.size(),
	}


func create_animation(params: Dictionary) -> Dictionary:
	var player := _resolve_animation_player(params)
	if player == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationPlayer not found.")

	var anim_name := str(params.get("animation_name", "")).strip_edges()
	if anim_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'animation_name' is required.")

	var lib_name := str(params.get("library", "")).strip_edges()
	var lib := _get_or_create_library(player, lib_name)
	if lib == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to access animation library.")

	if lib.has_animation(anim_name):
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Animation already exists: %s" % anim_name)

	var length := float(params.get("length", 1.0))
	var anim := Animation.new()
	anim.length = maxf(length, 0.01)

	var ur := _ctx.undo_redo()
	ur.create_action("MCP Create Animation: %s" % anim_name)
	ur.add_do_method(lib, "add_animation", anim_name, anim)
	ur.add_undo_method(lib, "remove_animation", anim_name)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(player),
		"library": lib_name,
		"animation_name": anim_name,
		"length": anim.length,
	}


func add_animation_track(params: Dictionary) -> Dictionary:
	var player := _resolve_animation_player(params)
	if player == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationPlayer not found.")

	var anim_name := str(params.get("animation_name", "")).strip_edges()
	var anim := _get_animation(player, anim_name)
	if anim == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Animation not found: %s" % anim_name)

	var track_type := _track_type_from_param(params.get("track_type", "value"))
	var track_path := str(params.get("path", "")).strip_edges()
	if track_path.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'path' is required.")

	var track_index := anim.add_track(track_type)
	anim.track_set_path(track_index, NodePath(track_path))

	return {
		"node_path": _ctx.node_path_relative(player),
		"animation_name": anim_name,
		"track_index": track_index,
		"track_type": track_type,
		"path": track_path,
	}


func set_animation_keyframe(params: Dictionary) -> Dictionary:
	var player := _resolve_animation_player(params)
	if player == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationPlayer not found.")

	var anim_name := str(params.get("animation_name", "")).strip_edges()
	var anim := _get_animation(player, anim_name)
	if anim == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Animation not found: %s" % anim_name)

	if not params.has("track_index") or not params.has("time") or not params.has("value"):
		return MCPErrorCodes.make_error(
			MCPErrorCodes.INVALID_PARAMS,
			"'track_index', 'time', and 'value' are required.",
		)

	var track_index := int(params.get("track_index"))
	if track_index < 0 or track_index >= anim.get_track_count():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Invalid track_index.")

	var time := float(params.get("time"))
	var value := MCPTypeParser.parse_value(params.get("value"))
	var transition := float(params.get("transition", 1.0))
	var key_index := anim.track_insert_key(track_index, time, value, transition)

	if params.has("length"):
		anim.length = maxf(float(params.get("length")), anim.length)

	return {
		"node_path": _ctx.node_path_relative(player),
		"animation_name": anim_name,
		"track_index": track_index,
		"key_index": key_index,
		"time": time,
	}


func get_animation_info(params: Dictionary) -> Dictionary:
	var player := _resolve_animation_player(params)
	if player == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationPlayer not found.")

	var anim_name := str(params.get("animation_name", "")).strip_edges()
	if anim_name.is_empty():
		var libraries: Array[Dictionary] = []
		for lib_name in player.get_animation_library_list():
			var lib := player.get_animation_library(lib_name)
			if lib == null:
				continue
			libraries.append({
				"library": lib_name,
				"animations": lib.get_animation_list(),
			})
		return {
			"node_path": _ctx.node_path_relative(player),
			"libraries": libraries,
			"autoplay": str(player.autoplay),
			"root_node": str(player.root_node),
		}

	var anim := _get_animation(player, anim_name)
	if anim == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Animation not found: %s" % anim_name)

	var tracks: Array[Dictionary] = []
	for i in range(anim.get_track_count()):
		tracks.append({
			"index": i,
			"type": anim.track_get_type(i),
			"path": str(anim.track_get_path(i)),
			"key_count": anim.track_get_key_count(i),
		})

	return {
		"node_path": _ctx.node_path_relative(player),
		"animation_name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"track_count": anim.get_track_count(),
		"tracks": tracks,
	}


func remove_animation(params: Dictionary) -> Dictionary:
	var player := _resolve_animation_player(params)
	if player == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "AnimationPlayer not found.")

	var anim_name := str(params.get("animation_name", "")).strip_edges()
	var lib_name := str(params.get("library", "")).strip_edges()
	var lib := player.get_animation_library(lib_name)
	if lib == null or not lib.has_animation(anim_name):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Animation not found: %s" % anim_name)

	var anim: Animation = lib.get_animation(anim_name)
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Remove Animation: %s" % anim_name)
	ur.add_do_method(lib, "remove_animation", anim_name)
	ur.add_undo_method(lib, "add_animation", anim_name, anim)
	ur.commit_action()

	return {
		"node_path": _ctx.node_path_relative(player),
		"animation_name": anim_name,
		"removed": true,
	}


func _resolve_animation_player(params: Dictionary) -> AnimationPlayer:
	var node_path := str(params.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return null
	var node := _ctx.resolve_node(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null


func _get_or_create_library(player: AnimationPlayer, lib_name: String) -> AnimationLibrary:
	if player.has_animation_library(lib_name):
		return player.get_animation_library(lib_name)
	var lib := AnimationLibrary.new()
	player.add_animation_library(lib_name, lib)
	return lib


func _get_animation(player: AnimationPlayer, anim_name: String) -> Animation:
	if anim_name.is_empty():
		return null
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		if lib != null and lib.has_animation(anim_name):
			return lib.get_animation(anim_name)
	return null


func _track_type_from_param(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	match str(value).strip_edges().to_lower():
		"value", "type_value":
			return Animation.TYPE_VALUE
		"position_3d", "type_position_3d":
			return Animation.TYPE_POSITION_3D
		"rotation_3d", "type_rotation_3d":
			return Animation.TYPE_ROTATION_3D
		"scale_3d", "type_scale_3d":
			return Animation.TYPE_SCALE_3D
		"method", "type_method":
			return Animation.TYPE_METHOD
		"bezier", "type_bezier":
			return Animation.TYPE_BEZIER
		"audio", "type_audio":
			return Animation.TYPE_AUDIO
		"animation", "type_animation":
			return Animation.TYPE_ANIMATION
		_:
			return Animation.TYPE_VALUE
