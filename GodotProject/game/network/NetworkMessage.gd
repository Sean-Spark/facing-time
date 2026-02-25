## 通用网络消息类
## 可以用于任何游戏类型的消息传递
class_name NetworkMessage
extends RefCounted

## 消息类型枚举
enum MessageType {
	PING,
	PONG,
	JOIN_GAME,
	LEAVE_GAME,
	READY,
	ROOM_STATE,
	PLAYER_ASSIGNED,
	PLAYER_JOINED,
	PLAYER_LEFT,
	PLAYER_READY,
	GAME_START,
	GAME_END,
	VOTE_TEAM,
	VOTE_TASK,
	ERROR,
	CHAT,
	CUSTOM
}

var type: MessageType = MessageType.PING
var timestamp: float = 0.0
var message_id: String = ""
var _data: Dictionary = {}

func _init(msg_type: MessageType = MessageType.PING):
	type = msg_type
	timestamp = Time.get_unix_time_from_system()
	message_id = _generate_id()

static func _generate_id() -> String:
	return str(Time.get_ticks_msec()) + str(randi())

## ========== 工厂方法 ==========

static func create_ping() -> NetworkMessage:
	return NetworkMessage.new(MessageType.PING)

static func create_pong() -> NetworkMessage:
	return NetworkMessage.new(MessageType.PONG)

static func create_join(player_name: String) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.JOIN_GAME)
	msg._data["player_name"] = player_name
	return msg

static func create_leave(reason: String = "") -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.LEAVE_GAME)
	msg._data["reason"] = reason
	return msg

static func create_ready() -> NetworkMessage:
	return NetworkMessage.new(MessageType.READY)

static func create_room_state(player_count: int, players: Dictionary) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.ROOM_STATE)
	msg._data["player_count"] = player_count
	msg._data["players"] = players
	return msg

static func create_player_joined(seat_index: int, player_name: String, player_id: String = "") -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.PLAYER_JOINED)
	msg._data["seat_index"] = seat_index
	msg._data["player_name"] = player_name
	msg._data["player_id"] = player_id
	return msg

static func create_player_assigned(seat_index: int) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.PLAYER_ASSIGNED)
	msg._data["seat_index"] = seat_index
	return msg

static func create_player_left(seat_index: int, reason: String = "") -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.PLAYER_LEFT)
	msg._data["seat_index"] = seat_index
	msg._data["reason"] = reason
	return msg

static func create_player_ready(seat_index: int, is_ready: bool) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.PLAYER_READY)
	msg._data["seat_index"] = seat_index
	msg._data["ready"] = is_ready
	return msg

static func create_game_start() -> NetworkMessage:
	return NetworkMessage.new(MessageType.GAME_START)

static func create_game_end(winner: String = "", reason: String = "") -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.GAME_END)
	msg._data["winner"] = winner
	msg._data["reason"] = reason
	return msg

static func create_team_vote(approve: bool) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.VOTE_TEAM)
	msg._data["approve"] = approve
	return msg

static func create_task_vote(approve: bool) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.VOTE_TASK)
	msg._data["approve"] = approve
	return msg

static func create_chat(message: String, sender_id: String = "", sender_name: String = "") -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.CHAT)
	msg._data["message"] = message
	msg._data["sender_id"] = sender_id
	msg._data["sender_name"] = sender_name
	return msg

static func create_error(error_message: String, original_type: MessageType = MessageType.PING) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.ERROR)
	msg._data["error_message"] = error_message
	msg._data["original_type"] = original_type
	return msg

## 创建自定义消息
static func create_custom(msg_type: int, data: Dictionary = {}) -> NetworkMessage:
	var msg := NetworkMessage.new(MessageType.CUSTOM)
	msg._data["custom_type"] = msg_type
	msg._data.merge(data, true)
	return msg

## ========== 序列化与反序列化 ==========

func serialize() -> Dictionary:
	return {
		"type": type,
		"timestamp": timestamp,
		"message_id": message_id,
		"data": _data
	}

func to_json() -> String:
	return JSON.stringify(serialize())

static func deserialize(data: Dictionary) -> NetworkMessage:
	var msg_type = data.get("type", MessageType.PING)
	var msg := NetworkMessage.new(msg_type)
	msg.timestamp = data.get("timestamp", 0.0)
	msg.message_id = data.get("message_id", "")
	msg._data = data.get("data", {})
	return msg

static func from_json(json_string: String) -> NetworkMessage:
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return null
	return deserialize(json.get_data())

## ========== 数据访问方法 ==========

func get_int(key: String, default: int = 0) -> int:
	return _data.get(key, default)

func get_bool(key: String, default: bool = false) -> bool:
	return _data.get(key, default)

func get_string(key: String, default: String = "") -> String:
	return _data.get(key, default)

func get_array(key: String) -> Array:
	return _data.get(key, [])

func get_dictionary(key: String) -> Dictionary:
	return _data.get(key, {})

## ========== 调试 ==========

func _to_string() -> String:
	return "NetworkMessage{type=%s, id=%s, data=%s}" % [MessageType.keys()[type], message_id, str(_data)]
