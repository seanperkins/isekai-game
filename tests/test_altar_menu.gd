extends GutTest
## The altar's menu: it pauses the game while open, draws the model's rows, and is driven by keys and the stick.

class StubHealth extends RefCounted:
	var dead := false
	func is_dead() -> bool:
		return dead

class StubPlayer extends Node:
	var health := StubHealth.new()
	var ended := [0]
	func end_channel() -> void:
		ended[0] += 1

var menu: AltarMenu
var player: StubPlayer
var engine: SkillRulesEngine
var soul: SoulProgress
var progress: WorldProgress
var goddess: Goddess
var rules := SoulRules.new()
var saved_pad: Array

func before_each() -> void:
	saved_pad = [Controls.last_stick, Controls.using_joypad, Controls.last_device, Controls.last_pad_name]
	var skills := DefLoader.load_dir("res://data/skills")
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test(msg)
	engine.setup(skills)
	engine.start_run()
	soul = SoulProgress.new(null, ["stats"])
	progress = WorldProgress.new()
	goddess = Goddess.new(soul, rules, GoddessLines.new(), {}, [_perk()], CompendiumModel.new(skills, []), skills)
	player = StubPlayer.new()
	add_child_autofree(player)
	menu = AltarMenu.new()
	add_child_autofree(menu)
	menu.bind(goddess, engine, progress, player)

func after_each() -> void:
	get_tree().paused = false
	Controls.last_stick = saved_pad[0]
	Controls.using_joypad = saved_pad[1]
	Controls.last_device = saved_pad[2]
	Controls.last_pad_name = saved_pad[3]

func _perk() -> PerkDef:
	var p := PerkDef.new()
	p.id = "stats"
	p.display_name = "Stronger base stats"
	p.altar = "C1"
	p.price_base = 5
	p.price_step = 3
	return p

func _absorb(element: String, n: int) -> void:
	for i in n:
		engine.handle_event("absorbed", {"essence": element, "source": "test"})

func _model(altar_id := "C1") -> AltarModel:
	return AltarModel.new(altar_id, _perk(), progress, soul, rules, engine)

func _altar(id := "C1") -> Altar:
	var altar := Altar.new()
	altar.setup({"kind": "altar", "id": id, "area": "cave", "perk": "stats", "pos": Vector2.ZERO}, {"progress": progress})
	add_child_autofree(altar)
	return altar

func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code  # Controls binds the physical key
	ev.pressed = true
	menu._unhandled_input(ev)

func test_open_for_pauses_and_close_unpauses() -> void:
	assert_true(menu.open_for(_altar()))
	assert_true(menu.is_open())
	assert_true(get_tree().paused)
	assert_eq(player.ended[0], 1, "a held channel ends before the pause, as the skill screen does")
	assert_eq(menu.row_texts().size(), 7, "attune, five essences and the perk, from the goddess's perk list")
	menu.close()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)

func test_it_refuses_to_open_when_paused_or_the_player_is_dead() -> void:
	get_tree().paused = true
	assert_false(menu.open_for(_altar()), "already paused: the skill screen is open")
	assert_false(menu.is_open())
	get_tree().paused = false
	player.health.dead = true
	assert_false(menu.open_for(_altar()))
	assert_false(menu.is_open())
	assert_false(get_tree().paused)

func test_rows_and_footer_read_as_specified() -> void:
	_absorb("water", 27)
	soul.add(12)
	menu.open_model(_model(), "Cave mouth")
	assert_eq(menu.title_text(), "Cave mouth")
	assert_eq(menu.row_texts(), ["> Attuned", "  Water  held 27  bank 0 = 0", "  Earth  held 0  bank 0 = 0",
		"  Air  held 0  bank 0 = 0", "  Light  held 0  bank 0 = 0", "  Dark  held 0  bank 0 = 0", "  Stronger base stats  x0  next 5"])
	assert_eq(menu.footer_text(), "Soul points 12    Enter: choose   Back: leave")
	menu.close()
	menu.open_model(_model("G1"), "Grotto altar")
	assert_eq(menu.row_texts()[0], "> Attune")

func test_keys_drive_the_model() -> void:
	_absorb("water", 27)
	menu.open_model(_model(), "Cave mouth")
	_press(KEY_DOWN)
	_press(KEY_RIGHT)
	_press(KEY_RIGHT)
	assert_eq(menu.row_texts()[1], "> Water  held 27  bank 20 = 2")
	_press(KEY_ENTER)
	assert_eq(soul.total_points(), 2)
	assert_eq(engine.held("water"), 7)
	assert_eq(menu.footer_text(), "Soul points 2    Banked 2 soul points.")
	for i in 5:
		_press(KEY_DOWN)
	_press(KEY_ENTER)
	assert_eq(menu.footer_text(), "Soul points 2    Not enough soul points.", "the perk costs 5")
	_press(KEY_BACKSPACE)
	assert_false(menu.is_open())
	assert_false(get_tree().paused)

func test_the_stick_steps_once_per_push() -> void:
	menu.open_model(_model(), "Cave mouth")
	Controls.last_stick = Vector2(0.0, 0.9)
	menu._process(0.016)
	assert_true((menu.row_texts()[1] as String).begins_with("> "))
	menu._process(0.016)
	assert_true((menu.row_texts()[1] as String).begins_with("> "), "a held push repeats only after the delay")
	Controls.last_stick = Vector2.ZERO
	menu._process(0.016)
	Controls.last_stick = Vector2(0.0, 0.9)
	menu._process(0.016)
	assert_true((menu.row_texts()[2] as String).begins_with("> "), "a fresh push steps again")

func test_joypad_motion_is_handled_while_open() -> void:
	menu.open_model(_model(), "Cave mouth")
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_Y
	ev.axis_value = 0.9
	menu._unhandled_input(ev)
	assert_true(get_viewport().is_input_handled())
	assert_true((menu.row_texts()[0] as String).begins_with("> "), "the event itself moves nothing")

func test_the_game_binds_the_menu_to_the_real_engine() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	assert_not_null(game.altar_menu)
	assert_same(game.altar_menu.engine, SkillRules)
	SkillRules.reset_run()
	Announcer.queue.clear()
