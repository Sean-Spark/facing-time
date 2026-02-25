class_name PlayerData
extends RefCounted

var id: String = ""
var name: String = ""
var seat_index: int = -1
var is_ready: bool = false

func _init(p_id: String = "", p_name: String = "", p_seat: int = -1):
	id = p_id
	name = p_name
	seat_index = p_seat

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"seat_index": seat_index,
		"is_ready": is_ready
	}

static func from_dict(data: Dictionary) -> PlayerData:
	var player = PlayerData.new(
		data.get("id", ""),
		data.get("name", ""),
		data.get("seat_index", -1)
	)
	player.is_ready = data.get("is_ready", false)
	return player
