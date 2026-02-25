extends Control


## UI状态枚举
enum UIState { SELECT_MODE, HOST_INIT, CLIENT_INIT, GAME_ROOM }

var current_state: UIState = UIState.SELECT_MODE
var is_host: bool = false

## 玩家信息
var player_name: String = ""
var local_seat_index: int = -1

## 子系统
var network: WebSocketNetwork
var game_room_view_model: GameRoomViewModel

## UI节点引用
@onready var select_mode: SelectMode = $SelectMode
@onready var host_init: HostInitUI = $HostInit
@onready var client_init: ClientInitUI = $ClientInit
@onready var game_room: GameRoomUI = $GameRoom

@onready var network_layer: Node = $NetworkLayer
@onready var room_layer: Node = $RoomLayer


func _ready() -> void:
	_init_subsystems()
	_static_server_setup()
	_connect_ui_signals()
	_show_ui(UIState.SELECT_MODE)


func _init_subsystems() -> void:
	# 初始化网络层
	network = WebSocketNetwork.new()
	network.add_to_group("NetworkManager")
	network_layer.add_child(network)

	# 初始化 GameRoomViewModel
	game_room_view_model = GameRoomViewModel.new()
	room_layer.add_child(game_room_view_model)

	# 连接 GameRoomViewModel 信号
	game_room_view_model.connection_state_changed.connect(_on_viewmodel_connection_state_changed)
	game_room_view_model.room_state_updated.connect(_on_viewmodel_room_state_updated)
	game_room_view_model.player_joined.connect(_on_viewmodel_player_joined)
	game_room_view_model.player_left.connect(_on_viewmodel_player_left)
	game_room_view_model.player_ready_changed.connect(_on_viewmodel_player_ready_changed)
	game_room_view_model.all_players_ready.connect(_on_viewmodel_all_players_ready)
	game_room_view_model.game_start_triggered.connect(_on_viewmodel_game_start_triggered)
	game_room_view_model.error_occurred.connect(_on_viewmodel_error)


func _static_server_setup() -> void:
	if OS.has_feature("web"):
		return
	var rust_core_server_script = load("res://game/server/wrap_rust_core_server.gd")
	var instance = rust_core_server_script.new()
	instance.setup()


func _connect_ui_signals() -> void:
	# 选择模式
	select_mode.sig_go_to_host_init.connect(_on_go_to_host_init)
	select_mode.sig_go_to_client_init.connect(_on_go_to_client_init)
	select_mode.sig_go_back.connect(_on_go_back)

	# 主机初始化
	host_init.sig_service_started.connect(_on_service_started)
	host_init.sig_go_back.connect(_on_go_back_to_select)

	# 客户端初始化
	client_init.sig_connect_to_server.connect(_on_connect_to_server)
	client_init.sig_go_back.connect(_on_go_back_to_select)

	# 游戏房间
	game_room.sig_player_ready.connect(_on_game_room_player_ready)
	game_room.sig_seat_selected.connect(_on_game_room_seat_selected)
	game_room.sig_seat_deselected.connect(_on_game_room_seat_deselected)
	game_room.sig_leave_room.connect(_on_leave_room)


func _show_ui(state: UIState) -> void:
	current_state = state
	select_mode.visible = (state == UIState.SELECT_MODE)
	host_init.visible = (state == UIState.HOST_INIT)
	client_init.visible = (state == UIState.CLIENT_INIT)
	game_room.visible = (state == UIState.GAME_ROOM)


## 选择模式回调
func _on_go_to_host_init() -> void:
	is_host = true
	_show_ui(UIState.HOST_INIT)


func _on_go_to_client_init() -> void:
	is_host = false
	_show_ui(UIState.CLIENT_INIT)


func _on_go_back() -> void:
	queue_free()


func _on_go_back_to_select() -> void:
	_show_ui(UIState.SELECT_MODE)


## 主机初始化回调
func _on_service_started(count: int, username: String) -> void:
	player_name = username

	# 初始化 GameRoomViewModel 作为主机
	game_room_view_model.start_host(host_init.get_port(), player_name, count)

	# 初始化游戏房间UI
	game_room.setup(count, player_name)
	_show_ui(UIState.GAME_ROOM)


## 客户端初始化回调
func _on_connect_to_server(username: String) -> void:
	player_name = username

	# 初始化 GameRoomViewModel 作为客户端
	game_room_view_model.connect_to_host(client_init.get_server_url(), player_name)

	client_init.set_status("正在连接...")


## GameRoomViewModel 信号处理
func _on_viewmodel_connection_state_changed(state: int) -> void:
	match state:
		GameRoomViewModel.ConnectionState.CONNECTED:
			_show_ui(UIState.GAME_ROOM)
		GameRoomViewModel.ConnectionState.ERROR:
			client_init.set_status("连接错误")


func _on_viewmodel_room_state_updated(room_data: RoomData) -> void:
	# 如果 UI 座位数量与房间不匹配，重新初始化 UI
	if game_room.player_count != room_data.player_count:
		game_room.setup(room_data.player_count, player_name)

	# 更新 UI
	for i in range(room_data.player_count):
		var seat = room_data.get_seat(i)
		if seat.player:
			game_room.update_player_name(i, seat.player.name)
			game_room.update_ready_state(i, seat.player.is_ready)
		else:
			game_room.update_player_name(i, "")
			game_room.update_ready_state(i, false)


func _on_viewmodel_player_joined(player: PlayerData) -> void:
	game_room.update_player_name(player.seat_index, player.name)
	if player == game_room_view_model.current_player:
		game_room.set_local_player_seat(player.seat_index)


func _on_viewmodel_player_left(seat_index: int) -> void:
	game_room.update_player_name(seat_index, "")


func _on_viewmodel_player_ready_changed(seat_index: int, is_ready: bool) -> void:
	game_room.update_ready_state(seat_index, is_ready)


func _on_viewmodel_all_players_ready() -> void:
	if is_host:
		game_room.set_status("所有玩家已准备，游戏开始！")


func _on_viewmodel_game_start_triggered() -> void:
	game_room.set_status("游戏开始！")


func _on_viewmodel_error(message: String) -> void:
	game_room.set_status("错误: " + message)


func _on_game_start_received(_message: NetworkMessage) -> void:
	game_room.set_status("游戏开始！")


## 网络消息处理 - 具体消息类型处理
func _on_room_state_received(message: NetworkMessage) -> void:
	var room_data = game_room_view_model.room_data
	if room_data:
		for i in range(room_data.player_count):
			var seat = room_data.get_seat(i)
			if seat.player:
				game_room.update_player_name(i, seat.player.name)
				game_room.update_ready_state(i, seat.player.is_ready)


func _on_player_assigned_received(message: NetworkMessage) -> void:
	var seat_index = message.data.get("seat_index", -1)
	if seat_index >= 0 and message.data.has("player"):
		var player_data = message.data.get("player")
		game_room.update_player_name(seat_index, player_data.get("name", ""))


func _on_player_joined_received(message: NetworkMessage) -> void:
	var seat_index = message.data.get("seat_index", -1)
	var player_name = message.data.get("player_name", "")
	if seat_index >= 0:
		game_room.update_player_name(seat_index, player_name)


func _on_player_ready_received(message: NetworkMessage) -> void:
	var seat_index = message.data.get("seat_index", -1)
	var is_ready = message.data.get("is_ready", false)
	if seat_index >= 0:
		game_room.update_ready_state(seat_index, is_ready)


func _on_player_left_received(message: NetworkMessage) -> void:
	var seat_index = message.data.get("seat_index", -1)
	if seat_index >= 0:
		game_room.update_player_name(seat_index, "")
		game_room.update_ready_state(seat_index, false)


## 游戏房间回调 - 使用 GameRoomViewModel
func _on_game_room_player_ready(seat_index: int, is_ready: bool) -> void:
	game_room_view_model.toggle_ready()


func _on_game_room_seat_selected(seat_index: int, p_name: String) -> void:
	game_room_view_model.select_seat(seat_index)


func _on_game_room_seat_deselected(seat_index: int) -> void:
	# 取消选择座位 = 离开房间
	var room_data = game_room_view_model.room_data
	if room_data:
		var seat = room_data.get_seat(seat_index)
		if seat and seat.player == game_room_view_model.current_player:
			seat.clear_player()
			var msg = NetworkMessage.create_player_left(seat_index)
			#if is_host:
				#network.broadcast(msg)
			#else:
				#network.send_to_server(msg)


func _on_leave_room() -> void:
	_cleanup_session()
	_show_ui(UIState.SELECT_MODE)


## 辅助方法
func _cleanup_session() -> void:
	if game_room_view_model:
		game_room_view_model.leave_room()
	player_name = ""
	local_seat_index = -1


func _exit_tree() -> void:
	_cleanup_session()


func _process(_delta: float) -> void:
	network.poll()
