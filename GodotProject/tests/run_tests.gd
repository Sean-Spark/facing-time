extends SceneTree

func _init():
	print("=== Starting Tests ===")
	print("")

	# Wait for the tree to be ready
	await ready

	# Use gut_cmdln.gd style approach
	var gut = load("res://addons/gut/gut.gd").new()
	root.add_child(gut)

	# Configure using .gutconfig.json
	var gut_config = load("res://addons/gut/gut_config.gd").new()
	gut_config.load_options("res://.gutconfig.json")
	gut_config.apply_options(gut)

	# Run tests
	await gut.run_tests()

	print("=== Test Summary ===")
	print("Tests completed.")
	print("=====================")

	quit()

func ready():
	# This is called when the tree is ready
	pass
