extends GutTest

const SeatData = preload("res://game/models/SeatData.gd")
const PlayerData = preload("res://game/models/PlayerData.gd")

func test_seat_is_empty_initially():
	var seat = SeatData.new(0)
	assert_true(seat.is_empty(), "New seat should be empty")

func test_seat_assignment():
	var seat = SeatData.new(0)
	var player = PlayerData.new("id1", "TestPlayer", 0)
	seat.assign_player(player)
	assert_false(seat.is_empty(), "Seat should not be empty after assignment")
	assert_eq(seat.player, player, "Player should be assigned to seat")
	assert_eq(player.seat_index, 0, "Player seat index should be updated")

func test_seat_clear():
	var seat = SeatData.new(0)
	var player = PlayerData.new("id1", "TestPlayer", 0)
	seat.assign_player(player)
	seat.clear_player()
	assert_true(seat.is_empty(), "Seat should be empty after clear")
	assert_null(seat.player, "Player reference should be null")
	assert_eq(player.seat_index, -1, "Player seat index should be reset to -1")

func test_seat_index_initialization():
	var seat = SeatData.new(5)
	assert_eq(seat.index, 5, "Seat index should be initialized correctly")

func test_assign_to_different_seat():
	var seat1 = SeatData.new(0)
	var seat2 = SeatData.new(1)
	var player = PlayerData.new("id1", "TestPlayer", -1)
	seat1.assign_player(player)
	assert_eq(player.seat_index, 0, "Player should be in seat 0")
	seat1.clear_player()
	seat2.assign_player(player)
	assert_eq(player.seat_index, 1, "Player should now be in seat 1")
	assert_true(seat1.is_empty(), "Seat 1 should be empty after clearing")
	assert_false(seat2.is_empty(), "Seat 2 should not be empty")
