## WebSocket server for MCP bridge.
## Godot 4.4+ APIs: TCPServer, WebSocketPeer.accept_stream (see networking/websocket docs).
extends Node

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)

const DEFAULT_PORT := 6505

var _tcp_server := TCPServer.new()
var _peers: Dictionary = {} # int -> WebSocketPeer
var _next_peer_id := 1
var _port: int = DEFAULT_PORT
var _tool_router: MCPToolRouter
var _server_start_time: float = 0.0


func configure(tool_router: MCPToolRouter, server_start_time: float) -> void:
	_tool_router = tool_router
	_server_start_time = server_start_time


func _ready() -> void:
	if _tool_router == null:
		push_error("[godot-mcp] WebSocket server started without tool router - call configure() before add_child")
		set_process(false)
		return
	_port = _resolve_port()
	_server_start_time = Time.get_ticks_msec() / 1000.0 if _server_start_time == 0.0 else _server_start_time
	var err := _tcp_server.listen(_port, "127.0.0.1")
	if err != OK:
		push_error("[godot-mcp] Unable to start WebSocket server on 127.0.0.1:%d (error %d)" % [_port, err])
		set_process(false)
		return
	print("[godot-mcp] WebSocket server listening on ws://127.0.0.1:%d" % _port)


func _process(_delta: float) -> void:
	while _tcp_server.is_connection_available():
		var tcp := _tcp_server.take_connection()
		var ws := WebSocketPeer.new()
		var err := ws.accept_stream(tcp)
		if err != OK:
			push_error("[godot-mcp] Failed to accept WebSocket stream (error %d)" % err)
			continue
		_next_peer_id += 1
		_peers[_next_peer_id] = ws
		print("[godot-mcp] MCP client connected (peer %d)" % _next_peer_id)
		client_connected.emit(_next_peer_id)

	for peer_id in _peers.keys():
		var peer: WebSocketPeer = _peers[peer_id]
		peer.poll()
		var state := peer.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				var packet := peer.get_packet()
				if peer.was_string_packet():
					var text := packet.get_string_from_utf8()
					_handle_message(peer, text)
				else:
					_send_error(peer, "", MCPErrorCodes.make_error(
						MCPErrorCodes.INVALID_PARAMS,
						"Binary WebSocket frames are not supported.",
						"Send JSON as a text frame."
					))
		elif state == WebSocketPeer.STATE_CLOSED:
			_peers.erase(peer_id)
			print("[godot-mcp] MCP client disconnected (peer %d)" % peer_id)
			client_disconnected.emit(peer_id)


func get_status() -> Dictionary:
	return {
		"port": _port,
		"client_count": _peers.size(),
		"uptime_seconds": Time.get_ticks_msec() / 1000.0 - _server_start_time,
	}


func shutdown() -> void:
	for peer_id in _peers.keys():
		var peer: WebSocketPeer = _peers[peer_id]
		peer.close()
	_peers.clear()
	if _tcp_server.is_listening():
		_tcp_server.stop()
	set_process(false)
	print("[godot-mcp] WebSocket server stopped")


func _handle_message(peer: WebSocketPeer, raw: String) -> void:
	if _tool_router == null:
		_send_error(peer, "", MCPErrorCodes.make_error(
			MCPErrorCodes.INTERNAL_ERROR,
			"Tool router is not configured.",
		))
		return

	var parsed := MCPProtocol.parse_request(raw)
	if not parsed.get("valid", false):
		var err_payload: Dictionary = parsed.get("error", {})
		var err_id := ""
		# Try to recover id from raw JSON for error responses
		var maybe = JSON.parse_string(raw)
		if typeof(maybe) == TYPE_DICTIONARY and maybe.has("id"):
			err_id = str(maybe["id"])
		_send_json(peer, MCPProtocol.attach_id(err_id, err_payload))
		return

	var request_id: String = parsed["id"]
	var method: String = parsed["method"]
	var params: Dictionary = parsed["params"]

	print("[godot-mcp] Tool call: %s (id=%s)" % [method, request_id])

	var result: Dictionary
	if params.is_empty():
		result = _tool_router.route(method, {})
	else:
		result = _tool_router.route(method, params)

	if result.get("ok", false):
		_send_json(peer, MCPProtocol.success(request_id, result.get("result", {})))
	else:
		_send_json(peer, MCPProtocol.attach_id(request_id, result))


func _send_error(peer: WebSocketPeer, request_id: String, error_payload: Dictionary) -> void:
	_send_json(peer, MCPProtocol.attach_id(request_id, error_payload))


func _send_json(peer: WebSocketPeer, payload: Dictionary) -> void:
	var text := JSON.stringify(payload)
	var err := peer.send_text(text)
	if err != OK:
		push_error("[godot-mcp] Failed to send WebSocket response (error %d)" % err)


func _resolve_port() -> int:
	var env_port := OS.get_environment("GODOT_MCP_PORT")
	if not env_port.is_empty():
		if env_port.is_valid_int():
			return int(env_port)
		push_error("[godot-mcp] Invalid GODOT_MCP_PORT '%s', using default %d" % [env_port, DEFAULT_PORT])
	return DEFAULT_PORT
