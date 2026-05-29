@tool
extends Node
## Ring buffer of MCP WebSocket command activity for the status panel and get_mcp_activity_log.

const MAX_ENTRIES := 500
const DEFAULT_EXPORT_PATH := "user://mcp_activity_log.txt"

var _entries: Array[Dictionary] = []


func add_entry(entry: Dictionary) -> void:
	var copy := entry.duplicate(true)
	if not copy.has("timestamp"):
		copy["timestamp"] = Time.get_datetime_string_from_system()
	_entries.append(copy)
	while _entries.size() > MAX_ENTRIES:
		_entries.remove_at(0)


func clear() -> void:
	_entries.clear()


func get_entry_count() -> int:
	return _entries.size()


func get_entries(
	max_count: int = 50,
	errors_only: bool = false,
	since_index: int = -1
) -> Array:
	var result: Array = []
	var start := 0
	if since_index >= 0:
		start = clampi(since_index, 0, _entries.size())
	for i in range(start, _entries.size()):
		var e: Dictionary = _entries[i]
		if errors_only and e.get("ok", true):
			continue
		result.append(e)
		if result.size() >= max_count:
			break
	return result


func export_text(
	include_params: bool = true,
	include_responses: bool = true,
	full_responses: bool = true,
	errors_only: bool = false,
	max_lines: int = -1
) -> String:
	var lines: PackedStringArray = []
	var count := 0
	for e: Dictionary in _entries:
		if errors_only and e.get("ok", true):
			continue
		lines.append(_format_entry_line(e, include_params, include_responses, full_responses))
		count += 1
		if max_lines > 0 and count >= max_lines:
			break
	return "\n".join(lines)


func save_to_file(
	path: String = DEFAULT_EXPORT_PATH,
	include_params: bool = true,
	include_responses: bool = true,
	full_responses: bool = true,
	errors_only: bool = false
) -> Dictionary:
	var text := export_text(include_params, include_responses, full_responses, errors_only)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"saved": false,
			"path": path,
			"error": error_string(FileAccess.get_open_error()),
		}
	file.store_string(text)
	file.close()
	return {"saved": true, "path": path, "bytes": text.length(), "entry_count": _entries.size()}


func _format_entry_line(
	e: Dictionary,
	include_params: bool,
	include_responses: bool,
	full_responses: bool
) -> String:
	var status := "OK" if e.get("ok", false) else "ERR"
	var dur := ""
	if e.has("duration_ms"):
		dur = " %dms" % int(e["duration_ms"])
	var port := ""
	if e.has("port"):
		port = " port=%d" % int(e["port"])
	var line := "[%s] [%s] %s%s%s" % [e.get("timestamp", ""), status, e.get("method", "?"), port, dur]
	if not e.get("ok", true) and e.has("error_message"):
		line += " — %s" % e["error_message"]
	if include_params and e.has("params"):
		line += "\n  params: %s" % _stringify_variant(e["params"], full_responses)
	if include_responses and e.has("response"):
		line += "\n  response: %s" % _stringify_variant(e["response"], full_responses)
	return line


func _stringify_variant(value: Variant, full: bool) -> String:
	var text := ""
	if value is String:
		text = value
	elif value is Dictionary or value is Array:
		text = JSON.stringify(value, "\t" if full else "")
	else:
		text = str(value)
	if not full and text.length() > 2000:
		return text.substr(0, 2000) + "… (%d chars total)" % text.length()
	return text
