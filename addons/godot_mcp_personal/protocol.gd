## JSON request/response helpers for the MCP WebSocket wire protocol.
class_name MCPProtocol

const PROTOCOL_VERSION := "1.0"


static func parse_request(raw: String) -> Dictionary:
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		return {
			"valid": false,
			"error": MCPErrorCodes.make_error(
				MCPErrorCodes.INVALID_PARAMS,
				"Request body is not valid JSON.",
				"Send JSON: {\"id\":\"...\",\"method\":\"tool_name\",\"params\":{}}"
			),
		}

	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"valid": false,
			"error": MCPErrorCodes.make_error(
				MCPErrorCodes.INVALID_PARAMS,
				"Request must be a JSON object.",
			),
		}

	var req: Dictionary = parsed
	if not req.has("id") or str(req["id"]).is_empty():
		return {
			"valid": false,
			"error": MCPErrorCodes.make_error(
				MCPErrorCodes.INVALID_PARAMS,
				"Request missing required 'id' field.",
			),
		}
	if not req.has("method") or str(req["method"]).is_empty():
		return {
			"valid": false,
			"error": MCPErrorCodes.make_error(
				MCPErrorCodes.INVALID_PARAMS,
				"Request missing required 'method' field.",
			),
		}

	var params: Dictionary = {}
	if req.has("params"):
		if typeof(req["params"]) != TYPE_DICTIONARY:
			return {
				"valid": false,
				"error": MCPErrorCodes.make_error(
					MCPErrorCodes.INVALID_PARAMS,
					"'params' must be an object when provided.",
				),
			}
		params = req["params"]

	return {
		"valid": true,
		"id": str(req["id"]),
		"method": str(req["method"]),
		"params": params,
	}


static func success(id: String, result: Variant) -> Dictionary:
	return {
		"id": id,
		"ok": true,
		"result": result,
	}


static func attach_id(id: String, payload: Dictionary) -> Dictionary:
	if payload.has("ok"):
		payload["id"] = id
	return payload
