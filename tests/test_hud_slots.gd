extends GutTest
## Skill slots on the HUD sit where their buttons are on the pad: bumpers on the bottom row,
## triggers above them, left buttons on the left. Each shows the button, icon and name.

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	Controls.using_joypad = false

func _game():
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	return game

func test_slots_are_laid_out_like_the_shoulder_buttons() -> void:
	var game = await _game()
	var lb: Dictionary = game.hud.slot_view(0)
	var rb: Dictionary = game.hud.slot_view(1)
	var lt: Dictionary = game.hud.slot_view(2)
	var rt: Dictionary = game.hud.slot_view(3)
	assert_lt(lb["pos"].x, 320.0)
	assert_lt(lt["pos"].x, 320.0)
	assert_gt(rb["pos"].x, 320.0)
	assert_gt(rt["pos"].x, 320.0)
	assert_lt(lt["pos"].y, lb["pos"].y)  # triggers above bumpers
	assert_lt(rt["pos"].y, rb["pos"].y)
	assert_gt(lb["pos"].y, 300.0)  # bottom of the screen

func test_a_slot_shows_button_icon_and_name() -> void:
	var game = await _game()
	game.player.skillset.slots.owned.append("water_blade")
	game.player.skillset.slots.slots[2] = "water_blade"
	await wait_process_frames(2)
	var v: Dictionary = game.hud.slot_view(2)
	assert_eq([v["label"], v["name"], v["icon"]], ["H", "Water Blade", "icon_water_blade"])
	Controls.using_joypad = true
	await wait_process_frames(2)
	assert_eq(game.hud.slot_view(2)["label"], "LT")
	assert_eq(game.hud.slot_view(0)["name"], "")

func test_a_slot_you_cannot_afford_is_dimmed() -> void:
	var game = await _game()
	game.player.skillset.slots.owned.append("water_blade")
	game.player.skillset.slots.slots[0] = "water_blade"
	game.player.mana.spend(game.player.mana.mp)
	await wait_process_frames(2)
	assert_true(game.hud.slot_view(0)["dim"])
