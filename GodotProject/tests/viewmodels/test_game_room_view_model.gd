extends GutTest

const GameRoomViewModel = preload("res://game/viewmodels/GameRoomViewModel.gd")
const RoomData = preload("res://game/models/RoomData.gd")
const PlayerData = preload("res://game/models/PlayerData.gd")

var _mock_network: _MockNetwork
var _vm: GameRoomViewModel

class _MockNetwork extends RefCounted:
	var _messages = []
	var _connection_state = 0
	var _connected = false
	var _start_host_result = true
	var _connect_result = true

	func start_server(port) -> int:
		return OK if _start_host_result else ERR_CONNECTION_ERROR

	func connect_to_server(url) -> int:
		return OK if _connect_result else ERR_CONNECTION_ERROR

	func send_message(msg) -> bool:
		_messages.append(msg)
		return true

	func send_to_server(msg) -> void:
		_messages.append(msg)

	func broadcast(msg) -> void:
		_messages.append(msg)

	func disconnect_network():
		_connected = false

	func get_connection_state() -> int:
		return _connection_state

	func get_connected() -> bool:
		return _connected

	func set_start_host_result(result: bool):
		_start_host_result = result

	func set_connect_result(result: bool):
		_connect_result = result

func before_each():
	_mock_network = _MockNetwork.new()
	_vm = GameRoomViewModel.new()

func after_each():
	_vm = null
	_mock_network = null

func test_viewmodel_initial_state():
	assert_eq(_vm.connection_state, GameRoomViewModel.ConnectionState.DISCONNECTED,
		"Initial connection state should be DISCONNECTED")
	assert_null(_vm.room_data, "Room data should be null initially")
	assert_null(_vm.current_player, "Current player should be null initially")
	assert_true(_vm.validation_errors.is_empty(), "Validation errors should be empty initially")

func test_host_creation_success():
	_vm._network = _mock_network
	var result = _vm.start_host(8080, "TestHost", 5)
	assert_true(result, "Host creation should succeed with valid parameters")
	assert_eq(_vm.connection_state, GameRoomViewModel.ConnectionState.CONNECTED,
		"Connection state should be CONNECTED after host creation")
	assert_not_null(_vm.room_data, "Room data should be created")
	assert_not_null(_vm.current_player, "Current player should be created")
	assert_eq(_vm.current_player.name, "TestHost", "Player name should match")
	assert_eq(_vm.room_data.player_count, 5, "Player count should match")
	assert_eq(_vm.current_player.seat_index, 0, "Host should be assigned seat 0")

func test_host_creation_invalid_port():
	_vm._network = _mock_network
	var result = _vm.start_host(0, "TestHost", 5)
	assert_false(result, "Host creation should fail with invalid port")
	assert_true(_vm.validation_errors.has("port"), "Should have port validation error")
	assert_null(_vm.room_data, "Room data should not be created")

func test_host_creation_empty_name():
	_vm._network = _mock_network
	var result = _vm.start_host(8080, "", 5)
	assert_false(result, "Host creation should fail with empty name")
	assert_true(_vm.validation_errors.has("player_name"), "Should have player_name validation error")

func test_host_creation_invalid_player_count():
	_vm._network = _mock_network
	var result = _vm.start_host(8080, "TestHost", 3)
	assert_false(result, "Host creation should fail with player count < 5")
	result = _vm.start_host(8080, "TestHost", 11)
	assert_false(result, "Host creation should fail with player count > 10")

func test_seat_selection_success():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	_vm.room_data.get_seat(0).clear_player()
	_vm.current_player.seat_index = -1
	var result = _vm.select_seat(2)
	assert_true(result, "Seat selection should succeed")
	assert_eq(_vm.current_player.seat_index, 2, "Player should be assigned to seat 2")

func test_seat_selection_invalid_seat():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	var result = _vm.select_seat(10)
	assert_false(result, "Selecting invalid seat should fail")

func test_seat_selection_occupied_seat():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	# Try to select seat 0 which is already occupied by host
	var result = _vm.select_seat(0)
	assert_false(result, "Selecting occupied seat should fail")

func test_toggle_ready_success():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	assert_false(_vm.current_player.is_ready, "Player should not be ready initially")
	var result = _vm.toggle_ready()
	assert_true(result, "Toggle ready should succeed")
	assert_true(_vm.current_player.is_ready, "Player should be ready after toggle")
	_vm.toggle_ready()
	assert_false(_vm.current_player.is_ready, "Player should not be ready after second toggle")

func test_toggle_ready_no_seat():
	var result = _vm.toggle_ready()
	assert_false(result, "Toggle ready should fail without seat")

func test_connect_to_host_success():
	_vm._network = _mock_network
	_vm.connect_to_host("ws://localhost:8080", "TestPlayer")
	assert_eq(_vm.connection_state, GameRoomViewModel.ConnectionState.CONNECTING,
		"Connection state should be CONNECTING")
	assert_not_null(_vm.current_player, "Current player should be created")
	assert_eq(_vm.current_player.name, "TestPlayer", "Player name should match")

func test_connect_to_host_empty_name():
	_vm._network = _mock_network
	var result = _vm.connect_to_host("ws://localhost:8080", "")
	assert_false(result, "Connection should fail with empty name")
	assert_true(_vm.validation_errors.has("player_name"), "Should have validation error")

func test_leave_room():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	assert_not_null(_vm.room_data, "Should have room data")
	assert_not_null(_vm._network, "Should have network")
	_vm.leave_room()
	assert_null(_vm.room_data, "Room data should be cleared")
	assert_null(_vm.current_player, "Current player should be cleared")
	assert_eq(_vm.connection_state, GameRoomViewModel.ConnectionState.DISCONNECTED,
		"Connection state should be DISCONNECTED")

func test_handle_player_join():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	# Directly assign player to seat
	var player = PlayerData.new("p1", "NewPlayer", 1)
	_vm.room_data.get_seat(1).assign_player(player)
	var seat = _vm.room_data.get_seat(1)
	assert_not_null(seat.player, "Seat should have player")
	assert_eq(seat.player.name, "NewPlayer", "Player name should match")

func test_handle_player_ready():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	_vm.current_player.is_ready = false
	_vm.toggle_ready()
	assert_true(_vm.current_player.is_ready, "Player should be ready")

func test_handle_player_leave():
	_vm._network = _mock_network
	_vm.start_host(8080, "Host", 5)
	_vm.room_data.get_seat(0).clear_player()
	var seat = _vm.room_data.get_seat(0)
	assert_true(seat.is_empty(), "Seat should be empty after player leaves")
