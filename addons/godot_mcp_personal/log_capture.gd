## Captures editor log output via OS.add_logger (Godot 4.4+ Logger API).
class_name MCPLogCapture
extends Logger

const MAX_ENTRIES := 500

var _entries: Array[Dictionary] = []
var _mutex := Mutex.new()


func _log_message(message: String, error: bool) -> void:
	_append("message", message, "error" if error else "info")


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	editor_notify: bool,
	error_type: int,
	script_backtraces: Array
) -> void:
	var text := "%s:%d %s: %s" % [file, line, code, rationale]
	if not function.is_empty():
		text = "%s() %s" % [function, text]
	_append("error", text, "error", {
		"file": file,
		"line": line,
		"code": code,
		"function": function,
		"error_type": error_type,
	})


func get_entries(limit: int = 100, kind_filter: String = "") -> Dictionary:
	_mutex.lock()
	var filtered: Array[Dictionary] = []
	for entry in _entries:
		if kind_filter.is_empty() or str(entry.get("kind", "")) == kind_filter:
			filtered.append(entry)

	var slice: Array = filtered
	if limit > 0 and slice.size() > limit:
		slice = slice.slice(slice.size() - limit, slice.size())

	var result := {
		"entries": slice,
		"total": _entries.size(),
		"filtered_total": filtered.size(),
	}
	_mutex.unlock()
	return result


func clear() -> void:
	_mutex.lock()
	_entries.clear()
	_mutex.unlock()


func _append(kind: String, text: String, level: String, details: Dictionary = {}) -> void:
	_mutex.lock()
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"kind": kind,
		"level": level,
		"text": text,
	}
	if not details.is_empty():
		entry["details"] = details
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	_mutex.unlock()
