class_name WrapRustCoreServer
extends Control
var rust_server: RustCoreServer = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

	
func setup():
	rust_server = RustCoreServer.new()
	rust_server.create_mdns()
	rust_server.create_server()
	rust_server.start_mdns(
		"_game._tcp.local.",
		"GameInstance",
		"qo-oq",
		8989)
	var static_web_resource = ProjectSettings.globalize_path("res://web")
	rust_server.start_server(
		"0.0.0.0:8089",
		static_web_resource,
		true)
	print(rust_server.get_status())
