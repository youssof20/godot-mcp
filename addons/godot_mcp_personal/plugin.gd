@tool
extends EditorPlugin

## Godot MCP Personal - editor plugin entry point.
## Godot 4.4+ assumption: EditorPlugin lifecycle via _enter_tree/_exit_tree.

const WebSocketServerScript = preload("res://addons/godot_mcp_personal/websocket_server.gd")

var _websocket_server: Node
var _tool_router: MCPToolRouter
var _log_capture: MCPLogCapture
var _server_start_time: float = 0.0


func _enter_tree() -> void:
	_server_start_time = Time.get_ticks_msec() / 1000.0

	_log_capture = MCPLogCapture.new()
	# Godot 4.4+ API: OS.add_logger
	OS.add_logger(_log_capture)

	_tool_router = MCPToolRouter.new()

	_websocket_server = WebSocketServerScript.new()
	_websocket_server.name = "MCPWebSocketServer"

	_tool_router.setup(self, _websocket_server, _server_start_time, _log_capture)
	if _websocket_server.has_method("configure"):
		_websocket_server.call("configure", _tool_router, _server_start_time)

	add_child(_websocket_server)

	print("[godot-mcp] Plugin enabled")


func _exit_tree() -> void:
	if _log_capture:
		OS.remove_logger(_log_capture)
		_log_capture = null

	if _websocket_server:
		if _websocket_server.has_method("shutdown"):
			_websocket_server.call("shutdown")
		_websocket_server.queue_free()
		_websocket_server = null
	_tool_router = null
	print("[godot-mcp] Plugin disabled")
