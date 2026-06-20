## Phase 6 testing, screenshots, recordings, and QA tools.
class_name MCPTestingQaTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext
var _runtime: MCPRuntimeHelper
var _router: MCPToolRouter
var _recorder: MCPFrameRecorder
var _last_test_report: Dictionary = {}
var _property_monitors: Dictionary = {}


func setup(
	plugin: EditorPlugin,
	ctx: MCPEditorContext,
	runtime: MCPRuntimeHelper,
	router: MCPToolRouter,
	recorder: MCPFrameRecorder
) -> void:
	_plugin = plugin
	_ctx = ctx
	_runtime = runtime
	_router = router
	_recorder = recorder


func get_editor_screenshot(params: Dictionary) -> Dictionary:
	var mode := str(params.get("viewport", "2d")).to_lower()
	var save := bool(params.get("save", false))
	var img: Image = null

	match mode:
		"2d":
			# Godot 4.4+ API: EditorInterface.get_editor_viewport_2d()
			img = MCPScreenshotHelper.capture_subviewport(_ctx.iface().get_editor_viewport_2d())
		"3d":
			var idx := clampi(int(params.get("viewport_3d_index", 0)), 0, 3)
			img = MCPScreenshotHelper.capture_subviewport(_ctx.iface().get_editor_viewport_3d(idx))
		_:
			return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "viewport must be '2d' or '3d'")

	if img == null or img.is_empty():
		return MCPErrorCodes.make_error(
			MCPErrorCodes.GODOT_API_ERROR,
			"Failed to capture editor viewport.",
			"Ensure a scene is open in the %s editor viewport." % mode,
		)

	return _format_screenshot_result(img, "editor_%s" % mode, save)


func get_game_screenshot(params: Dictionary) -> Dictionary:
	if not _runtime.is_playing():
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Game is not running.")

	var root := _runtime.find_runtime_root()
	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.RUNTIME_NOT_RUNNING, "Runtime root not found.")

	var save := bool(params.get("save", false))
	var img := MCPScreenshotHelper.capture_runtime_root(root)
	if img == null or img.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Failed to capture game viewport.")

	return _format_screenshot_result(img, "game", save)


func capture_frames(params: Dictionary) -> Dictionary:
	var count := clampi(int(params.get("count", 3)), 1, 30)
	var delay_ms := clampi(int(params.get("delay_ms", 200)), 50, 5000)
	var target := str(params.get("target", "editor_2d")).strip_edges()
	var save := bool(params.get("save", false))

	var frames: Array[Dictionary] = []
	for i in range(count):
		var shot := _capture_target(target, save, "frame_%d_%d" % [Time.get_ticks_msec(), i])
		if shot.is_empty():
			return MCPErrorCodes.make_error(MCPErrorCodes.GODOT_API_ERROR, "Capture failed at frame %d" % i)
		frames.append(shot)
		if i < count - 1:
			OS.delay_msec(delay_ms)

	return {"frames": frames, "count": frames.size(), "target": target}


func compare_screenshots(params: Dictionary) -> Dictionary:
	var path_a := MCPPathUtils.normalize_storage_path(str(params.get("image_a", "")))
	var path_b := MCPPathUtils.normalize_storage_path(str(params.get("image_b", "")))
	var max_ratio := float(params.get("max_diff_ratio", 0.0))

	if path_a.is_empty() or path_b.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'image_a' and 'image_b' required.")

	var img_a := MCPScreenshotHelper.load_image_from_path(path_a)
	var img_b := MCPScreenshotHelper.load_image_from_path(path_b)
	if img_a == null or img_b == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Could not load one or both images.")

	var cmp := MCPScreenshotHelper.compare_images(img_a, img_b)
	cmp["image_a"] = path_a
	cmp["image_b"] = path_b
	cmp["passed"] = float(cmp.get("diff_ratio", 1.0)) <= max_ratio
	return cmp


func start_recording(params: Dictionary) -> Dictionary:
	if _recorder.active:
		return MCPErrorCodes.make_error(MCPErrorCodes.ALREADY_EXISTS, "Recording already active.")

	var target := str(params.get("target", "editor_2d"))
	var interval_ms := int(params.get("interval_ms", 200))
	_recorder.start_recording(target, interval_ms)
	return {"recording": true, "target": target, "interval_ms": interval_ms}


func stop_recording(_params: Dictionary) -> Dictionary:
	if not _recorder.active:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No active recording.")
	return _recorder.stop_recording()


func replay_recording(_params: Dictionary) -> Dictionary:
	if _recorder.frames.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No recorded frames. Run start_recording first.")
	return {
		"frames": _recorder.frames.duplicate(),
		"count": _recorder.frames.size(),
		"note": "Returns captured frame metadata from the last recording session.",
	}


func run_test_scenario(params: Dictionary) -> Dictionary:
	var steps: Array = params.get("steps", [])
	if steps.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'steps' array required.")

	var results: Array[Dictionary] = []
	var passed := 0
	var failed := 0

	for i in range(steps.size()):
		var step = steps[i]
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = step
		var method := str(d.get("tool", d.get("method", "")))
		var step_params: Dictionary = d.get("params", {})
		var started := Time.get_ticks_msec()
		var response := _router.route(method, step_params)
		var elapsed := Time.get_ticks_msec() - started
		var ok := response.get("ok", false)
		if ok:
			passed += 1
		else:
			failed += 1
		results.append({
			"index": i,
			"tool": method,
			"ok": ok,
			"elapsed_ms": elapsed,
			"response": response,
		})

	_last_test_report = {
		"scenario": str(params.get("name", "unnamed")),
		"passed": passed,
		"failed": failed,
		"total": results.size(),
		"results": results,
		"timestamp": Time.get_unix_time_from_system(),
	}

	return _last_test_report


func assert_node_state(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "")).strip_edges()
	var property := str(params.get("property", "")).strip_edges()
	if node_path.is_empty() or property.is_empty() or not params.has("expected"):
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "node_path, property, expected required.")

	var use_runtime := bool(params.get("runtime", false))
	var node: Node = null
	if use_runtime:
		node = _runtime.resolve_runtime_node(node_path)
	else:
		node = _ctx.resolve_node(node_path)

	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found.")

	var actual = node.get(property)
	var expected = MCPTypeParser.parse_value(params["expected"])
	var passed := str(actual) == str(expected)

	return {
		"passed": passed,
		"node_path": node_path,
		"property": property,
		"expected": expected,
		"actual": actual,
	}


func assert_screen_text(params: Dictionary) -> Dictionary:
	var text := str(params.get("text", "")).strip_edges()
	if text.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'text' required.")

	var use_runtime := bool(params.get("runtime", false))
	var root: Node = null
	if use_runtime:
		root = _runtime.find_runtime_root()
	else:
		root = _ctx.edited_root()

	if root == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No scene available.")

	var matches: Array[Dictionary] = []
	_find_text_nodes(root, text, root, matches)

	return {
		"passed": not matches.is_empty(),
		"text": text,
		"matches": matches,
		"count": matches.size(),
	}


func run_stress_test(params: Dictionary) -> Dictionary:
	var tool := str(params.get("tool", "godot_ping"))
	var iterations := clampi(int(params.get("iterations", 50)), 1, 500)
	var tool_params: Dictionary = params.get("params", {})

	var times: Array[int] = []
	var failures := 0

	for i in range(iterations):
		var t0 := Time.get_ticks_msec()
		var response := _router.route(tool, tool_params)
		var elapsed := Time.get_ticks_msec() - t0
		times.append(elapsed)
		if not response.get("ok", false):
			failures += 1

	times.sort()
	var total := 0
	for t in times:
		total += t

	_last_test_report = {
		"type": "stress_test",
		"tool": tool,
		"iterations": iterations,
		"failures": failures,
		"avg_ms": float(total) / float(iterations) if iterations > 0 else 0.0,
		"min_ms": times[0] if not times.is_empty() else 0,
		"max_ms": times[times.size() - 1] if not times.is_empty() else 0,
		"timestamp": Time.get_unix_time_from_system(),
	}

	return _last_test_report


func get_test_report(_params: Dictionary) -> Dictionary:
	if _last_test_report.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "No test report yet. Run run_test_scenario or run_stress_test.")
	return _last_test_report.duplicate(true)


func monitor_properties(params: Dictionary) -> Dictionary:
	var monitor_id := str(params.get("monitor_id", "default"))
	var action := str(params.get("action", "snapshot")).to_lower()

	if action == "clear":
		_property_monitors.erase(monitor_id)
		return {"monitor_id": monitor_id, "cleared": true}

	var node_path := str(params.get("node_path", "")).strip_edges()
	var props: Array = params.get("properties", [])
	if node_path.is_empty() or props.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "node_path and properties required.")

	var use_runtime := bool(params.get("runtime", false))
	var node: Node = null
	if use_runtime:
		node = _runtime.resolve_runtime_node(node_path)
	else:
		node = _ctx.resolve_node(node_path)
	if node == null:
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Node not found.")

	var snapshot: Dictionary = {}
	for p in props:
		snapshot[str(p)] = str(node.get(str(p)))

	if action == "diff":
		var prev: Dictionary = _property_monitors.get(monitor_id, {})
		var changes: Dictionary = {}
		for key in snapshot.keys():
			if not prev.has(key) or str(prev[key]) != str(snapshot[key]):
				changes[key] = {"from": prev.get(key), "to": snapshot[key]}
		_property_monitors[monitor_id] = snapshot
		return {"monitor_id": monitor_id, "action": "diff", "changes": changes}

	_property_monitors[monitor_id] = snapshot
	return {"monitor_id": monitor_id, "action": "snapshot", "values": snapshot}


func capture_for_recorder(target_name: String) -> Dictionary:
	return _capture_target(target_name, true, "rec_%d" % Time.get_ticks_msec())


func _capture_target(target: String, save: bool, filename: String) -> Dictionary:
	match target:
		"editor_2d":
			var img := MCPScreenshotHelper.capture_subviewport(_ctx.iface().get_editor_viewport_2d())
			if img == null:
				return {}
			return _format_screenshot_result(img, "editor_2d", save, filename)
		"editor_3d":
			return _editor_shot_3d(save, filename)
		"game":
			return _game_shot_result(save, filename)
		_:
			return {}


func _editor_shot_3d(save: bool, filename: String) -> Dictionary:
	var img := MCPScreenshotHelper.capture_subviewport(_ctx.iface().get_editor_viewport_3d(0))
	if img == null:
		return {}
	return _format_screenshot_result(img, "editor_3d", save, filename)


func _game_shot_result(save: bool, filename: String) -> Dictionary:
	if not _runtime.is_playing():
		return {}
	var root := _runtime.find_runtime_root()
	var img := MCPScreenshotHelper.capture_runtime_root(root)
	if img == null:
		return {}
	return _format_screenshot_result(img, "game", save, filename)


func _format_screenshot_result(img: Image, label: String, save: bool, filename: String = "") -> Dictionary:
	var fn := filename if not filename.is_empty() else "%s_%d.png" % [label, Time.get_ticks_msec()]
	var saved_path := ""
	if save:
		saved_path = MCPScreenshotHelper.save_image_png(img, fn)
	return {
		"width": img.get_width(),
		"height": img.get_height(),
		"format": "png",
		"png_base64": MCPScreenshotHelper.image_to_png_base64(img),
		"saved_path": saved_path,
	}


func _find_text_nodes(node: Node, needle: String, root: Node, out: Array) -> void:
	if node is Label:
		var lbl := node as Label
		if needle in lbl.text:
			out.append({"path": _ctx.node_path_relative_to(lbl, root), "text": lbl.text, "type": "Label"})
	elif node is Button:
		var btn := node as Button
		if needle in btn.text:
			out.append({"path": _ctx.node_path_relative_to(btn, root), "text": btn.text, "type": "Button"})
	for child in node.get_children():
		_find_text_nodes(child, needle, root, out)
