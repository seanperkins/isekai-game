extends GutTest
## Skill slots on the HUD form one block top-right shaped like the pad's shoulders: triggers
## on top, bumpers under them, left buttons on the left. Each shows the button, icon and name.

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	Controls.using_joypad = false

func _game():
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	return game

func test_slots_form_one_controller_shaped_block_top_right() -> void:
	var game = await _game()
	var lb: Dictionary = game.hud.slot_view(0)
	var rb: Dictionary = game.hud.slot_view(1)
	var lt: Dictionary = game.hud.slot_view(2)
	var rt: Dictionary = game.hud.slot_view(3)
	var size: Vector2 = Hud.SLOT_SIZE
	assert_gt(lt["pos"].x, 320.0)  # right half
	assert_lt(lt["pos"].y, 20.0)   # top edge
	assert_eq(rt["pos"], lt["pos"] + Vector2(size.x, 0))  # triggers side by side, touching
	assert_eq(lb["pos"], lt["pos"] + Vector2(0, size.y))  # bumpers right under them
	assert_eq(rb["pos"], lt["pos"] + size)
	assert_lte(rt["pos"].x + size.x, 640.0)

func test_the_menu_hint_and_popup_stay_clear_of_the_slots() -> void:
	var game = await _game()
	var block := Rect2(game.hud.slot_view(2)["pos"], Hud.SLOT_SIZE * 2)
	assert_false(block.has_point(game.hud.menu_hint_position()))
	assert_gt(game.hud.popup_top(), block.end.y)

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
