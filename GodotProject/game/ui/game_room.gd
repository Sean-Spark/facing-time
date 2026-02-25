class_name GameRoomUI
extends Control

signal sig_player_ready(seat_index: int, is_ready: bool)
signal sig_seat_selected(seat_index: int, player_name: String)
signal sig_seat_deselected(seat_index: int)
signal sig_leave_room()
signal sig_game_started()

var seats_container: HBoxContainer:
	get:
		return $Panel/VBoxContainer/SeatsScroll/SeatsContainer

var status_label: Label:
	get:
		return $Panel/VBoxContainer/StatusLabel

var ready_button: Button:
	get:
		return $Panel/VBoxContainer/ReadyButton

var leave_button: Button:
	get:
		return $Panel/VBoxContainer/LeaveButton

var player_count: int = 5
var player_name: String = ""
var local_seat_index: int = -1
var is_local_ready: bool = false
var seat_players: Array[String] = []
var seat_ready_states: Array[bool] = []

func setup(total_seats: int, username: String) -> void:
	player_count = total_seats
	player_name = username
	seat_players.resize(total_seats)
	seat_ready_states.resize(total_seats)
	seat_players.fill("")
	seat_ready_states.fill(false)

	# 清理旧的座位
	_clear_seats()

	# 初始隐藏准备按钮
	ready_button.visible = false

	_create_seats()


func _clear_seats() -> void:
	# 清理已有的座位
	for child in seats_container.get_children():
		child.queue_free()

func _create_seats() -> void:
	for i: int in range(player_count):
		var seat_panel: Panel = Panel.new()
		seat_panel.custom_minimum_size = Vector2(100, 120)
		seat_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 10)

		var seat_label: Label = Label.new()
		seat_label.name = "SeatLabel"
		seat_label.text = "座位 " + str(i + 1)
		seat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = ""
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.y = 40

		var ready_label: Label = Label.new()
		ready_label.name = "ReadyLabel"
		ready_label.text = ""
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		vbox.add_child(seat_label, true)
		vbox.add_child(name_label, true)
		vbox.add_child(ready_label, true)
		seat_panel.add_child(vbox, true)

		seat_panel.set_meta("seat_index", i)
		seat_panel.gui_input.connect(_on_seat_input.bind(i))

		# 默认样式（未选择）
		_update_seat_style(seat_panel, false)

		seats_container.add_child(seat_panel)

func _on_seat_input(event: InputEvent, seat_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if local_seat_index == -1:
			_select_seat(seat_index)
		elif local_seat_index == seat_index:
			_deselect_seat()

func _select_seat(seat_index: int) -> void:
	# 如果座位已被其他玩家占用，不能选择
	if seat_players[seat_index] != "" and seat_players[seat_index] != player_name:
		status_label.text = "该座位已被占用"
		return

	# 如果之前有选择，先取消
	_deselect_seat()

	# 占据座位
	seat_players[seat_index] = player_name
	local_seat_index = seat_index

	# 更新座位视觉效果
	var seat_panel: Panel = seats_container.get_child(seat_index)
	_update_seat_style(seat_panel, true)

	# 更新座位上的名字显示
	_update_seat_name_label(seat_index, player_name)

	# 显示准备按钮
	ready_button.visible = true
	ready_button.text = "准备"
	is_local_ready = false

	status_label.text = "已选择座位 " + str(seat_index + 1)

	# 通知主机广播玩家加入
	sig_seat_selected.emit(seat_index, player_name)

func _deselect_seat() -> void:
	if local_seat_index >= 0:
		var previous_seat: int = local_seat_index

		# 清除座位占用
		seat_players[local_seat_index] = ""
		seat_ready_states[local_seat_index] = false

		var seat_panel: Panel = seats_container.get_child(local_seat_index)
		_update_seat_style(seat_panel, false)

		# 清空座位上的名字
		_update_seat_name_label(local_seat_index, "")

		# 隐藏准备按钮
		ready_button.visible = false
		is_local_ready = false

		local_seat_index = -1
		status_label.text = "请选择一个座位"

		# 通知主机广播玩家离开
		sig_seat_deselected.emit(previous_seat)

func _update_seat_style(seat_panel: Panel, selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	if selected:
		style.bg_color = Color(0.2, 0.6, 0.3, 0.8)
	else:
		style.bg_color = Color(0.25, 0.25, 0.25, 0.6)

	style.set_border_width_all(2)
	style.set_corner_radius_all(8)

	seat_panel.add_theme_stylebox_override("panel", style)

func _update_seat_name_label(seat_index: int, username: String) -> void:
	var seat_panel: Panel = seats_container.get_child(seat_index)
	var vbox: VBoxContainer = seat_panel.get_node("VBoxContainer")
	var name_label: Label = vbox.get_node("NameLabel")
	name_label.text = username

func update_player_name(seat_index: int, username: String) -> void:
	if seat_index < 0 or seat_index >= player_count:
		return

	# 确保数组大小足够
	if seat_index >= seat_players.size():
		seat_players.resize(seat_index + 1)
		seat_players.fill("")

	seat_players[seat_index] = username

	# 如果是自己选择的座位，更新显示
	if seat_index == local_seat_index and username == "":
		# 被其他玩家取消
		_deselect_seat()
	else:
		_update_seat_name_label(seat_index, username)

func update_ready_state(seat_index: int, user_ready: bool) -> void:
	if seat_index < 0 or seat_index >= player_count:
		return

	seat_ready_states[seat_index] = user_ready

	var seat_panel: Panel = seats_container.get_child(seat_index)
	var vbox: VBoxContainer = seat_panel.get_node("VBoxContainer")
	var ready_label: Label = vbox.get_node("ReadyLabel")

	if seat_players[seat_index] != "":
		ready_label.text = "✓" if user_ready else ""
		ready_label.modulate = Color.GREEN if user_ready else Color.WHITE
	else:
		ready_label.text = ""

	_check_all_ready()

func _check_all_ready() -> void:
	var all_ready: bool = true
	var has_players: bool = false

	for i: int in range(player_count):
		if seat_players[i] != "":
			has_players = true
			if not seat_ready_states[i]:
				all_ready = false
				break

	if all_ready and has_players:
		status_label.text = "所有玩家已准备，游戏即将开始！"
		sig_game_started.emit()
	else:
		status_label.text = "等待玩家准备..."

func _on_ready_pressed() -> void:
	if local_seat_index < 0:
		return

	is_local_ready = not is_local_ready

	# 切换按钮文字
	if is_local_ready:
		ready_button.text = "取消准备"
	else:
		ready_button.text = "准备"

	sig_player_ready.emit(local_seat_index, is_local_ready)

func _on_leave_pressed() -> void:
	# 离开时取消座位占用
	if local_seat_index >= 0:
		seat_players[local_seat_index] = ""
		seat_ready_states[local_seat_index] = false

	sig_leave_room.emit()

func set_local_player_seat(seat_index: int) -> void:
	if seat_index < 0 or seat_index >= player_count:
		return

	# 检查数组是否已初始化
	if seat_players.is_empty() or seat_index >= seat_players.size():
		return

	if seat_players[seat_index] != "" and seat_players[seat_index] != player_name:
		return

	_select_seat(seat_index)

func get_local_seat() -> int:
	return local_seat_index

func is_local_player_ready() -> bool:
	return is_local_ready

func set_status(text: String) -> void:
	status_label.text = text
	print_debug(text)
