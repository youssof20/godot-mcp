## Frame recorder Node for start_recording / stop_recording.
## Godot 4.4+ assumption: Timer node in editor plugin tree.
class_name MCPFrameRecorder
extends Node

signal recording_stopped(report: Dictionary)

var active := false
var frames: Array[Dictionary] = []
var interval_ms := 200
var target := "editor_2d"
var _timer: Timer
var _capture_fn: Callable


func setup(capture_fn: Callable) -> void:
	_capture_fn = capture_fn
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func start_recording(target_name: String, interval: int) -> void:
	target = target_name
	interval_ms = clampi(interval, 50, 5000)
	frames.clear()
	active = true
	_timer.wait_time = interval_ms / 1000.0
	_timer.start()
	_on_tick()


func stop_recording() -> Dictionary:
	active = false
	_timer.stop()
	var report := {
		"frame_count": frames.size(),
		"frames": frames.duplicate(),
		"target": target,
	}
	recording_stopped.emit(report)
	return report


func _on_tick() -> void:
	if not active or not _capture_fn.is_valid():
		return
	var shot: Variant = _capture_fn.call(target)
	if shot is Dictionary:
		frames.append(shot)
