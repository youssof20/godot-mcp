## Phase 5 input simulation tools.
## Godot 4.4+ API: Input.parse_input_event(), InputMap
class_name MCPInputTools
extends RefCounted

var _plugin: EditorPlugin
var _ctx: MCPEditorContext


func setup(plugin: EditorPlugin, ctx: MCPEditorContext) -> void:
	_plugin = plugin
	_ctx = ctx


func simulate_key(params: Dictionary) -> Dictionary:
	var keycode := int(params.get("keycode", 0))
	var physical := int(params.get("physical_keycode", 0))
	var pressed := bool(params.get("pressed", true))
	var shift := bool(params.get("shift", false))
	var ctrl := bool(params.get("ctrl", false))
	var alt := bool(params.get("alt", false))

	if keycode == 0 and physical == 0:
		var key_name := str(params.get("key", "")).strip_edges()
		if key_name.is_empty():
			return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Provide 'key' or 'keycode'.")
		keycode = _key_from_name(key_name)
		if keycode == 0:
			return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Unknown key: %s" % key_name)

	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	if physical > 0:
		ev.physical_keycode = physical as Key
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	ev.alt_pressed = alt
	Input.parse_input_event(ev)

	return {"simulated": true, "type": "key", "keycode": keycode, "pressed": pressed}


func simulate_mouse_click(params: Dictionary) -> Dictionary:
	var x := float(params.get("x", 0))
	var y := float(params.get("y", 0))
	var button := int(params.get("button", MOUSE_BUTTON_LEFT))
	var pressed := bool(params.get("pressed", true))
	var ev := InputEventMouseButton.new()
	ev.position = Vector2(x, y)
	ev.global_position = Vector2(x, y)
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	return {"simulated": true, "type": "mouse_click", "x": x, "y": y, "button": button}


func simulate_mouse_move(params: Dictionary) -> Dictionary:
	var x := float(params.get("x", 0))
	var y := float(params.get("y", 0))
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(x, y)
	ev.global_position = Vector2(x, y)
	Input.parse_input_event(ev)
	return {"simulated": true, "type": "mouse_move", "x": x, "y": y}


func simulate_action(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "")).strip_edges()
	if action.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'action' is required.")
	if not InputMap.has_action(action):
		return MCPErrorCodes.make_error(MCPErrorCodes.NOT_FOUND, "Input action not found: %s" % action)

	var pressed := bool(params.get("pressed", true))
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	return {"simulated": true, "type": "action", "action": action, "pressed": pressed}


func simulate_sequence(params: Dictionary) -> Dictionary:
	var steps: Array = params.get("steps", [])
	if steps.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'steps' array required.")

	var results: Array[Dictionary] = []
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = step
		var delay_ms := int(d.get("delay_ms", 0))
		if delay_ms > 0:
			OS.delay_msec(clampi(delay_ms, 0, 5000))

		var step_type := str(d.get("type", "")).to_lower()
		var result: Variant = null
		match step_type:
			"key":
				result = simulate_key(d)
			"mouse_click":
				result = simulate_mouse_click(d)
			"mouse_move":
				result = simulate_mouse_move(d)
			"action":
				result = simulate_action(d)
			_:
				result = MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "Unknown step type: %s" % step_type)

		if result is Dictionary and result.get("ok") == false:
			return result
		results.append(result if result is Dictionary else {"ok": true})

	return {"simulated": true, "steps_run": results.size(), "results": results}


func get_input_actions(_params: Dictionary) -> Dictionary:
	var actions: Array[Dictionary] = []
	for action in InputMap.get_actions():
		var events: Array = InputMap.action_get_events(action)
		actions.append({
			"name": action,
			"deadzone": InputMap.action_get_deadzone(action),
			"event_count": events.size(),
		})
	return {"actions": actions, "count": actions.size()}


func set_input_action(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "")).strip_edges()
	if action.is_empty():
		return MCPErrorCodes.make_error(MCPErrorCodes.INVALID_PARAMS, "'action' is required.")

	var existed := InputMap.has_action(action)
	if not existed and bool(params.get("create", true)):
		InputMap.add_action(action, float(params.get("deadzone", 0.5)))

	if params.has("events"):
		var events: Array = params["events"]
		if bool(params.get("replace_events", false)):
			for ev in InputMap.action_get_events(action):
				InputMap.action_erase_event(action, ev)
		for ev_data in events:
			if typeof(ev_data) != TYPE_DICTIONARY:
				continue
			var built := _build_input_event(ev_data)
			if built != null:
				InputMap.action_add_event(action, built)

	ProjectSettings.save()

	return {
		"action": action,
		"exists": InputMap.has_action(action),
		"event_count": InputMap.action_get_events(action).size(),
		"note": "InputMap changes saved to project.godot.",
	}


func _key_from_name(name: String) -> int:
	var upper := name.to_upper()
	match upper:
		"SPACE":
			return KEY_SPACE
		"ENTER", "RETURN":
			return KEY_ENTER
		"ESCAPE", "ESC":
			return KEY_ESCAPE
		"UP":
			return KEY_UP
		"DOWN":
			return KEY_DOWN
		"LEFT":
			return KEY_LEFT
		"RIGHT":
			return KEY_RIGHT
		_:
			if upper.length() == 1:
				return upper.unicode_at(0)
			return 0


func _build_input_event(data: Dictionary) -> InputEvent:
	var kind := str(data.get("type", "key")).to_lower()
	match kind:
		"key":
			var ev := InputEventKey.new()
			ev.keycode = _key_from_name(str(data.get("key", ""))) as Key
			ev.pressed = bool(data.get("pressed", true))
			return ev
		"mouse_button":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(data.get("button", MOUSE_BUTTON_LEFT))
			mb.pressed = bool(data.get("pressed", true))
			return mb
		"action":
			var ac := InputEventAction.new()
			ac.action = str(data.get("action", ""))
			ac.pressed = bool(data.get("pressed", true))
			return ac
		_:
			return null
