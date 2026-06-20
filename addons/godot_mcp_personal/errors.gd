## Standard error codes for Godot MCP bridge responses.
class_name MCPErrorCodes

const GODOT_NOT_CONNECTED := "GODOT_NOT_CONNECTED"
const TIMEOUT := "TIMEOUT"
const INVALID_PARAMS := "INVALID_PARAMS"
const NOT_FOUND := "NOT_FOUND"
const ALREADY_EXISTS := "ALREADY_EXISTS"
const UNSUPPORTED_NODE_TYPE := "UNSUPPORTED_NODE_TYPE"
const UNSUPPORTED_RESOURCE_TYPE := "UNSUPPORTED_RESOURCE_TYPE"
const GODOT_API_ERROR := "GODOT_API_ERROR"
const SCRIPT_ERROR := "SCRIPT_ERROR"
const SCENE_ERROR := "SCENE_ERROR"
const RUNTIME_NOT_RUNNING := "RUNTIME_NOT_RUNNING"
const PERMISSION_DENIED := "PERMISSION_DENIED"
const DANGEROUS_TOOL_DISABLED := "DANGEROUS_TOOL_DISABLED"
const NOT_IMPLEMENTED := "NOT_IMPLEMENTED"
const INTERNAL_ERROR := "INTERNAL_ERROR"


static func make_error(
	code: String,
	message: String,
	suggestion: String = "",
	details: Dictionary = {}
) -> Dictionary:
	var err := {
		"ok": false,
		"error": {
			"code": code,
			"message": message,
		},
	}
	if not suggestion.is_empty():
		err["error"]["suggestion"] = suggestion
	if not details.is_empty():
		err["error"]["details"] = details
	return err


static func not_implemented(method: String) -> Dictionary:
	return make_error(
		NOT_IMPLEMENTED,
		"Tool '%s' is not implemented yet." % method,
		"See docs/TOOL_MATRIX.md for implementation status."
	)
