# WebSocketNetwork 集成测试实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 WebSocketNetwork 组件编写集成测试，验证服务器/客户端模式的完整通信流程

**Architecture:** 使用 GutTest 框架，在本地建立实际的 WebSocket 服务器-客户端连接进行集成测试。使用 `wss://127.0.0.1:<port>` 连接，依赖现有的 TLS 证书。

**Tech Stack:** Godot 4.x, GDScript, GutTest

---

### Task 1: 添加测试夹具和辅助方法

**Files:**
- Modify: `GodotProject/tests/network/test_network.gd`

**Step 1: 创建完整的测试类框架**

```gdscript
extends GutTest

const WebSocketNetwork = preload("res://game/network/WebSocketNetwork.gd")
const NetworkMessage = preload("res://game/network/NetworkMessage.gd")

var _server_network: WebSocketNetwork
var _client_network: WebSocketNetwork
var _test_port: int = 9949
var _connection_timeout: float = 2.0

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
```

**Step 2: 添加辅助等待方法**

```gdscript
func _wait_for_state(network: WebSocketNetwork, target_state: WebSocketNetwork.ConnectionState, timeout: float = 2.0) -> bool:
	var start_time = Time.get_ticks_msec()
	while network.state != target_state:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			return false
		await get_tree().process_frame
	return true

func _wait_for_signal(sig: Signal, timeout: float = 2.0) -> bool:
	var completed = false
	var timeout_timer = 0.0

	func on_complete():
		nonlocal completed = true

	sig.connect(on_complete)
	var start_time = Time.get_ticks_msec()

	while not completed:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			sig.disconnect(on_complete)
			return false
		await get_tree().process_frame

	sig.disconnect(on_complete)
	return true
```

**Step 3: 运行测试验证框架创建**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: 测试框架无语法错误

---

### Task 2: 服务器功能测试

**Files:**
- Modify: `GodotProject/tests/network/test_network.gd`

**Step 1: 编写 test_server_start_and_stop**

```gdscript
func test_server_start_and_stop():
	var err = _server_network.start_server(_test_port)
	assert_eq(err, OK, "Server should start on port " + str(_test_port))

	# 等待服务器就绪
	var waited = _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)
	assert_true(waited, "Server should be in LISTENING state")

	# 停止服务器
	_server_network.stop_server()
	waited = _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.DISCONNECTED)
	assert_true(waited, "Server should be in DISCONNECTED state after stop")
```

**Step 2: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_server_start_and_stop PASS

**Step 3: 编写 test_get_connected_peers_empty**

```gdscript
func test_get_connected_peers_empty():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	var peers = _server_network.get_connected_peers()
	assert_eq(peers.size(), 0, "Should have no connected peers initially")

	_server_network.stop_server()
```

**Step 4: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_get_connected_peers_empty PASS

**Step 5: 编写 test_broadcast_without_clients**

```gdscript
func test_broadcast_without_clients():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	var msg = NetworkMessage.create_chat("test", "", "sender")
	var err = _server_network.broadcast(msg)
	assert_eq(err, OK, "Broadcast should succeed even without clients")

	_server_network.stop_server()
```

**Step 6: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_broadcast_without_clients PASS

**Step 7: 编写 test_send_to_invalid_peer**

```gdscript
func test_send_to_invalid_peer():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	var msg = NetworkMessage.create_chat("test", "", "sender")
	var err = _server_network.send_to_peer(9999, msg)  # 无效 peer
	assert_ne(err, OK, "Sending to invalid peer should fail")

	_server_network.stop_server()
```

**Step 8: 提交代码**

```bash
git add GodotProject/tests/network/test_network.gd
git commit -m "test: add server functionality tests for WebSocketNetwork"
```

---

### Task 3: 客户端功能测试

**Files:**
- Modify: `GodotProject/tests/network/test_network.gd`

**Step 1: 编写 test_client_connect_and_disconnect**

```gdscript
func test_client_connect_and_disconnect():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 客户端连接
	var err = _client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	assert_eq(err, OK, "Client should initiate connection")

	# 等待连接建立
	var waited = _wait_for_signal(_client_network.connected_to_server, 3.0)
	assert_true(waited, "Client should connect to server")

	# 断开连接
	_client_network.disconnect_from_server()
	waited = _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.DISCONNECTED)
	assert_true(waited, "Client should be disconnected")

	_server_network.stop_server()
```

**Step 2: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_client_connect_and_disconnect PASS

**Step 3: 编写 test_client_connection_state**

```gdscript
func test_client_connection_state():
	# 初始状态
	assert_eq(_client_network.state, WebSocketNetwork.ConnectionState.DISCONNECTED)

	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 连接中状态
	_client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	await _wait_for_signal(_client_network.connected_to_server, 3.0)

	# 已连接状态
	assert_eq(_client_network.state, WebSocketNetwork.ConnectionState.CONNECTED)

	# 断开后
	_client_network.disconnect_from_server()
	await _wait_for_state(_client_network, WebSocketNetwork.ConnectionState.DISCONNECTED)

	_server_network.stop_server()
```

**Step 4: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_client_connection_state PASS

**Step 5: 编写 test_send_without_connection**

```gdscript
func test_send_without_connection():
	var msg = NetworkMessage.create_chat("test", "", "sender")
	var err = _client_network.send_to_server(msg)
	assert_ne(err, OK, "Sending without connection should fail")
```

**Step 6: 提交代码**

```bash
git add GodotProject/tests/network/test_network.gd
git commit -m "test: add client functionality tests for WebSocketNetwork"
```

---

### Task 4: 消息通信测试

**Files:**
- Modify: `GodotProject/tests/network/test_network.gd`

**Step 1: 添加消息接收辅助方法**

```gdscript
var _last_received_message: NetworkMessage = null
var _last_received_peer_id: int = -1

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
		await get_tree().process_frame

	network.message_received.disconnect(_on_message_received)
	return _last_received_message
```

**Step 2: 编写 test_client_to_server_message**

```gdscript
func test_client_to_server_message():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 客户端连接
	_client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	await _wait_for_signal(_client_network.connected_to_server, 3.0)

	# 客户端发送消息
	var sent_msg = NetworkMessage.create_chat("Hello Server", "player1", "Player One")
	var err = _client_network.send_to_server(sent_msg)
	assert_eq(err, OK, "Client should send message successfully")

	# 服务器接收消息
	var received = _await_message(_server_network)
	assert_not_null(received, "Server should receive message")
	assert_eq(received.type, NetworkMessage.MessageType.CHAT, "Message type should be CHAT")
	assert_eq(received.get_string("message"), "Hello Server", "Message content should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()
```

**Step 3: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_client_to_server_message PASS

**Step 4: 编写 test_server_to_client_message**

```gdscript
func test_server_to_client_message():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 客户端连接
	_client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	await _wait_for_signal(_client_network.connected_to_server, 3.0)

	# 获取客户端 peer_id
	var peers = _server_network.get_connected_peers()
	assert_gt(peers.size(), 0, "Should have connected peers")
	var peer_id = peers[0]

	# 服务器发送消息给客户端
	var sent_msg = NetworkMessage.create_chat("Hello Client", "server", "Server")
	var err = _server_network.send_to_peer(peer_id, sent_msg)
	assert_eq(err, OK, "Server should send message successfully")

	# 客户端接收消息
	var received = _await_message(_client_network)
	assert_not_null(received, "Client should receive message")
	assert_eq(received.get_string("message"), "Hello Client", "Message content should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()
```

**Step 5: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_server_to_client_message PASS

**Step 6: 提交代码**

```bash
git add GodotProject/tests/network/test_network.gd
git commit -m "test: add message communication tests for WebSocketNetwork"
```

---

### Task 5: 便捷方法测试

**Files:**
- Modify: `GodotProject/tests/network/test_network.gd`

**Step 1: 编写 test_send_player_joined**

```gdscript
func test_send_player_joined():
	# 启动服务器
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	# 客户端连接
	_client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	await _wait_for_signal(_client_network.connected_to_server, 3.0)

	# 服务器广播玩家加入
	_server_network.send_player_joined(0, "TestPlayer", "player_1")

	# 客户端接收
	var received = _await_message(_client_network)
	assert_not_null(received, "Should receive player joined message")
	assert_eq(received.type, NetworkMessage.MessageType.PLAYER_JOINED, "Message type should be PLAYER_JOINED")
	assert_eq(received.get_int("seat_index"), 0, "Seat index should be 0")
	assert_eq(received.get_string("player_name"), "TestPlayer", "Player name should match")

	# 清理
	_client_network.disconnect_from_server()
	_server_network.stop_server()
```

**Step 2: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_send_player_joined PASS

**Step 3: 编写 test_send_player_ready**

```gdscript
func test_send_player_ready():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	_client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	await _wait_for_signal(_client_network.connected_to_server, 3.0)

	# 服务器广播玩家准备
	_server_network.send_player_ready(2, true)

	# 客户端接收
	var received = _await_message(_client_network)
	assert_not_null(received, "Should receive player ready message")
	assert_eq(received.type, NetworkMessage.MessageType.PLAYER_READY, "Message type should be PLAYER_READY")
	assert_eq(received.get_int("seat_index"), 2, "Seat index should be 2")
	assert_true(received.get_bool("ready"), "Ready status should be true")

	_client_network.disconnect_from_server()
	_server_network.stop_server()
```

**Step 4: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_send_player_ready PASS

**Step 5: 编写 test_send_chat**

```gdscript
func test_send_chat():
	_server_network.start_server(_test_port)
	await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

	_client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
	await _wait_for_signal(_client_network.connected_to_server, 3.0)

	# 客户端发送聊天
	_client_network.send_chat("Hello everyone!", "player_1", "Player One")

	# 服务器接收
	var received = _await_message(_server_network)
	assert_not_null(received, "Should receive chat message")
	assert_eq(received.type, NetworkMessage.MessageType.CHAT, "Message type should be CHAT")
	assert_eq(received.get_string("message"), "Hello everyone!", "Chat content should match")

	_client_network.disconnect_from_server()
	_server_network.stop_server()
```

**Step 6: 运行测试验证**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: test_send_chat PASS

**Step 7: 提交代码**

```bash
git add GodotProject/tests/network/test_network.gd
git commit -m "test: add convenience method tests for WebSocketNetwork"
```

---

### Task 6: 运行完整测试套件

**Files:**
- Run: `GodotProject/tests/run_tests.gd`

**Step 1: 运行所有测试**

Run: `godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd 2>&1`
Expected: 所有测试 PASS

**Step 2: 检查测试覆盖率**

确认以下测试都已通过:
- test_server_start_and_stop
- test_get_connected_peers_empty
- test_broadcast_without_clients
- test_send_to_invalid_peer
- test_client_connect_and_disconnect
- test_client_connection_state
- test_send_without_connection
- test_client_to_server_message
- test_server_to_client_message
- test_send_player_joined
- test_send_player_ready
- test_send_chat

**Step 3: 最终提交**

```bash
git add GodotProject/tests/network/test_network.gd
git commit -m "test: complete WebSocketNetwork integration tests

- Add test fixtures and helper methods
- Add server functionality tests
- Add client functionality tests
- Add message communication tests
- Add convenience method tests

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

**Plan complete and saved to `docs/plans/2026-02-23-network-test-impl.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
