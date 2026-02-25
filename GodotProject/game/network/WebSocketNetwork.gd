## 通用 WebSocket 网络管理器
## 支持服务器端和客户端模式
class_name WebSocketNetwork
extends Node

## 网络类型
enum NetworkType { SERVER, CLIENT }

## 连接状态
enum ConnectionState {
	DISCONNECTED,
	LISTENING,
	CONNECTING,
	CONNECTED,
	ERROR
}

## 信号
signal connected_to_server
signal connection_closed
signal message_received(peer_id: int, message: NetworkMessage)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connection_failed(error: String)
signal connection_state_changed(state: ConnectionState)
signal error_occurred(message: String)  # 向后兼容信号

## 属性
var network_type: NetworkType = NetworkType.CLIENT
var state: ConnectionState = ConnectionState.DISCONNECTED:
	set(v):
		state = v
		connection_state_changed.emit(v)

var is_host: bool = false
var listen_port: int = 0
var server_url: String = ""

## 内部组件
var _server: WebSocketServer = null
var _client: WebSocketClient = null


## ========== 服务器端方法 ==========

## 启动服务器
func start_server(port: int) -> Error:
	network_type = NetworkType.SERVER
	is_host = true
	listen_port = port
	state = ConnectionState.LISTENING

	_server = WebSocketServer.new()
	_server.init()
	var err := _server.listen(port)
	if err != OK:
		state = ConnectionState.ERROR
		connection_failed.emit("Failed to start server on port " + str(port))
		return err

	_connect_server_signals()
	print("WebSocketNetwork: Server started on port ", port)
	return OK

## 停止服务器
func stop_server() -> void:
	if _server:
		_server.stop()
		_server = null
	if state == ConnectionState.LISTENING:
		state = ConnectionState.DISCONNECTED

## 发送消息给指定客户端
func send_to_peer(peer_id: int, message: NetworkMessage) -> Error:
	if not _server or peer_id <= 0:
		return ERR_INVALID_PARAMETER
	var err := _server.send(peer_id, message.to_json())
	return err

## 广播消息给所有客户端
func broadcast(message: NetworkMessage) -> Error:
	if not _server:
		return ERR_INVALID_PARAMETER
	var err := _server.send(0, message.to_json())
	return err

## 获取所有连接的客户端ID
func get_connected_peers() -> Array[int]:
	var peers: Array[int] = []
	if _server:
		for peer_id in _server.peers:
			peers.append(peer_id)
	return peers

## ========== 客户端方法 ==========

## 连接到服务器
func connect_to_server(url: String) -> Error:
	network_type = NetworkType.CLIENT
	is_host = false
	server_url = url
	state = ConnectionState.CONNECTING

	_client = WebSocketClient.new()
	var err := _client.connect_to_url(url)
	if err != OK:
		state = ConnectionState.ERROR
		connection_failed.emit("Failed to connect to " + url)
		return err

	_connect_client_signals()
	print("WebSocketNetwork: Connecting to ", url)
	return OK

## 断开与服务器的连接
func disconnect_from_server() -> void:
	if _client:
		_client.close()
		_client = null
	if state == ConnectionState.CONNECTED or state == ConnectionState.CONNECTING:
		state = ConnectionState.DISCONNECTED

## 发送消息到服务器
func send_to_server(message: NetworkMessage) -> Error:
	if not _client:
		return ERR_INVALID_PARAMETER
	var err := _client.send(message.to_json())
	return err

## ========== 通用方法 ==========

## 轮询网络状态
func poll() -> void:
	if _server:
		_server.poll()
	elif _client:
		_client.poll()

## 清理连接
func cleanup() -> void:
	if network_type == NetworkType.SERVER:
		stop_server()
	else:
		disconnect_from_server()

## 完全断开连接
func disconnect_network() -> void:
	cleanup()
	is_host = false
	listen_port = 0
	server_url = ""

## ========== 内部方法 ==========

func _connect_server_signals() -> void:
	if _server:
		_server.sig_client_connected.connect(_on_server_client_connected)
		_server.sig_client_disconnected.connect(_on_server_client_disconnected)
		_server.sig_message_received.connect(_on_server_message_received)

func _connect_client_signals() -> void:
	if _client:
		_client.sig_connected_to_server.connect(_on_client_connected_to_server)
		_client.sig_connection_closed.connect(_on_client_connection_closed)
		_client.sig_message_received.connect(_on_client_message_received)

func _on_server_client_connected(peer_id: int) -> void:
	print("Client connected: ", peer_id)
	client_connected.emit(peer_id)

func _on_server_client_disconnected(peer_id: int) -> void:
	print("Client disconnected: ", peer_id)
	client_disconnected.emit(peer_id)

func _on_server_message_received(peer_id: int, message: String) -> void:
	var msg: NetworkMessage = NetworkMessage.from_json(message)
	if msg:
		message_received.emit(peer_id, msg)

func _on_client_connected_to_server() -> void:
	state = ConnectionState.CONNECTED
	connected_to_server.emit()
	print("Connected to server")

func _on_client_connection_closed() -> void:
	state = ConnectionState.DISCONNECTED
	connection_closed.emit()
	print("Connection closed")

func _on_client_message_received(message: Variant) -> void:
	if typeof(message) == TYPE_STRING:
		var msg: NetworkMessage = NetworkMessage.from_json(message)
		if msg:
			message_received.emit(-1, msg)

## ========== 便捷方法 ==========

## 发送玩家加入消息
func send_player_joined(seat_index: int, player_name: String, player_id: String = "") -> void:
	var msg := NetworkMessage.create_player_joined(seat_index, player_name, player_id)
	if is_host:
		broadcast(msg)
	else:
		send_to_server(msg)

## 发送玩家离开消息
func send_player_left(seat_index: int, reason: String = "") -> void:
	var msg := NetworkMessage.create_player_left(seat_index, reason)
	if is_host:
		broadcast(msg)
	else:
		send_to_server(msg)

## 发送玩家准备消息
func send_player_ready(seat_index: int, is_ready: bool) -> void:
	var msg := NetworkMessage.create_player_ready(seat_index, is_ready)
	if is_host:
		broadcast(msg)
	else:
		send_to_server(msg)

## 发送聊天消息
func send_chat(message: String, sender_id: String = "", sender_name: String = "") -> void:
	var msg := NetworkMessage.create_chat(message, sender_id, sender_name)
	if is_host:
		broadcast(msg)
	else:
		send_to_server(msg)

## 发送错误消息
func send_error(error_message: String, original_type: NetworkMessage.MessageType = NetworkMessage.MessageType.PING) -> void:
	var msg := NetworkMessage.create_error(error_message, original_type)
	if is_host:
		broadcast(msg)
	else:
		send_to_server(msg)
