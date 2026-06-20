## Routes WebSocket tool method names to GDScript handlers.
## Godot 4.4+ assumption: EditorPlugin context passed in at setup.
class_name MCPToolRouter
extends RefCounted

const PLUGIN_VERSION := "0.1.0"

const IMPLEMENTED_TOOLS: Array[String] = [
	"godot_ping",
	"get_connection_status",
	"list_available_tools",
	"get_project_info",
	"get_filesystem_tree",
	"search_files",
	"get_project_settings",
	"uid_to_project_path",
	"project_path_to_uid",
	"get_scene_tree",
	"get_scene_file_content",
	"get_node_properties",
	"list_scripts",
	"read_script",
	"get_editor_errors",
	"get_output_log",
	"create_scene",
	"open_scene",
	"save_scene",
	"delete_scene",
	"add_node",
	"delete_node",
	"duplicate_node",
	"move_node",
	"rename_node",
	"update_property",
	"add_resource",
	"set_anchor_preset",
	"create_script",
	"edit_script",
	"attach_script",
	"validate_script",
	"search_in_files",
	"reload_project",
	"connect_signal",
	"disconnect_signal",
	"get_signals",
	"get_node_groups",
	"set_node_groups",
	"find_nodes_in_group",
	"read_resource",
	"edit_resource",
	"create_resource",
	"get_resource_preview",
	"add_autoload",
	"remove_autoload",
	"find_node_references",
	"find_script_references",
	"find_resource_references",
	"get_scene_dependencies",
	"detect_circular_dependencies",
	"play_scene",
	"stop_scene",
	"get_runtime_status",
	"get_game_scene_tree",
	"get_game_node_properties",
	"set_game_node_property",
	"execute_game_script",
	"batch_get_properties",
	"find_nodes_by_script",
	"get_autoload",
	"find_ui_elements",
	"click_button_by_text",
	"wait_for_node",
	"find_nearby_nodes",
	"navigate_to",
	"move_to",
	"simulate_key",
	"simulate_mouse_click",
	"simulate_mouse_move",
	"simulate_action",
	"simulate_sequence",
	"get_input_actions",
	"set_input_action",
	"get_editor_screenshot",
	"get_game_screenshot",
	"capture_frames",
	"compare_screenshots",
	"start_recording",
	"stop_recording",
	"replay_recording",
	"run_test_scenario",
	"assert_node_state",
	"assert_screen_text",
	"run_stress_test",
	"get_test_report",
	"monitor_properties",
	"list_animations",
	"create_animation",
	"add_animation_track",
	"set_animation_keyframe",
	"get_animation_info",
	"remove_animation",
	"create_animation_tree",
	"get_animation_tree_structure",
	"tilemap_set_cell",
	"tilemap_fill_rect",
	"tilemap_get_cell",
	"tilemap_clear",
	"tilemap_get_info",
	"tilemap_get_used_cells",
]

var _plugin: EditorPlugin
var _websocket_server: Node
var _server_start_time: float
var _log_capture: MCPLogCapture

var _project_tools: MCPProjectTools
var _scene_tools: MCPSceneTools
var _node_tools: MCPNodeTools
var _script_tools: MCPScriptTools
var _editor_tools: MCPEditorTools
var _resource_tools: MCPResourceTools
var _batch_tools: MCPBatchRefactorTools
var _runtime_tools: MCPRuntimeTools
var _input_tools: MCPInputTools
var _testing_qa_tools: MCPTestingQaTools
var _animation_tools: MCPAnimationTools
var _animation_tree_tools: MCPAnimationTreeTools
var _tilemap_tools: MCPTilemapTools
var _frame_recorder: MCPFrameRecorder
var _ctx: MCPEditorContext


func setup(
	plugin: EditorPlugin,
	websocket_server: Node,
	server_start_time: float,
	log_capture: MCPLogCapture,
	frame_recorder: MCPFrameRecorder
) -> void:
	_plugin = plugin
	_websocket_server = websocket_server
	_server_start_time = server_start_time
	_log_capture = log_capture

	_ctx = MCPEditorContext.new()
	_ctx.setup(plugin)

	_project_tools = MCPProjectTools.new()
	_project_tools.setup(plugin)
	_scene_tools = MCPSceneTools.new()
	_scene_tools.setup(plugin, _ctx)
	_node_tools = MCPNodeTools.new()
	_node_tools.setup(plugin, _ctx)
	_script_tools = MCPScriptTools.new()
	_script_tools.setup(plugin, _ctx)
	_editor_tools = MCPEditorTools.new()
	_editor_tools.setup(plugin, _ctx, log_capture)
	_resource_tools = MCPResourceTools.new()
	_resource_tools.setup(plugin, _ctx)
	_batch_tools = MCPBatchRefactorTools.new()
	_batch_tools.setup(plugin, _ctx)
	_runtime_tools = MCPRuntimeTools.new()
	_runtime_tools.setup(plugin, _ctx)
	_input_tools = MCPInputTools.new()
	_input_tools.setup(plugin, _ctx)

	_frame_recorder = frame_recorder
	var runtime_helper := MCPRuntimeHelper.new()
	runtime_helper.setup(_ctx)
	_testing_qa_tools = MCPTestingQaTools.new()
	_testing_qa_tools.setup(plugin, _ctx, runtime_helper, self, _frame_recorder)
	_frame_recorder.setup(Callable(_testing_qa_tools, "capture_for_recorder"))

	_animation_tools = MCPAnimationTools.new()
	_animation_tools.setup(plugin, _ctx)
	_animation_tree_tools = MCPAnimationTreeTools.new()
	_animation_tree_tools.setup(plugin, _ctx)
	_tilemap_tools = MCPTilemapTools.new()
	_tilemap_tools.setup(plugin, _ctx)


func route(method: String, params: Dictionary) -> Dictionary:
	match method:
		"godot_ping":
			return _success(_godot_ping(params))
		"get_connection_status":
			return _success(_get_connection_status(params))
		"list_available_tools":
			return _success(_list_available_tools(params))
		"get_project_info":
			return _dispatch(_project_tools.get_project_info(params))
		"get_filesystem_tree":
			return _dispatch(_project_tools.get_filesystem_tree(params))
		"search_files":
			return _dispatch(_project_tools.search_files(params))
		"get_project_settings":
			return _dispatch(_project_tools.get_project_settings(params))
		"uid_to_project_path":
			return _dispatch(_project_tools.uid_to_project_path(params))
		"project_path_to_uid":
			return _dispatch(_project_tools.project_path_to_uid(params))
		"get_scene_tree":
			return _dispatch(_scene_tools.get_scene_tree(params))
		"get_scene_file_content":
			return _dispatch(_scene_tools.get_scene_file_content(params))
		"get_node_properties":
			return _dispatch(_node_tools.get_node_properties(params))
		"list_scripts":
			return _dispatch(_script_tools.list_scripts(params))
		"read_script":
			return _dispatch(_script_tools.read_script(params))
		"get_editor_errors":
			return _dispatch(_editor_tools.get_editor_errors(params))
		"get_output_log":
			return _dispatch(_editor_tools.get_output_log(params))
		"create_scene":
			return _dispatch(_scene_tools.create_scene(params))
		"open_scene":
			return _dispatch(_scene_tools.open_scene(params))
		"save_scene":
			return _dispatch(_scene_tools.save_scene(params))
		"delete_scene":
			return _dispatch(_scene_tools.delete_scene(params))
		"add_node":
			return _dispatch(_node_tools.add_node(params))
		"delete_node":
			return _dispatch(_node_tools.delete_node(params))
		"duplicate_node":
			return _dispatch(_node_tools.duplicate_node(params))
		"move_node":
			return _dispatch(_node_tools.move_node(params))
		"rename_node":
			return _dispatch(_node_tools.rename_node(params))
		"update_property":
			return _dispatch(_node_tools.update_property(params))
		"add_resource":
			return _dispatch(_node_tools.add_resource(params))
		"set_anchor_preset":
			return _dispatch(_node_tools.set_anchor_preset(params))
		"create_script":
			return _dispatch(_script_tools.create_script(params))
		"edit_script":
			return _dispatch(_script_tools.edit_script(params))
		"attach_script":
			return _dispatch(_script_tools.attach_script(params))
		"validate_script":
			return _dispatch(_script_tools.validate_script(params))
		"search_in_files":
			return _dispatch(_script_tools.search_in_files(params))
		"reload_project":
			return _dispatch(_editor_tools.reload_project(params))
		"connect_signal":
			return _dispatch(_node_tools.connect_signal(params))
		"disconnect_signal":
			return _dispatch(_node_tools.disconnect_signal(params))
		"get_signals":
			return _dispatch(_node_tools.get_signals(params))
		"get_node_groups":
			return _dispatch(_node_tools.get_node_groups(params))
		"set_node_groups":
			return _dispatch(_node_tools.set_node_groups(params))
		"find_nodes_in_group":
			return _dispatch(_node_tools.find_nodes_in_group(params))
		"read_resource":
			return _dispatch(_resource_tools.read_resource(params))
		"edit_resource":
			return _dispatch(_resource_tools.edit_resource(params))
		"create_resource":
			return _dispatch(_resource_tools.create_resource(params))
		"get_resource_preview":
			return _dispatch(_resource_tools.get_resource_preview(params))
		"add_autoload":
			return _dispatch(_resource_tools.add_autoload(params))
		"remove_autoload":
			return _dispatch(_resource_tools.remove_autoload(params))
		"find_node_references":
			return _dispatch(_batch_tools.find_node_references(params))
		"find_script_references":
			return _dispatch(_batch_tools.find_script_references(params))
		"find_resource_references":
			return _dispatch(_batch_tools.find_resource_references(params))
		"get_scene_dependencies":
			return _dispatch(_batch_tools.get_scene_dependencies(params))
		"detect_circular_dependencies":
			return _dispatch(_batch_tools.detect_circular_dependencies(params))
		"play_scene":
			return _dispatch(_runtime_tools.play_scene(params))
		"stop_scene":
			return _dispatch(_runtime_tools.stop_scene(params))
		"get_runtime_status":
			return _dispatch(_runtime_tools.get_runtime_status(params))
		"get_game_scene_tree":
			return _dispatch(_runtime_tools.get_game_scene_tree(params))
		"get_game_node_properties":
			return _dispatch(_runtime_tools.get_game_node_properties(params))
		"set_game_node_property":
			return _dispatch(_runtime_tools.set_game_node_property(params))
		"execute_game_script":
			return _dispatch(_runtime_tools.execute_game_script(params))
		"batch_get_properties":
			return _dispatch(_runtime_tools.batch_get_properties(params))
		"find_nodes_by_script":
			return _dispatch(_runtime_tools.find_nodes_by_script(params))
		"get_autoload":
			return _dispatch(_runtime_tools.get_autoload(params))
		"find_ui_elements":
			return _dispatch(_runtime_tools.find_ui_elements(params))
		"click_button_by_text":
			return _dispatch(_runtime_tools.click_button_by_text(params))
		"wait_for_node":
			return _dispatch(_runtime_tools.wait_for_node(params))
		"find_nearby_nodes":
			return _dispatch(_runtime_tools.find_nearby_nodes(params))
		"navigate_to":
			return _dispatch(_runtime_tools.navigate_to(params))
		"move_to":
			return _dispatch(_runtime_tools.move_to(params))
		"simulate_key":
			return _dispatch(_input_tools.simulate_key(params))
		"simulate_mouse_click":
			return _dispatch(_input_tools.simulate_mouse_click(params))
		"simulate_mouse_move":
			return _dispatch(_input_tools.simulate_mouse_move(params))
		"simulate_action":
			return _dispatch(_input_tools.simulate_action(params))
		"simulate_sequence":
			return _dispatch(_input_tools.simulate_sequence(params))
		"get_input_actions":
			return _dispatch(_input_tools.get_input_actions(params))
		"set_input_action":
			return _dispatch(_input_tools.set_input_action(params))
		"get_editor_screenshot":
			return _dispatch(_testing_qa_tools.get_editor_screenshot(params))
		"get_game_screenshot":
			return _dispatch(_testing_qa_tools.get_game_screenshot(params))
		"capture_frames":
			return _dispatch(_testing_qa_tools.capture_frames(params))
		"compare_screenshots":
			return _dispatch(_testing_qa_tools.compare_screenshots(params))
		"start_recording":
			return _dispatch(_testing_qa_tools.start_recording(params))
		"stop_recording":
			return _dispatch(_testing_qa_tools.stop_recording(params))
		"replay_recording":
			return _dispatch(_testing_qa_tools.replay_recording(params))
		"run_test_scenario":
			return _dispatch(_testing_qa_tools.run_test_scenario(params))
		"assert_node_state":
			return _dispatch(_testing_qa_tools.assert_node_state(params))
		"assert_screen_text":
			return _dispatch(_testing_qa_tools.assert_screen_text(params))
		"run_stress_test":
			return _dispatch(_testing_qa_tools.run_stress_test(params))
		"get_test_report":
			return _dispatch(_testing_qa_tools.get_test_report(params))
		"monitor_properties":
			return _dispatch(_testing_qa_tools.monitor_properties(params))
		"list_animations":
			return _dispatch(_animation_tools.list_animations(params))
		"create_animation":
			return _dispatch(_animation_tools.create_animation(params))
		"add_animation_track":
			return _dispatch(_animation_tools.add_animation_track(params))
		"set_animation_keyframe":
			return _dispatch(_animation_tools.set_animation_keyframe(params))
		"get_animation_info":
			return _dispatch(_animation_tools.get_animation_info(params))
		"remove_animation":
			return _dispatch(_animation_tools.remove_animation(params))
		"create_animation_tree":
			return _dispatch(_animation_tree_tools.create_animation_tree(params))
		"get_animation_tree_structure":
			return _dispatch(_animation_tree_tools.get_animation_tree_structure(params))
		"tilemap_set_cell":
			return _dispatch(_tilemap_tools.tilemap_set_cell(params))
		"tilemap_fill_rect":
			return _dispatch(_tilemap_tools.tilemap_fill_rect(params))
		"tilemap_get_cell":
			return _dispatch(_tilemap_tools.tilemap_get_cell(params))
		"tilemap_clear":
			return _dispatch(_tilemap_tools.tilemap_clear(params))
		"tilemap_get_info":
			return _dispatch(_tilemap_tools.tilemap_get_info(params))
		"tilemap_get_used_cells":
			return _dispatch(_tilemap_tools.tilemap_get_used_cells(params))
		_:
			return MCPErrorCodes.not_implemented(method)


func _dispatch(result: Variant) -> Dictionary:
	if result is Dictionary and result.get("ok") == false:
		return result
	return _success(result)


func _success(result: Variant) -> Dictionary:
	return {"ok": true, "result": result}


func _godot_ping(_params: Dictionary) -> Dictionary:
	# Godot 4.4+ API: Engine.get_version_info()
	var version_info: Dictionary = Engine.get_version_info()
	var version_string := "%s.%s.%s%s" % [
		version_info.get("major", "?"),
		version_info.get("minor", "?"),
		version_info.get("patch", "?"),
		("-dev.%s" % version_info.get("build", "")) if version_info.get("status", "") == "dev" else "",
	]

	var project_name := str(
		ProjectSettings.get_setting("application/config/name", "Untitled")
	)

	return {
		"pong": true,
		"plugin_version": PLUGIN_VERSION,
		"protocol_version": MCPProtocol.PROTOCOL_VERSION,
		"godot_version": version_string,
		"godot_version_info": version_info,
		"project_name": project_name,
		"project_path": ProjectSettings.globalize_path("res://"),
		"uptime_seconds": Time.get_ticks_msec() / 1000.0 - _server_start_time,
		"editor_hint": Engine.is_editor_hint(),
	}


func _get_connection_status(_params: Dictionary) -> Dictionary:
	var client_count := 0
	var port := 6505
	if _websocket_server and _websocket_server.has_method("get_status"):
		var status: Dictionary = _websocket_server.call("get_status")
		client_count = int(status.get("client_count", 0))
		port = int(status.get("port", 6505))

	return {
		"plugin_enabled": true,
		"plugin_version": PLUGIN_VERSION,
		"connected_clients": client_count,
		"websocket_port": port,
		"uptime_seconds": Time.get_ticks_msec() / 1000.0 - _server_start_time,
		"implemented_tool_count": IMPLEMENTED_TOOLS.size(),
	}


func _list_available_tools(_params: Dictionary) -> Dictionary:
	return {
		"tools": IMPLEMENTED_TOOLS.duplicate(),
		"count": IMPLEMENTED_TOOLS.size(),
		"plugin_version": PLUGIN_VERSION,
		"protocol_version": MCPProtocol.PROTOCOL_VERSION,
	}
