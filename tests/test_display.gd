extends GutTest
## Fixed 640x360 internal resolution scaled to the window, and a HUD that fits it.

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_project_renders_at_640x360_and_scales_to_the_window() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")

func test_hud_fits_the_view_and_shows_mp() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	assert_eq(game.hud.mp_text(), "MP 20/20")
	for c in game.hud.get_children():
		if c is Control:
			assert_between(c.position.x, 0.0, 639.0, c.name)
			assert_between(c.position.y, 0.0, 359.0, c.name)
	var cam: Camera2D = game.player.get_node("Camera")
	assert_eq(cam.zoom, Vector2(1, 1))
