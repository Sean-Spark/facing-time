class_name GameRoomViewModel
extends ViewModelBase

signal connection_state_changed(state: int)
signal room_state_updated(room_data: RoomData)
signal player_joined(player: PlayerData)
signal player_left(seat_index: int)
signal player_ready_changed(seat_index: int, is_ready: bool)
signal all_players_ready
signal game_start_triggered()
signal error_occurred(message: String)

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	ERROR
}

var connection_state: int = ConnectionState.DISCONNECTED:
	set(v):
		connection_state = v
		connection_state_changed.emit(v)

var room_data: RoomData = null
var current_player: PlayerData = null
var validation_errors: Dictionary = {}

var _network = null

func _ready():
	_network = get_tree().get_first_node_in_group("NetworkManager")
	if _network:
		_network.message_received.connect(_on_network_message)
		_network.connection_state_changed.connect(_on_connection_state_changed)
		_network.error_occurred.connect(_on_error)

func start_host(port: int, player_name: String, player_count: int) -> bool:
	if not _validate_host_init(port, player_name, player_count):
		return false

	if _network.start_server(port) == OK:
		room_data = RoomData.new(player_count)
		current_player = PlayerData.new(str(Time.get_unix_time_from_system()), player_name, 0)
		room_data.get_seat(0).assign_player(current_player)
		connection_state = ConnectionState.CONNECTED
		return true
	return false

func connect_to_host(url: String, player_name: String) -> bool:
	if player_name.is_empty():
		validation_errors["player_name"] = "Player name is required"
		error_occurred.emit("Player name is required")
		return false

	if _network.connect_to_server(url) == OK:
		current_player = PlayerData.new(str(Time.get_unix_time_from_system()), player_name)
		connection_state = ConnectionState.CONNECTING
		return true
	return false

func select_seat(seat_index: int) -> bool:
	if not room_data or not current_player:
		return false

	var seat = room_data.get_seat(seat_index)
	if not seat or not seat.is_empty():
		return false

	# Clear current position
	if current_player.seat_index >= 0:
		var old_seat = room_data.get_seat(current_player.seat_index)
		if old_seat:
			old_seat.clear_player()

	seat.assign_player(current_player)

	# Send network message
	var msg = NetworkMessage.create_player_joined(seat_index, current_player.name)
	_network.send_to_server(msg)

	room_state_updated.emit(room_data)
	return true

func toggle_ready() -> bool:
	if not current_player or current_player.seat_index < 0:
		return false

	current_player.is_ready = not current_player.is_ready

	var msg = NetworkMessage.create_player_ready(current_player.seat_index, current_player.is_ready)
	_network.send_to_server(msg)

	player_ready_changed.emit(current_player.seat_index, current_player.is_ready)

	# Check if all ready
	if room_data.is_all_ready():
		all_players_ready.emit()
		var start_msg = NetworkMessage.create_game_start()
		_network.broadcast(start_msg)
		game_start_triggered.emit()

	return true

func leave_room():
	if _network:
		_network.disconnect_network()
	_reset_state()

func _validate_host_init(port: int, player_name: String, player_count: int) -> bool:
	validation_errors.clear()

	if port < 1 or port > 65535:
		validation_errors["port"] = "Port must be between 1 and 65535"
	if player_name.is_empty():
		validation_errors["player_name"] = "Player name is required"
	if player_count < 5 or player_count > 10:
		validation_errors["player_count"] = "Player count must be between 5 and 10"

	if not validation_errors.is_empty():
		var first_error = validation_errors.values()[0]
		error_occurred.emit(first_error)
		return false
	return true

func _on_network_message(msg: NetworkMessage):
	match msg.type:
		NetworkMessage.MessageType.ROOM_STATE:
			_handle_room_state(msg)
		NetworkMessage.MessageType.PLAYER_JOINED:
			_handle_player_join(msg)
		NetworkMessage.MessageType.PLAYER_READY:
			_handle_player_ready(msg)
		NetworkMessage.MessageType.GAME_START:
			game_start_triggered.emit()
		NetworkMessage.MessageType.PLAYER_LEFT:
			_handle_player_leave(msg)

func _handle_room_state(msg: NetworkMessage):
	if not room_data:
		room_data = RoomData.new(msg.get_int("player_count", 5))

	var players = msg.get_dictionary("players")
	for seat_idx_str in players:
		var seat_idx = int(seat_idx_str)
		var player_name = players[seat_idx_str]
		var seat = room_data.get_seat(seat_idx)
		if seat and seat.is_empty():
			var player = PlayerData.new(str(seat_idx), player_name, seat_idx)
			seat.assign_player(player)

	room_state_updated.emit(room_data)

func _handle_player_join(msg: NetworkMessage):
	var seat_index = msg.get_int("seat_index", -1)
	var player_name = msg.get_string("player_name", "Unknown")
	var seat = room_data.get_seat(seat_index)
	if seat and seat.is_empty():
		var player = PlayerData.new(str(seat_index), player_name, seat_index)
		seat.assign_player(player)
		player_joined.emit(player)
	room_state_updated.emit(room_data)

func _handle_player_ready(msg: NetworkMessage):
	var seat_index = msg.get_int("seat_index", -1)
	var is_ready = msg.get_bool("ready", false)
	var seat = room_data.get_seat(seat_index)
	if seat and seat.player:
		seat.player.is_ready = is_ready
		player_ready_changed.emit(seat_index, is_ready)
		if room_data.is_all_ready():
			all_players_ready.emit()

func _handle_player_leave(msg: NetworkMessage):
	var seat_index = msg.get_int("seat_index", -1)
	var seat = room_data.get_seat(seat_index)
	if seat:
		seat.clear_player()
		player_left.emit(seat_index)
		room_state_updated.emit(room_data)

func _on_connection_state_changed(state: int):
	connection_state = state

func _on_error(message: String):
	error_occurred.emit(message)

func _reset_state():
	room_data = null
	current_player = null
	connection_state = ConnectionState.DISCONNECTED
