extends GutTest

const NetworkMessage = preload("res://game/network/NetworkMessage.gd")

# ========== NetworkMessage 单元测试 ==========

func test_create_ping():
	var msg = NetworkMessage.create_ping()
	assert_eq(msg.type, NetworkMessage.MessageType.PING, "Type should be PING")
	assert_true(msg.message_id != "", "Should have message id")

func test_create_pong():
	var msg = NetworkMessage.create_pong()
	assert_eq(msg.type, NetworkMessage.MessageType.PONG, "Type should be PONG")

func test_create_join():
	var msg = NetworkMessage.create_join("TestPlayer")
	assert_eq(msg.type, NetworkMessage.MessageType.JOIN_GAME, "Type should be JOIN_GAME")
	assert_eq(msg.get_string("player_name"), "TestPlayer", "Player name should match")

func test_create_leave():
	var msg = NetworkMessage.create_leave("disconnected")
	assert_eq(msg.type, NetworkMessage.MessageType.LEAVE_GAME, "Type should be LEAVE_GAME")
	assert_eq(msg.get_string("reason"), "disconnected", "Reason should match")

func test_create_room_state():
	var players = {"1": "Player1", "2": "Player2"}
	var msg = NetworkMessage.create_room_state(2, players)
	assert_eq(msg.type, NetworkMessage.MessageType.ROOM_STATE, "Type should be ROOM_STATE")
	assert_eq(msg.get_int("player_count"), 2, "Player count should be 2")
	assert_eq(msg.get_dictionary("players").size(), 2, "Should have 2 players")

func test_create_player_joined():
	var msg = NetworkMessage.create_player_joined(0, "TestPlayer", "player_1")
	assert_eq(msg.type, NetworkMessage.MessageType.PLAYER_JOINED, "Type should be PLAYER_JOINED")
	assert_eq(msg.get_int("seat_index"), 0, "Seat index should be 0")
	assert_eq(msg.get_string("player_name"), "TestPlayer", "Player name should match")
	assert_eq(msg.get_string("player_id"), "player_1", "Player id should match")

func test_create_player_left():
	var msg = NetworkMessage.create_player_left(1, "left game")
	assert_eq(msg.type, NetworkMessage.MessageType.PLAYER_LEFT, "Type should be PLAYER_LEFT")
	assert_eq(msg.get_int("seat_index"), 1, "Seat index should be 1")
	assert_eq(msg.get_string("reason"), "left game", "Reason should match")

func test_create_player_ready():
	var msg = NetworkMessage.create_player_ready(2, true)
	assert_eq(msg.type, NetworkMessage.MessageType.PLAYER_READY, "Type should be PLAYER_READY")
	assert_eq(msg.get_int("seat_index"), 2, "Seat index should be 2")
	assert_true(msg.get_bool("ready"), "Ready should be true")

func test_create_game_start():
	var msg = NetworkMessage.create_game_start()
	assert_eq(msg.type, NetworkMessage.MessageType.GAME_START, "Type should be GAME_START")

func test_create_game_end():
	var msg = NetworkMessage.create_game_end("Good", "Time up")
	assert_eq(msg.type, NetworkMessage.MessageType.GAME_END, "Type should be GAME_END")
	assert_eq(msg.get_string("winner"), "Good", "Winner should match")
	assert_eq(msg.get_string("reason"), "Time up", "Reason should match")

func test_create_team_vote():
	var msg = NetworkMessage.create_team_vote(true)
	assert_eq(msg.type, NetworkMessage.MessageType.VOTE_TEAM, "Type should be VOTE_TEAM")
	assert_true(msg.get_bool("approve"), "Approve should be true")

func test_create_task_vote():
	var msg = NetworkMessage.create_task_vote(false)
	assert_eq(msg.type, NetworkMessage.MessageType.VOTE_TASK, "Type should be VOTE_TASK")
	assert_false(msg.get_bool("approve"), "Approve should be false")

func test_create_chat():
	var msg = NetworkMessage.create_chat("Hello!", "player_1", "Player One")
	assert_eq(msg.type, NetworkMessage.MessageType.CHAT, "Type should be CHAT")
	assert_eq(msg.get_string("message"), "Hello!", "Message should match")
	assert_eq(msg.get_string("sender_id"), "player_1", "Sender id should match")
	assert_eq(msg.get_string("sender_name"), "Player One", "Sender name should match")

func test_create_error():
	var msg = NetworkMessage.create_error("Something went wrong", NetworkMessage.MessageType.JOIN_GAME)
	assert_eq(msg.type, NetworkMessage.MessageType.ERROR, "Type should be ERROR")
	assert_eq(msg.get_string("error_message"), "Something went wrong", "Error message should match")
	assert_eq(msg.get_int("original_type"), NetworkMessage.MessageType.JOIN_GAME, "Original type should match")

func test_create_custom():
	var data = {"key1": "value1", "key2": 123}
	var msg = NetworkMessage.create_custom(999, data)
	assert_eq(msg.type, NetworkMessage.MessageType.CUSTOM, "Type should be CUSTOM")
	assert_eq(msg.get_int("custom_type"), 999, "Custom type should match")
	assert_eq(msg.get_string("key1"), "value1", "Custom data should match")
	assert_eq(msg.get_int("key2"), 123, "Custom data should match")

func test_serialize():
	var msg = NetworkMessage.create_chat("test", "id", "name")
	var serialized = msg.serialize()
	assert_true(serialized.has("type"), "Should have type key")
	assert_true(serialized.has("timestamp"), "Should have timestamp key")
	assert_true(serialized.has("message_id"), "Should have message_id key")
	assert_true(serialized.has("data"), "Should have data key")

func test_to_json():
	var msg = NetworkMessage.create_chat("test", "id", "name")
	var json = msg.to_json()
	# 打印实际输出以便调试
	print("JSON output: ", json)
	# CHAT = 15
	assert_true(json.contains('"type":15') or json.contains('"type": 15'), "JSON should contain message type as number")
	assert_true(json.contains("test"), "JSON should contain message content")

func test_deserialize():
	var original = NetworkMessage.create_chat("test", "id", "name")
	var serialized = original.serialize()
	var deserialized = NetworkMessage.deserialize(serialized)
	assert_eq(deserialized.type, original.type, "Type should match")
	assert_eq(deserialized.get_string("message"), "test", "Message should match")

func test_from_json():
	# CHAT = 15
	var json_string = '{"type": 15, "timestamp": 1234567890.0, "message_id": "test123", "data": {"message": "hello"}}'
	var msg = NetworkMessage.from_json(json_string)
	assert_eq(msg.type, 15, "Type value should be 15 (CHAT)")
	assert_eq(msg.get_string("message"), "hello", "Message should match")

func test_from_json_invalid():
	var msg = NetworkMessage.from_json("invalid json")
	assert_null(msg, "Should return null for invalid JSON")

func test_get_int_default():
	var msg = NetworkMessage.new()
	assert_eq(msg.get_int("nonexistent"), 0, "Default should be 0")
	assert_eq(msg.get_int("nonexistent", 5), 5, "Should return provided default")

func test_get_bool_default():
	var msg = NetworkMessage.new()
	assert_eq(msg.get_bool("nonexistent"), false, "Default should be false")
	assert_true(msg.get_bool("nonexistent", true), "Should return provided default")

func test_get_string_default():
	var msg = NetworkMessage.new()
	assert_eq(msg.get_string("nonexistent"), "", "Default should be empty string")
	assert_eq(msg.get_string("nonexistent", "default"), "default", "Should return provided default")

func test_get_array_default():
	var msg = NetworkMessage.new()
	assert_eq(msg.get_array("nonexistent"), [], "Default should be empty array")

func test_get_dictionary_default():
	var msg = NetworkMessage.new()
	assert_eq(msg.get_dictionary("nonexistent"), {}, "Default should be empty dictionary")
