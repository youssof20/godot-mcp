## Phase 9 profiling tools.
class_name MCPProfilingTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext

const MONITOR_NAMES: Array[String] = [
	"time_fps",
	"time_process",
	"time_physics_process",
	"memory_static",
	"memory_static_max",
	"memory_message_buffer_max",
	"object_count",
	"object_resource_count",
	"object_node_count",
	"render_total_objects_in_frame",
	"render_total_primitives_in_frame",
	"render_total_draw_calls_in_frame",
]


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func get_performance_monitors(params: Dictionary) -> Dictionary:
	var monitors: Array[Dictionary] = []
	var requested: Array = params.get("monitors", MONITOR_NAMES)
	for name in requested:
		var key := str(name).strip_edges().to_upper()
		var enum_val := _monitor_enum(key)
		if enum_val >= 0:
			monitors.append({"name": str(name).to_lower(), "value": Performance.get_monitor(enum_val)})
	return {"monitors": monitors, "count": monitors.size()}


func get_editor_performance(_params: Dictionary) -> Dictionary:
	var root := _ctx.edited_root()
	var node_count := 0
	if root:
		node_count = _count_nodes(root)

	return {
		"fps": Engine.get_frames_per_second(),
		"process_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"memory_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"edited_scene_nodes": node_count,
		"is_playing": _ctx.iface().is_playing_scene(),
	}


func _monitor_enum(name: String) -> int:
	match name:
		"TIME_FPS": return Performance.TIME_FPS
		"TIME_PROCESS": return Performance.TIME_PROCESS
		"TIME_PHYSICS_PROCESS": return Performance.TIME_PHYSICS_PROCESS
		"MEMORY_STATIC": return Performance.MEMORY_STATIC
		"MEMORY_STATIC_MAX": return Performance.MEMORY_STATIC_MAX
		"MEMORY_MESSAGE_BUFFER_MAX": return Performance.MEMORY_MESSAGE_BUFFER_MAX
		"OBJECT_COUNT": return Performance.OBJECT_COUNT
		"OBJECT_RESOURCE_COUNT": return Performance.OBJECT_RESOURCE_COUNT
		"OBJECT_NODE_COUNT": return Performance.OBJECT_NODE_COUNT
		"RENDER_TOTAL_OBJECTS_IN_FRAME": return Performance.RENDER_TOTAL_OBJECTS_IN_FRAME
		"RENDER_TOTAL_PRIMITIVES_IN_FRAME": return Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
		"RENDER_TOTAL_DRAW_CALLS_IN_FRAME": return Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
		_: return -1


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
