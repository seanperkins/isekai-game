extends SceneTree
## Stitches every room of the world into one image: .tmp/shots/overview.png (1 px per game pixel).
## Each room is shot one screen at a time in the real engine, with the HUD, the player and the
## screen-glued foreground frame hidden, then placed at the room's world position. Needs a window:
## do not pass --headless.
##   tools/shot_run.sh tools/shoot_overview.gd
## Far parallax layers follow the camera, so they jump at screen boundaries inside a room.

const SCREEN := Vector2i(640, 360)

var view: SubViewport  # the stage the game is drawn on (tools/shot_stage.gd)

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame  # the autoloads are only ready after the first frame: scripts first loaded before it fail to compile
	var game = load("res://scenes/main.tscn").instantiate()
	view = ShotStage.mount(root, game)
	for _i in 4:
		await process_frame
	var world = game.world  # untyped: naming World here compiles it before the autoloads exist, and it and the scripts it needs break
	var extent := Rect2()
	for id in world.rooms:
		extent = extent.merge((world.rooms[id] as RoomDef).world_rect())
	var canvas := Image.create(int(extent.size.x), int(extent.size.y), false, Image.FORMAT_RGB8)
	canvas.fill(Color(0.1, 0.1, 0.12))
	game.hud.visible = false
	game.player.visible = false
	world.set_physics_process(false)
	for id in world.rooms:
		var def: RoomDef = world.rooms[id]
		world.enter(id)
		var foreground = world.room.get_node_or_null("foreground")
		if foreground != null:
			foreground.visible = false
		var rect := def.world_rect()
		game.player.global_position = rect.position + Vector2(-5000, -5000)  # out of every room
		for cy in def.size.y:
			for cx in def.size.x:
				var centre := rect.position + Vector2(cx * SCREEN.x + SCREEN.x / 2.0, cy * SCREEN.y + SCREEN.y / 2.0)
				world.camera.global_position = centre
				for _i in 6:
					await process_frame
				var shot := view.get_texture().get_image()
				shot.resize(SCREEN.x, SCREEN.y, Image.INTERPOLATE_LANCZOS)
				shot.convert(Image.FORMAT_RGB8)
				canvas.blit_rect(shot, Rect2i(Vector2i.ZERO, SCREEN),
					Vector2i(rect.position - extent.position) + Vector2i(cx * SCREEN.x, cy * SCREEN.y))
		print("shot ", id)
	var path := ProjectSettings.globalize_path("res://.tmp/shots/overview.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	canvas.save_png(path)
	print("saved ", path, " ", canvas.get_size())
	quit(0)
