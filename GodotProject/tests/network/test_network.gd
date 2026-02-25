extends GutTest

const WebSocketNetwork = preload("res://game/network/WebSocketNetwork.gd")
const NetworkMessage = preload("res://game/network/NetworkMessage.gd")

var _server_network: WebSocketNetwork
var _client_network: WebSocketNetwork
var _test_port: int = 9949
var _connection_timeout: float = 2.0

# 用于消息接收测试
var _last_received_message: NetworkMessage = null
var _last_received_peer_id: int = -1

func before_each():
	_server_network = WebSocketNetwork.new()
	_client_network = WebSocketNetwork.new()
	add_child(_server_network)
	add_child(_client_network)

func after_each():
	_server_network.cleanup()
	_client_network.cleanup()
	_server_network.free()
	_client_network.free()

# ========== 辅助等待方法 ==========

func _wait_for_state(network: WebSocketNetwork, target_state: WebSocketNetwork.ConnectionState, timeout: float = 2.0) -> bool:
	var start_time = Time.get_ticks_msec()
	while network.state != target_state:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			return false
		# 同时 poll 服务器和客户端网络
		_server_network.poll()
		_client_network.poll()
		network.poll()
		await get_tree().process_frame
	return true

func _wait_for_signal(sig: Signal, timeout: float = 2.0) -> bool:
	var completed: bool = false
	var start_time = Time.get_ticks_msec()

	sig.connect(func():
		completed = true
	)

	while not completed:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			return false
		# 调用 poll 处理网络事件
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	return true

# ========== 消息接收辅助方法 ==========

func _on_message_received(peer_id: int, message: NetworkMessage):
	_last_received_message = message
	_last_received_peer_id = peer_id

func _await_message(network: WebSocketNetwork, timeout: float = 2.0) -> NetworkMessage:
	_last_received_message = null
	network.message_received.connect(_on_message_received)

	var start_time = Time.get_ticks_msec()
	while _last_received_message == null:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			network.message_received.disconnect(_on_message_received)
			return null
		network.poll()
		await get_tree().process_frame

	network.message_received.disconnect(_on_message_received)
	return _last_received_message

# ========== 测试用例 ==========

# ========== 服务器功能测试 ==========

func test_server_start_and_stop():
	var err = _server_network.start_server(_test_port)
	assert_eq(err, OK, "Server should start on port " + str(_test_port))

	# 等待服务器就绪
	var waited = await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)
	assert_true(waited, "Server should be in LISTENING state")

	# 停止服务器
	_server_network.stop_server()
	waited = await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.DISCONNECTED)
	assert_true(waited, "Server should be in DISCONNECTED state after stop")

func test_get_connected_peers_empty():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 0, "Should have no connected peers initially")

	_server_network.stop_server()

func test_broadcast_without_clients():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	var msg = NetworkMessage.create_chat("test", "", "sender")
	var err = _server_network.broadcast(msg)
	assert_eq(err, OK, "Broadcast should succeed even without clients")

	_server_network.stop_server()

# ========== 客户端功能测试 ==========

func test_client_connection_initial_state():
	# 初始状态应该是 DISCONNECTED
	assert_eq(_client_network.state, WebSocketNetwork.ConnectionState.DISCONNECTED)

func test_send_without_connection():
	var msg = NetworkMessage.create_chat("test", "", "sender")
	var err = _client_network.send_to_server(msg)
	assert_ne(err, OK, "Sending without connection should fail")


# ========== 客户端连接服务器测试 ==========

func test_client_connect_to_server():
	# 启动服务器
	var err = _server_network.start_server(_test_port)
	assert_eq(err, OK, "Server should start")

	# 禁用 TLS 以支持非 TLS 客户端连接测试
	_server_network._server.use_tls = false

	var waited = await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)
	assert_true(waited, "Server should be in LISTENING state")

	# 客户端连接到服务器
	err = _client_network.connect_to_server("ws://localhost:" + str(_test_port))
	assert_eq(err, OK, "Client should initiate connection")

	# 轮询等待连接完成
	waited = await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)
	assert_true(waited, "Client should be CONNECTED")

	# 额外轮询几次让服务器端也完成连接检测
	for i in range(5):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证服务器有连接的客户端
	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 1, "Should have 1 connected peer")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()


func test_client_send_message_to_server():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 禁用 TLS 以支持非 TLS 客户端连接测试
	_server_network._server.use_tls = false

	# 订阅服务器消息接收信号
	var received_ref: Array[NetworkMessage] = []
	_server_network.message_received.connect(func(_peer_id, msg):
		received_ref.append(msg)
	)

	# 客户端连接
	_client_network.connect_to_server("ws://localhost:" + str(_test_port))
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)

	# 额外轮询确保服务器端完全建立连接
	for i in range(10):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证连接建立
	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 1, "Should have 1 connected peer")

	# 客户端发送消息
	var chat_msg = NetworkMessage.create_chat("Hello Server", "player1", "Player One")
	var send_err = _client_network.send_to_server(chat_msg)
	assert_eq(send_err, OK, "Client should send message successfully")

	# 多次轮询确保消息被发送和接收
	for i in range(20):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证服务器收到消息内容
	var received_msg = received_ref[0] if received_ref.size() > 0 else null
	assert_not_null(received_msg, "Server should receive message")
	assert_eq(received_msg.type, NetworkMessage.MessageType.CHAT, "Message type should be CHAT")
	assert_eq(received_msg.get_string("message", ""), "Hello Server", "Message content should match")
	assert_eq(received_msg.get_string("sender_id", ""), "player1", "Sender ID should match")
	assert_eq(received_msg.get_string("sender_name", ""), "Player One", "Sender name should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()


func test_server_broadcast_to_client():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 禁用 TLS 以支持非 TLS 客户端连接测试
	_server_network._server.use_tls = false

	# 订阅客户端消息接收信号
	var client_received_ref: Array[NetworkMessage] = []
	_client_network.message_received.connect(func(_peer_id, msg):
		client_received_ref.append(msg)
	)

	# 客户端连接
	_client_network.connect_to_server("ws://localhost:" + str(_test_port))
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)

	# 额外轮询确保连接建立
	for i in range(10):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证连接建立
	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 1, "Should have 1 connected peer")

	# 服务器广播消息
	var broadcast_msg = NetworkMessage.create_chat("Broadcast message", "server", "Server")
	var broadcast_err = _server_network.broadcast(broadcast_msg)
	assert_eq(broadcast_err, OK, "Server should broadcast successfully")

	# 多次轮询
	for i in range(20):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证客户端收到广播内容
	var received_msg = client_received_ref[0] if client_received_ref.size() > 0 else null
	assert_not_null(received_msg, "Client should receive broadcast")
	assert_eq(received_msg.type, NetworkMessage.MessageType.CHAT, "Message type should be CHAT")
	assert_eq(received_msg.get_string("message", ""), "Broadcast message", "Message content should match")
	assert_eq(received_msg.get_string("sender_id", ""), "server", "Sender ID should match")
	assert_eq(received_msg.get_string("sender_name", ""), "Server", "Sender name should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()


func test_client_disconnect_from_server():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 禁用 TLS 以支持非 TLS 客户端连接测试
	_server_network._server.use_tls = false

	# 客户端连接
	_client_network.connect_to_server("ws://localhost:" + str(_test_port))
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)

	# 额外轮询确保连接建立
	for i in range(10):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证有连接
	var peers_before = _server_network.get_connected_peers()
	assert_eq(peers_before.size(), 1, "Should have 1 peer before disconnect")

	# 客户端断开连接
	_client_network.disconnect_from_server()

	# 等待客户端状态变为 DISCONNECTED
	var waited = await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.DISCONNECTED)
	assert_true(waited, "Client should be DISCONNECTED")

	# 多次轮询让服务器检测断开
	for i in range(20):
		_server_network.poll()
		await get_tree().process_frame

	# 验证客户端已断开
	assert_eq(_client_network.state, WebSocketNetwork.ConnectionState.DISCONNECTED)

	# 清理
	_server_network.stop_server()


# ========== WSS (TLS) 连接测试 ==========

func test_wss_client_connect_to_server():
	# 启动服务器（默认 use_tls = true）
	var err = _server_network.start_server(_test_port)
	assert_eq(err, OK, "Server should start")

	var waited = await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)
	assert_true(waited, "Server should be in LISTENING state")

	# 客户端使用 WSS 连接到服务器
	err = _client_network.connect_to_server("wss://localhost:" + str(_test_port))
	assert_eq(err, OK, "Client should initiate WSS connection")

	# 轮询等待连接完成
	waited = await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)
	assert_true(waited, "Client should be CONNECTED via WSS")

	# 额外轮询几次让服务器端也完成连接检测
	for i in range(5):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证服务器有连接的客户端
	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 1, "Should have 1 connected peer")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()


func test_wss_client_send_message_to_server():
	# 启动服务器（默认 use_tls = true）
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 订阅服务器消息接收信号
	var server_received_ref: Array[NetworkMessage] = []
	_server_network.message_received.connect(func(_peer_id, msg):
		server_received_ref.append(msg)
	)

	# 客户端使用 WSS 连接
	_client_network.connect_to_server("wss://localhost:" + str(_test_port))
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)

	# 额外轮询确保服务器端完全建立连接
	for i in range(10):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证连接建立
	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 1, "Should have 1 connected peer")

	# 客户端发送消息
	var chat_msg = NetworkMessage.create_chat("Hello Server via WSS", "player1", "Player One")
	var send_err = _client_network.send_to_server(chat_msg)
	assert_eq(send_err, OK, "Client should send message successfully via WSS")

	# 多次轮询确保消息被发送
	for i in range(20):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证服务器收到消息内容
	var received_msg = server_received_ref[0] if server_received_ref.size() > 0 else null
	assert_not_null(received_msg, "Server should receive message via WSS")
	assert_eq(received_msg.type, NetworkMessage.MessageType.CHAT, "Message type should be CHAT")
	assert_eq(received_msg.get_string("message", ""), "Hello Server via WSS", "Message content should match")
	assert_eq(received_msg.get_string("sender_id", ""), "player1", "Sender ID should match")
	assert_eq(received_msg.get_string("sender_name", ""), "Player One", "Sender name should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()


func test_wss_server_broadcast_to_client():
	# 启动服务器（默认 use_tls = true）
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 订阅客户端消息接收信号
	var client_received_ref: Array[NetworkMessage] = []
	_client_network.message_received.connect(func(_peer_id, msg):
		client_received_ref.append(msg)
	)

	# 客户端使用 WSS 连接
	_client_network.connect_to_server("wss://localhost:" + str(_test_port))
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)

	# 额外轮询确保连接建立
	for i in range(10):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证连接建立
	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 1, "Should have 1 connected peer")

	# 服务器广播消息
	var broadcast_msg = NetworkMessage.create_chat("Broadcast via WSS", "server", "Server")
	var broadcast_err = _server_network.broadcast(broadcast_msg)
	assert_eq(broadcast_err, OK, "Server should broadcast successfully via WSS")

	# 多次轮询
	for i in range(20):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证客户端收到广播内容
	var received_msg = client_received_ref[0] if client_received_ref.size() > 0 else null
	assert_not_null(received_msg, "Client should receive broadcast via WSS")
	assert_eq(received_msg.type, NetworkMessage.MessageType.CHAT, "Message type should be CHAT")
	assert_eq(received_msg.get_string("message", ""), "Broadcast via WSS", "Message content should match")
	assert_eq(received_msg.get_string("sender_id", ""), "server", "Sender ID should match")
	assert_eq(received_msg.get_string("sender_name", ""), "Server", "Sender name should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()


func test_wss_client_disconnect_from_server():
	# 启动服务器（默认 use_tls = true）
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 客户端使用 WSS 连接
	_client_network.connect_to_server("wss://localhost:" + str(_test_port))
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.CONNECTED)

	# 额外轮询确保连接建立
	for i in range(10):
		_server_network.poll()
		_client_network.poll()
		await get_tree().process_frame

	# 验证有连接
	var peers_before = _server_network.get_connected_peers()
	assert_eq(peers_before.size(), 1, "Should have 1 peer before disconnect")

	# 客户端断开连接
	_client_network.disconnect_from_server()

	# 等待客户端状态变为 DISCONNECTED
	var waited = await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.DISCONNECTED)
	assert_true(waited, "Client should be DISCONNECTED")

	# 多次轮询让服务器检测断开
	for i in range(20):
		_server_network.poll()
		await get_tree().process_frame

	# 验证客户端已断开
	assert_eq(_client_network.state, WebSocketNetwork.ConnectionState.DISCONNECTED)

	# 清理
	_server_network.stop_server()