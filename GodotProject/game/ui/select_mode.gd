class_name SelectMode
extends Control

signal sig_go_to_host_init()
signal sig_go_to_client_init()
signal sig_go_back()

@onready var host_button: Button = $Panel/VBoxContainer/HostButton

func _ready() -> void:
	# Web打包时隐藏主机端按钮
	if OS.has_feature("web"):
		host_button.visible = false

func _on_host_button_pressed() -> void:
	sig_go_to_host_init.emit()

func _on_client_button_pressed() -> void:
	sig_go_to_client_init.emit()

func _on_back_button_pressed() -> void:
	sig_go_back.emit()
