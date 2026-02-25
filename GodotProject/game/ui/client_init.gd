class_name ClientInitUI
extends Control

## 固定的服务器地址
const DEFAULT_SERVER_URL: String = "wss://qo-oq.local:8766"

signal sig_connect_to_server(player_name: String)
signal sig_go_back()

@onready var player_name_input: LineEdit = $Panel/VBoxContainer/PlayerNameContainer/PlayerNameInput
@onready var server_url_label: Label = $Panel/VBoxContainer/ServerUrlLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var connect_button: Button = $Panel/VBoxContainer/ConnectButton

var player_name: String = ""

func _ready() -> void:
	# 显示固定服务器地址
	server_url_label.text = "服务器: " + DEFAULT_SERVER_URL
	_update_button_state()

func _on_player_name_changed(text: String) -> void:
	player_name = text
	_update_button_state()

func _update_button_state() -> void:
	var can_connect: bool = player_name.length() > 0
	connect_button.disabled = not can_connect
	status_label.text = "状态：等待输入..."

func _on_connect_pressed() -> void:
	if player_name.length() == 0:
		return

	status_label.text = "状态：正在连接..."
	connect_button.disabled = true

	sig_connect_to_server.emit(player_name)

func _on_back_pressed() -> void:
	sig_go_back.emit()

func set_status(text: String) -> void:
	status_label.text = "状态：" + text
	connect_button.disabled = false
	print_debug(text)

func get_server_url() -> String:
	return DEFAULT_SERVER_URL
