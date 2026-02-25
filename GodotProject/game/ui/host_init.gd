class_name HostInitUI
extends Control

## 固定的服务端口
const DEFAULT_PORT: int = 8766

signal sig_service_started(player_count: int, player_name: String)
signal sig_go_back()

@onready var port_label: Label = $Panel/VBoxContainer/PortLabel
@onready var player_count_button: OptionButton = $Panel/VBoxContainer/PlayerCountContainer/PlayerCountButton
@onready var player_name_input: LineEdit = $Panel/VBoxContainer/PlayerNameContainer/PlayerNameInput
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var start_button: Button = $Panel/VBoxContainer/StartButton

var player_count: int = 5
var player_name: String = ""

func _ready() -> void:
	# 显示固定端口
	port_label.text = "端口: " + str(DEFAULT_PORT)
	_update_button_state()

func _on_player_count_selected(index: int) -> void:
	player_count = 5 + index
	_update_button_state()

func _on_player_name_changed(text: String) -> void:
	player_name = text
	_update_button_state()

func _update_button_state() -> void:
	var can_start: bool = player_name.length() > 0
	start_button.disabled = not can_start
	status_label.text = "状态：等待输入..."

func _on_start_pressed() -> void:
	if player_name.length() == 0:
		return

	status_label.text = "状态：正在启动服务..."
	start_button.disabled = true

	sig_service_started.emit(player_count, player_name)

func _on_back_pressed() -> void:
	sig_go_back.emit()

func set_status(text: String) -> void:
	status_label.text = "状态：" + text
	start_button.disabled = false
	print_debug(text)

func get_port() -> int:
	return DEFAULT_PORT
