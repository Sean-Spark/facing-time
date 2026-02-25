class_name WebSocketClient
extends Node

@export var handshake_headers: PackedStringArray
@export var supported_protocols: PackedStringArray
@export var verify_certificate: bool = false  # 开发环境设为 false 以支持自签名证书

var tls_options: TLSOptions = null
var socket := WebSocketPeer.new()
var last_state := WebSocketPeer.STATE_CLOSED

signal sig_connected_to_server()
signal sig_connection_closed()
signal sig_message_received(message: Variant)

func init_tls_options() -> void:
	if verify_certificate:
		# 使用系统证书验证
		tls_options = TLSOptions.client()
		print("WebSocketClient: Using TLS with certificate verification")
	else:
		# 跳过证书验证（仅用于开发/自签名证书）
		tls_options = TLSOptions.client_unsafe()
		print("WebSocketClient: Using TLS WITHOUT certificate verification")

func connect_to_url(url: String) -> int:
	# 根据 URL 协议决定是否使用 TLS
	if url.begins_with("wss://"):
		init_tls_options()
	else:
		tls_options = null  # 非 TLS 连接
		print("WebSocketClient: Connecting without TLS")

	socket.supported_protocols = supported_protocols
	socket.handshake_headers = handshake_headers

	print("WebSocketClient: Connecting to ", url, " with tls_options: ", tls_options)
	var err := socket.connect_to_url(url, tls_options)
	if err != OK:
		print("WebSocketClient: connect_to_url failed with error: ", err)
		return err
	return OK


func send(message: String) -> int:
	if typeof(message) == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))


func get_message() -> Variant:
	if socket.get_available_packet_count() < 1:
		return null
	var pkt := socket.get_packet()
	if socket.was_string_packet():
		return pkt.get_string_from_utf8()
	return bytes_to_var(pkt)


func close(code: int = 1000, reason: String = "") -> void:
	socket.close(code, reason)
	last_state = socket.get_ready_state()


func clear() -> void:
	socket = WebSocketPeer.new()
	last_state = socket.get_ready_state()


func get_socket() -> WebSocketPeer:
	return socket


func poll() -> void:
	socket.poll()
	var state := socket.get_ready_state()
	if last_state != state:
		print_debug(state)
		last_state = state
		if state == socket.STATE_OPEN:
			sig_connected_to_server.emit()
		elif state == socket.STATE_CLOSED:
			sig_connection_closed.emit()
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		sig_message_received.emit(get_message())


func _process(_delta: float) -> void:
	poll()
