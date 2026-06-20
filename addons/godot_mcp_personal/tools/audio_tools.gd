## Phase 8 audio tools.
class_name MCPAudioTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func add_audio_player(params: Dictionary) -> Dictionary:
	var root_check := _ctx.require_edited_root()
	if root_check is Dictionary:
		return root_check

	var dim := str(params.get("dimension", "2d")).to_lower()
	var node_type := "AudioStreamPlayer3D" if dim == "3d" else "AudioStreamPlayer2D"
	if bool(params.get("ui", false)):
		node_type = "AudioStreamPlayer"

	var parent := _ctx.resolve_parent(str(params.get("parent_path", ".")))
	if parent == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Parent not found.")

	var player := _ctx.instantiate_node(node_type)
	player.name = str(params.get("node_name", node_type))
	var stream_path := str(params.get("stream_path", "")).strip_edges()
	if not stream_path.is_empty():
		var stream: AudioStream = load(MCPPathUtils.normalize_res_path(stream_path))
		if stream != null:
			player.stream = stream
	if params.has("volume_db"):
		player.volume_db = float(params.get("volume_db"))
	if params.has("autoplay"):
		player.autoplay = bool(params.get("autoplay"))

	var edited_root: Node = root_check
	var ur := _ctx.undo_redo()
	ur.create_action("MCP Add Audio Player")
	ur.add_do_method(parent, "add_child", player)
	ur.add_do_method(player, "set_owner", edited_root)
	ur.add_undo_method(parent, "remove_child", player)
	ur.add_undo_method(player, "queue_free")
	ur.commit_action()

	return {"node_path": _ctx.node_path_relative(player), "type": player.get_class()}


func add_audio_bus(params: Dictionary) -> Dictionary:
	var bus_name := str(params.get("bus_name", "")).strip_edges()
	if bus_name.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "bus_name required.")

	if AudioServer.get_bus_index(bus_name) >= 0:
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Bus already exists: %s" % bus_name)

	var at_position := int(params.get("at_position", -1))
	if at_position < 0:
		at_position = AudioServer.get_bus_count()
	AudioServer.add_bus(at_position)
	AudioServer.set_bus_name(at_position, bus_name)

	return {"bus_name": bus_name, "index": AudioServer.get_bus_index(bus_name)}


func add_audio_bus_effect(params: Dictionary) -> Dictionary:
	var bus_name := str(params.get("bus_name", "Master")).strip_edges()
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Bus not found: %s" % bus_name)

	var effect_type := str(params.get("effect_type", "reverb")).to_lower()
	var effect: AudioEffect = null
	match effect_type:
		"eq":
			effect = AudioEffectEQ.new()
		"compressor":
			effect = AudioEffectCompressor.new()
		"delay":
			effect = AudioEffectDelay.new()
		_:
			effect = AudioEffectReverb.new()

	AudioServer.add_bus_effect(bus_idx, effect)
	return {
		"bus_name": bus_name,
		"effect_type": effect_type,
		"effect_index": AudioServer.get_bus_effect_count(bus_idx) - 1,
	}


func set_audio_bus(params: Dictionary) -> Dictionary:
	var bus_name := str(params.get("bus_name", "Master")).strip_edges()
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Bus not found: %s" % bus_name)

	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(bus_idx, float(params.get("volume_db")))
	if params.has("mute"):
		AudioServer.set_bus_mute(bus_idx, bool(params.get("mute")))
	if params.has("solo"):
		AudioServer.set_bus_solo(bus_idx, bool(params.get("solo")))

	return get_audio_info({"bus_name": bus_name})


func get_audio_bus_layout(_params: Dictionary) -> Dictionary:
	var buses: Array[Dictionary] = []
	for i in range(AudioServer.get_bus_count()):
		buses.append({
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		})
	return {"buses": buses, "count": buses.size()}


func get_audio_info(params: Dictionary) -> Dictionary:
	if params.has("node_path"):
		var node := _ctx.resolve_node(str(params.get("node_path")))
		if node == null:
			return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Audio player not found.")
		return {
			"node_path": _ctx.node_path_relative(node),
			"type": node.get_class(),
			"volume_db": float(node.get("volume_db")),
			"playing": bool(node.get("playing")) if node.get("playing") != null else false,
			"stream": node.stream.resource_path if node.stream else "",
		}

	var bus_name := str(params.get("bus_name", "Master"))
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Bus not found: %s" % bus_name)
	return {
		"bus_name": bus_name,
		"index": bus_idx,
		"volume_db": AudioServer.get_bus_volume_db(bus_idx),
		"mute": AudioServer.is_bus_mute(bus_idx),
		"solo": AudioServer.is_bus_solo(bus_idx),
	}
