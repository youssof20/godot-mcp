@tool
extends VBoxContainer

var websocket_server: Node = null
var command_router: Node = null
var activity_log: Node = null

const MAX_LOG_ENTRIES := 200
const COLOR_CONNECTED := Color(0.2, 0.9, 0.2)
const COLOR_DISCONNECTED := Color(0.9, 0.2, 0.2)
const COLOR_STALE := Color(1.0, 0.7, 0.2)
const COLOR_SUCCESS := Color(0.6, 1, 0.6)
const COLOR_ERROR := Color(1, 0.6, 0.6)
const COLOR_DIM := Color(0.6, 0.6, 0.6)
const COLOR_WARN := Color(1.0, 0.85, 0.4)

const BASE_PORT := 6505
const MAX_PORT := 6509

# Header
var _status_icon: Label
var _status_label: Label
var _client_count_label: Label

# Tabs
var _tab_container: TabContainer

# Activity tab
var _show_params_check: CheckBox
var _show_full_check: CheckBox
var _log_container: VBoxContainer
var _log_scroll: ScrollContainer
var _entry_rows: Array[VBoxContainer] = []

# Clients tab
var _port_labels: Dictionary = {}  # port -> {icon: Label, label: Label}

# Tools tab
var _filter_edit: LineEdit
var _tools_container: VBoxContainer
var _tool_checkboxes: Dictionary = {}  # method_name -> CheckBox


func _ready() -> void:
	_build_ui()


func setup(ws_server: Node, cmd_router: Node = null, act_log: Node = null) -> void:
	websocket_server = ws_server
	command_router = cmd_router
	activity_log = act_log

	if websocket_server:
		websocket_server.client_connected.connect(_on_client_connected)
		websocket_server.client_disconnected.connect(_on_client_disconnected)
		if websocket_server.has_signal("activity_logged"):
			websocket_server.activity_logged.connect(_on_activity_logged)
		elif websocket_server.has_signal("command_completed"):
			websocket_server.command_completed.connect(_on_command_completed_legacy)

	if command_router:
		_populate_tools_list()


func _build_ui() -> void:
	# Header bar
	var header := HBoxContainer.new()
	add_child(header)

	_status_icon = Label.new()
	_status_icon.text = "●"
	_status_icon.add_theme_color_override("font_color", COLOR_DISCONNECTED)
	header.add_child(_status_icon)

	_status_label = Label.new()
	_status_label.text = " MCP Pro: Waiting for connection..."
	header.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_client_count_label = Label.new()
	_client_count_label.text = "Clients: 0"
	header.add_child(_client_count_label)

	var sep := HSeparator.new()
	add_child(sep)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)

	_build_activity_tab()
	_build_clients_tab()
	_build_tools_tab()


func _build_activity_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Activity"
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(vbox)

	var controls := HBoxContainer.new()
	vbox.add_child(controls)

	_show_full_check = CheckBox.new()
	_show_full_check.text = "Full JSON"
	_show_full_check.tooltip_text = "Show complete request/response JSON (no truncation)"
	_show_full_check.button_pressed = false
	_show_full_check.toggled.connect(_on_detail_options_changed)
	controls.add_child(_show_full_check)

	_show_params_check = CheckBox.new()
	_show_params_check.text = "Params"
	_show_params_check.tooltip_text = "Show request parameters for each tool call"
	_show_params_check.button_pressed = true
	_show_params_check.toggled.connect(_on_detail_options_changed)
	controls.add_child(_show_params_check)

	var ctrl_spacer := Control.new()
	ctrl_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(ctrl_spacer)

	var copy_all_btn := Button.new()
	copy_all_btn.text = "Copy All"
	copy_all_btn.tooltip_text = "Copy entire activity log to system clipboard"
	copy_all_btn.pressed.connect(_on_copy_all)
	controls.add_child(copy_all_btn)

	var copy_err_btn := Button.new()
	copy_err_btn.text = "Copy Errors"
	copy_err_btn.tooltip_text = "Copy only failed tool calls"
	copy_err_btn.pressed.connect(_on_copy_errors)
	controls.add_child(copy_err_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.tooltip_text = "Save log to user://mcp_activity_log.txt"
	save_btn.pressed.connect(_on_save_log)
	controls.add_child(save_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_log)
	controls.add_child(clear_btn)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.custom_minimum_size.y = 80
	vbox.add_child(_log_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_container)


func _build_clients_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Clients"
	_tab_container.add_child(vbox)

	for p in range(BASE_PORT, MAX_PORT + 1):
		var row := HBoxContainer.new()
		vbox.add_child(row)

		var icon := Label.new()
		icon.text = "○"
		icon.add_theme_color_override("font_color", COLOR_DISCONNECTED)
		row.add_child(icon)

		var lbl := Label.new()
		lbl.text = "  Port %d  —  Disconnected" % p
		row.add_child(lbl)

		_port_labels[p] = {"icon": icon, "label": lbl}


func _build_tools_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Tools"
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(vbox)

	var controls := HBoxContainer.new()
	vbox.add_child(controls)

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "Filter tools..."
	_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_edit.text_changed.connect(_on_filter_changed)
	controls.add_child(_filter_edit)

	var enable_all_btn := Button.new()
	enable_all_btn.text = "Enable All"
	enable_all_btn.pressed.connect(_on_enable_all)
	controls.add_child(enable_all_btn)

	var disable_all_btn := Button.new()
	disable_all_btn.text = "Disable All"
	disable_all_btn.pressed.connect(_on_disable_all)
	controls.add_child(disable_all_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 80
	vbox.add_child(scroll)

	_tools_container = VBoxContainer.new()
	_tools_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tools_container)


func _populate_tools_list() -> void:
	if not command_router:
		return

	for child in _tools_container.get_children():
		child.queue_free()
	_tool_checkboxes.clear()

	var methods: Array = command_router.get_available_methods()
	methods.sort()

	for method_name: String in methods:
		var cb := CheckBox.new()
		cb.text = method_name
		cb.button_pressed = not command_router.is_tool_disabled(method_name)
		cb.toggled.connect(_on_tool_toggled.bind(method_name))
		_tools_container.add_child(cb)
		_tool_checkboxes[method_name] = cb


func _process(_delta: float) -> void:
	if not websocket_server:
		return

	var count: int = websocket_server.get_client_count()
	_client_count_label.text = "Clients: %d" % count

	var any_stale := false
	if websocket_server.has_method("is_port_stale"):
		for p in range(BASE_PORT, MAX_PORT + 1):
			if websocket_server.is_port_stale(p):
				any_stale = true
				break

	if count > 0:
		_status_icon.add_theme_color_override("font_color", COLOR_CONNECTED)
		_status_label.text = " MCP Pro: Connected"
	elif any_stale:
		_status_icon.add_theme_color_override("font_color", COLOR_STALE)
		_status_label.text = " MCP Pro: Reconnecting (stale connection)..."
	else:
		_status_icon.add_theme_color_override("font_color", COLOR_DISCONNECTED)
		_status_label.text = " MCP Pro: Waiting for connection..."

	_update_clients_tab()


func _update_clients_tab() -> void:
	var connected_ports: Array[int] = []
	if websocket_server.has_method("get_connected_ports"):
		connected_ports = websocket_server.get_connected_ports()

	for p: int in _port_labels:
		var info: Dictionary = _port_labels[p]
		var icon: Label = info["icon"]
		var lbl: Label = info["label"]

		var is_stale := false
		if websocket_server.has_method("is_port_stale"):
			is_stale = websocket_server.is_port_stale(p)

		if p in connected_ports:
			var time_str := ""
			if websocket_server.has_method("get_port_connect_time"):
				var elapsed: float = websocket_server.get_port_connect_time(p)
				if elapsed >= 0:
					var mins := int(elapsed) / 60
					var secs := int(elapsed) % 60
					time_str = "  (%dm %02ds)" % [mins, secs]

			var idle_str := ""
			if websocket_server.has_method("get_port_idle_time"):
				var idle: float = websocket_server.get_port_idle_time(p)
				if idle >= 2.0:
					idle_str = "  · idle %.0fs" % idle

			icon.text = "●"
			icon.add_theme_color_override("font_color", COLOR_CONNECTED)
			lbl.text = "  Port %d  —  Connected%s%s" % [p, time_str, idle_str]
		elif is_stale:
			icon.text = "◐"
			icon.add_theme_color_override("font_color", COLOR_STALE)
			lbl.text = "  Port %d  —  Stale (reconnecting)" % p
		else:
			icon.text = "○"
			icon.add_theme_color_override("font_color", COLOR_DISCONNECTED)
			lbl.text = "  Port %d  —  Disconnected" % p


# --- Activity ---

func _on_client_connected() -> void:
	_add_simple_log("Client connected", COLOR_CONNECTED)


func _on_client_disconnected() -> void:
	_add_simple_log("Client disconnected", COLOR_DISCONNECTED)


func _on_activity_logged(entry: Dictionary) -> void:
	_add_log_entry(entry)


func _on_command_completed_legacy(method: String, ok: bool, response: String, source_port: int) -> void:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(),
		"method": method,
		"ok": ok,
		"port": source_port,
		"response": response,
		"duration_ms": 0,
		"params": {},
	}
	if not ok:
		var parsed := JSON.new()
		if parsed.parse(response) == OK and parsed.data is Dictionary:
			entry["error_message"] = str(parsed.data.get("message", ""))
	_add_log_entry(entry)


func _on_clear_log() -> void:
	for child in _log_container.get_children():
		child.queue_free()
	_entry_rows.clear()
	if activity_log and activity_log.has_method("clear"):
		activity_log.clear()


func _on_detail_options_changed(_on: bool) -> void:
	for row in _entry_rows:
		if not is_instance_valid(row):
			continue
		var details: Node = row.get_node_or_null("Details")
		if details:
			_rebuild_entry_details(row, details.get_meta("entry", {}))


func _on_copy_all() -> void:
	var text := _export_log_text(false)
	if text.is_empty():
		_clipboard_set("(MCP activity log is empty)")
	else:
		_clipboard_set(text)


func _on_copy_errors() -> void:
	var text := _export_log_text(true)
	if text.is_empty():
		_clipboard_set("(No MCP errors in log)")
	else:
		_clipboard_set(text)


func _on_save_log() -> void:
	if activity_log and activity_log.has_method("save_to_file"):
		var result: Dictionary = activity_log.save_to_file(
			"user://mcp_activity_log.txt",
			_show_params_check.button_pressed,
			true,
			_show_full_check.button_pressed,
			false
		)
		if result.get("saved", false):
			_add_simple_log("Saved log → %s" % result.get("path", ""), COLOR_WARN)
		else:
			_add_simple_log("Save failed: %s" % result.get("error", "?"), COLOR_ERROR)
	else:
		_clipboard_set(_export_log_text(false))
		_add_simple_log("Saved via clipboard (no log node)", COLOR_WARN)


func _export_log_text(errors_only: bool) -> String:
	if activity_log and activity_log.has_method("export_text"):
		return activity_log.export_text(
			_show_params_check.button_pressed,
			true,
			_show_full_check.button_pressed,
			errors_only,
			-1
		)
	var lines: PackedStringArray = []
	for row in _entry_rows:
		if not is_instance_valid(row):
			continue
		var entry: Dictionary = row.get_meta("entry", {})
		if errors_only and entry.get("ok", true):
			continue
		lines.append(_format_summary_line(entry))
	return "\n".join(lines)


func _add_simple_log(text: String, color: Color) -> void:
	_add_log_entry({
		"timestamp": Time.get_time_string_from_system(),
		"method": text,
		"ok": true,
		"is_system": true,
	}, color)


func _add_log_entry(entry: Dictionary, override_color: Color = Color.WHITE) -> void:
	if _log_container == null:
		return

	var is_system: bool = entry.get("is_system", false)
	var ok: bool = entry.get("ok", true)
	var color := override_color
	if override_color == Color.WHITE:
		color = COLOR_SUCCESS if ok else COLOR_ERROR

	var row := VBoxContainer.new()
	row.set_meta("entry", entry)
	_entry_rows.append(row)
	_log_container.add_child(row)

	var header_row := HBoxContainer.new()
	row.add_child(header_row)

	var summary := Label.new()
	summary.text = _format_summary_line(entry) if not is_system else "[%s] %s" % [
		entry.get("timestamp", ""),
		entry.get("method", ""),
	]
	summary.add_theme_color_override("font_color", color)
	summary.add_theme_font_size_override("font_size", 12)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_row.add_child(summary)

	if not is_system:
		var copy_btn := Button.new()
		copy_btn.text = "Copy"
		copy_btn.tooltip_text = "Copy this entry to clipboard"
		copy_btn.pressed.connect(_on_copy_entry.bind(entry))
		header_row.add_child(copy_btn)

	var details := VBoxContainer.new()
	details.name = "Details"
	details.set_meta("entry", entry)
	row.add_child(details)
	_rebuild_entry_details(row, entry)

	while _log_container.get_child_count() > MAX_LOG_ENTRIES:
		var old: Node = _log_container.get_child(0)
		_log_container.remove_child(old)
		_entry_rows.erase(old)
		old.queue_free()

	_auto_scroll.call_deferred()


func _format_summary_line(entry: Dictionary) -> String:
	var status := "OK" if entry.get("ok", false) else "ERR"
	var dur := ""
	if entry.has("duration_ms") and int(entry["duration_ms"]) > 0:
		dur = " %dms" % int(entry["duration_ms"])
	var port := ""
	if entry.has("port"):
		port = " · p%d" % int(entry["port"])
	var err := ""
	if not entry.get("ok", true) and not str(entry.get("error_message", "")).is_empty():
		err = " — %s" % entry["error_message"]
	return "[%s] [%s] %s%s%s%s" % [
		_format_time(entry.get("timestamp", "")),
		status,
		entry.get("method", "?"),
		port,
		dur,
		err,
	]


func _format_time(timestamp: String) -> String:
	if timestamp.is_empty():
		return Time.get_time_string_from_system()
	# datetime string → show time portion only when long
	var parts := timestamp.split(" ")
	if parts.size() >= 2:
		return parts[1]
	return timestamp


func _rebuild_entry_details(row: VBoxContainer, entry: Dictionary) -> void:
	var details: Node = row.get_node_or_null("Details")
	if details == null:
		return

	for child in details.get_children():
		child.queue_free()

	if entry.get("is_system", false):
		return

	var show_params := _show_params_check.button_pressed if _show_params_check else true
	var full := _show_full_check.button_pressed if _show_full_check else false

	if show_params and entry.has("params"):
		_add_detail_block(details, "params", entry["params"], full)

	if entry.has("response"):
		_add_detail_block(details, "response", entry["response"], full)


func _add_detail_block(parent: Node, label: String, value: Variant, full: bool) -> void:
	var caption := Label.new()
	caption.text = label + ":"
	caption.add_theme_color_override("font_color", COLOR_DIM)
	caption.add_theme_font_size_override("font_size", 10)
	parent.add_child(caption)

	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.bbcode_enabled = false
	rtl.add_theme_color_override("default_color", COLOR_DIM)
	rtl.add_theme_font_size_override("normal_font_size", 10)
	rtl.text = _stringify_detail(value, full)
	parent.add_child(rtl)


func _stringify_detail(value: Variant, full: bool) -> String:
	var text := ""
	if value is String:
		text = value
		# Pretty-print JSON strings when possible
		var parsed := JSON.new()
		if parsed.parse(text) == OK:
			text = JSON.stringify(parsed.data, "\t" if full else "")
	elif value is Dictionary or value is Array:
		text = JSON.stringify(value, "\t" if full else "")
	else:
		text = str(value)

	if not full and text.length() > 800:
		return text.substr(0, 800) + "\n… truncated (%d chars, enable Full JSON)" % text.length()
	return text


func _on_copy_entry(entry: Dictionary) -> void:
	var lines: PackedStringArray = [_format_summary_line(entry)]
	if _show_params_check.button_pressed and entry.has("params"):
		lines.append("params: " + _stringify_detail(entry["params"], true))
	if entry.has("response"):
		lines.append("response: " + _stringify_detail(entry["response"], true))
	_clipboard_set("\n".join(lines))


func _clipboard_set(text: String) -> void:
	DisplayServer.clipboard_set(text)


func _auto_scroll() -> void:
	if _log_scroll:
		_log_scroll.set_deferred(
			"scroll_vertical",
			int(_log_scroll.get_v_scroll_bar().max_value)
		)


# --- Tools callbacks ---

func _on_filter_changed(filter: String) -> void:
	for method_name: String in _tool_checkboxes:
		var cb: CheckBox = _tool_checkboxes[method_name]
		cb.visible = filter.is_empty() or method_name.containsn(filter)


func _on_tool_toggled(enabled: bool, method_name: String) -> void:
	if command_router and command_router.has_method("set_tool_disabled"):
		command_router.set_tool_disabled(method_name, not enabled)


func _on_enable_all() -> void:
	if command_router and command_router.has_method("set_all_tools_disabled"):
		command_router.set_all_tools_disabled(false)
	for method_name: String in _tool_checkboxes:
		_tool_checkboxes[method_name].set_pressed_no_signal(true)


func _on_disable_all() -> void:
	if command_router and command_router.has_method("set_all_tools_disabled"):
		command_router.set_all_tools_disabled(true)
	for method_name: String in _tool_checkboxes:
		_tool_checkboxes[method_name].set_pressed_no_signal(false)
