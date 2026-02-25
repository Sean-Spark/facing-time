class_name SeatData
extends RefCounted

var index: int = 0
var player: PlayerData = null

func _init(seat_index: int = 0):
	index = seat_index

func is_empty() -> bool:
	return player == null

func assign_player(p: PlayerData) -> void:
	player = p
	player.seat_index = index

func clear_player() -> void:
	if player:
		player.seat_index = -1
		player = null
