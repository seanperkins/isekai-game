extends SceneTree
## Saves screenshots of real rooms to .tmp/shots/. Needs a window: do not pass --headless.
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s tools/shoot_rooms.gd
## Each shot is [room id, focus point in room-local px]. The camera and player sit on the focus.

const SHOTS := [
	["C1", Vector2(300, 250)],
	["C1", Vector2(900, 250)],
	["C2", Vector2(420, 250)],
	["C3", Vector2(300, 560)],
	["C4", Vector2(320, 250)],
	["C5", Vector2(300, 250)],
	["C6", Vector2(320, 250)],
]

func _initialize() -> void:  # autoloads exist by now, unlike in _init
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for _i in 4:
		await process_frame
	var dir := ProjectSettings.globalize_path("res://.tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	var world: World = game.world
	for shot in SHOTS:
		var id: String = shot[0]
		world.enter(id)
		var rect := world.current_rect()
		world.set_physics_process(false)  # stop the camera following; we place it
		game.player.velocity = Vector2.ZERO
		game.player.global_position = rect.position + shot[1]
		world.camera.global_position = World.view_center(rect, rect.position + shot[1])
		for _i in 6:
			await process_frame
		var img := root.get_texture().get_image()
		n += 1
		var path := "%s/%02d_%s.png" % [dir, n, id]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		world.set_physics_process(true)
	quit(0)
