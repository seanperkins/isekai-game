extends GutTest
## Channelling: hold a slot to sustain a skill. The Player owns one live channel and steps it after the use_active checks
## each physics tick: release, the MP beat (one point every 0.5 s), the cap, then the ability's own tick.

class TestChannel extends Ability:
	var began := 0
	var ticks := 0
	var ended := []
	func _init() -> void:
		max_channel = 1.0
	func can_channel() -> bool:
		return true
	func begin_channel() -> void:
		began += 1
	func channel_tick(_delta: float) -> bool:
		ticks += 1
		return true
	func end_channel(hard := false) -> void:
		ended.append(hard)
		super.end_channel(hard)

var rules: SkillRulesEngine
var compendium: CompendiumModel
var events: Array
var player: Player
var ch: TestChannel

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	events = []
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})  # Hydraulic Propulsion in slot 0
	ch = TestChannel.new()
	player.add_child(ch)
	ch.setup(player, [100], 1)
	player._abilities["hydraulic_propulsion"] = ch
	player.mana.mp = 20
	player.mana.max_mp = 20

func after_each() -> void:
	for a in ["active_1", "active_2", "active_3", "move_left", "move_right"]:
		Input.action_release(a)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)

func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _names() -> Array:
	return events.map(func(e): return e[0])

func _hold(seconds: float) -> void:
	Input.action_press("active_1")
	await wait_physics_frames(int(round(seconds * 60.0)) + 1)

func test_a_press_starts_the_channel_once() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(2)
	assert_eq(ch.began, 1)
	assert_eq(player._channel, ch)
	assert_eq(_names().count("skill_used"), 1)
	assert_eq(player.mana.mp, 17, "the start cost, as a cast pays it")

func test_every_press_is_ignored_while_a_channel_is_live() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(2)
	player.use_active(0)
	player.use_active(1)
	assert_eq(ch.began, 1)
	assert_eq(_names().count("skill_used"), 1)
	assert_eq(player.mana.mp, 17)

func test_release_ends_it_once_and_softly_then_the_cooldown_runs() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(3)
	Input.action_release("active_1")
	await wait_physics_frames(2)
	assert_eq(ch.ended, [false])
	assert_null(player._channel)
	var mp := player.mana.mp
	player.use_active(0)
	assert_eq(player.mana.mp, mp, "a press inside the 0.8 s after release costs nothing")
	await wait_physics_frames(52)  # past 0.8 s
	player.use_active(0)
	assert_eq(ch.began, 2, "and a press after it casts again")
	Input.action_release("active_1")

func test_the_mp_beat_is_one_point_every_half_second() -> void:
	await _hold(1.0)
	Input.action_release("active_1")
	await wait_physics_frames(2)
	assert_eq(player.mana.mp, 20 - 3 - 2 + _regen(1.0), "two beats by 1.0 s")
	assert_eq(_names().count("mana_spent"), 3 + 2, "each beat emits one mana_spent like the start cost")

func _regen(seconds: float) -> int:
	return int(seconds * 1.0)  # 1 MP per second at the base regen; Mana holds whole points

func test_the_cap_ends_it_even_at_maximum_regen() -> void:
	player.stats.set_modifiers("test_regen", [{"stat": "mp_regen", "op": "add", "value": 300}])
	await _hold(1.3)
	assert_eq(ch.ended, [false], "ended at max_channel 1.0 s without release")
	assert_null(player._channel)

func test_running_out_of_mp_ends_it_silently() -> void:
	player.mana.mp = 3  # exactly the start cost: the first beat cannot be paid
	var refused := [0]
	player.not_enough_mp.connect(func(_id: String) -> void: refused[0] += 1)
	await _hold(0.7)
	assert_eq(ch.ended, [false])
	assert_eq(refused[0], 0, "no ticker for running dry mid-hold")

func test_a_trigger_dipping_to_forty_percent_keeps_the_channel_and_twenty_ends_it() -> void:
	player.skillset.slots.assign(2, "hydraulic_propulsion")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.9)
	await wait_physics_frames(3)
	assert_eq(ch.began, 1)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.4)
	assert_eq(Input.get_action_strength("active_3"), 0.0, "the 0.5 action deadzone would read this as released")
	await wait_physics_frames(3)
	assert_not_null(player._channel, "raw strength keeps it")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.2)
	await wait_physics_frames(2)
	assert_null(player._channel)

func test_a_contact_hit_ends_it_hard_and_the_knockback_survives() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(3)
	player.receive_hit(1, "physical", Vector2(-50, 0))
	assert_eq(ch.ended, [true])
	assert_gt(player.velocity.x, 0.0, "knocked away from the attacker")

func test_a_poison_hit_ends_it_too() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(3)
	player.receive_poison(1, 1, 2.0)
	assert_eq(ch.ended, [true])

func test_a_hit_the_invulnerability_gate_swallows_does_not_end_it() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(3)
	player._invuln = 1.0
	player.receive_hit(1, "physical", Vector2(-50, 0))
	assert_not_null(player._channel)
	Input.action_release("active_1")

func _start() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(3)
	assert_not_null(player._channel)

func test_predation_ends_it_hard() -> void:
	await _start()
	var target := Enemy.new()
	target.setup(DefLoader.load_dir("res://data/creatures").filter(func(c): return c.id == "bat")[0], {})
	add_child_autofree(target)
	target.global_position = player.global_position + Vector2(10, 0)
	target.set_physics_process(false)
	target.receive_tackle(1, false)
	Input.action_release("active_1")  # the eat needs the slot free of a live channel: begin_predate ends it either way
	player._channel = ch
	player.begin_predate()
	assert_true(ch.ended.has(true))

func test_the_evolution_moment_ends_it_hard() -> void:
	await _start()
	player._begin_evolve_moment(FormLoader.load_all()["tide"])
	assert_eq(ch.ended, [true])

func test_death_ends_it_hard() -> void:
	await _start()
	player._on_health_died()
	assert_eq(ch.ended, [true])

func test_a_new_run_ends_it_hard() -> void:
	await _start()
	player._on_run_started()
	assert_eq(ch.ended, [true])

func test_the_skill_screen_ends_it_before_pausing() -> void:
	Input.action_press("active_1")
	await wait_physics_frames(3)
	var screen := SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, DefLoader.load_dir("res://data/skills"))
	screen.open()
	assert_eq(ch.ended, [true])
	screen.close()

func test_a_one_shot_ability_still_casts_through_activate() -> void:
	var blade: Ability = load("res://scenes/abilities/water_blade.tscn").instantiate()
	player.add_child(blade)
	blade.setup(player, [3], 1)
	player._abilities["hydraulic_propulsion"] = blade
	player.use_active(0)
	assert_null(player._channel)
	assert_eq(_names().count("skill_used"), 1)
	assert_false(blade.ready(), "the cooldown starts at the press for a one-shot")
