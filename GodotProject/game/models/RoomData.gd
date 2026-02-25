class_name RoomData
extends RefCounted

var room_id: String = ""
var player_count: int = 5
var seats: Array[SeatData] = []
var host_name: String = ""

func _init(count: int = 5):
	player_count = count
	for i in range(count):
		seats.append(SeatData.new(i))

func get_seat(index: int) -> SeatData:
	if index >= 0 and index < seats.size():
		return seats[index]
	return null

func find_empty_seat() -> SeatData:
	for seat in seats:
		if seat.is_empty():
			return seat
	return null

func get_all_players() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for seat in seats:
		if not seat.is_empty():
			result.append(seat.player)
	return result

func is_all_ready() -> bool:
	for seat in seats:
		if not seat.is_empty() and not seat.player.is_ready:
			return false
	return get_all_players().size() > 0
