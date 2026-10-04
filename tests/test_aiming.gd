extends GutTest
## Aimed skills: cast toward the held direction (8-way for the left stick and keys; the right stick and the mouse are free, see
## test_pointer_aim.gd), or forward when nothing is held.

class FakeActor extends Node2D:
	var team := "player"
	var facing := 1
	var impulses: Array = []
	var hits: Array = []
	var threads: Array = []
	func apply_impulse(v: Vector2) -> void:
		impulses.append(v)
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_thread(tier: int) -> void:
		threads.append(tier)

var actor: FakeActor

func before_each() -> void:
	actor = FakeActor.new()
	add_child_autofree(actor)
	actor.add_to_group("actors")

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()
	for a in ["aim_up", "aim_down", "move_left", "move_right"]:
		Input.action_release(a)

func _enemy(pos: Vector2) -> FakeActor:
	var e := FakeActor.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = pos
	return e

func _cast(id: String, aim: Vector2, values: Array = [1, 1, 1, 1, 1]) -> Ability:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % id).instantiate()
	add_child_autofree(a)
	a.setup(actor, values, 1)
	a.aim = aim
	a.activate()
	return a

func _approx(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01

func test_resolve_aim_snaps_to_eight_directions_or_falls_back_to_facing() -> void:
	assert_eq(Player.resolve_aim(Vector2.ZERO, -1), Vector2(-1, 0))
	assert_eq(Player.resolve_aim(Vector2(0.2, 0.1), 1), Vector2(1, 0))  # inside the deadzone
	assert_true(_approx(Player.resolve_aim(Vector2(0, -1), 1), Vector2(0, -1)))
	assert_true(_approx(Player.resolve_aim(Vector2(0.7, -0.7), 1), Vector2(1, -1).normalized()))
	assert_true(_approx(Player.resolve_aim(Vector2(0.95, -0.2), -1), Vector2(1, 0)))

func test_keyboard_jump_is_space_only_and_w_s_arrows_aim() -> void:
	var jump_keys := InputMap.action_get_events("jump").filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
	assert_eq(jump_keys, [KEY_SPACE])
	for pair in [["aim_up", [KEY_W, KEY_UP]], ["aim_down", [KEY_S, KEY_DOWN]]]:
		var keys := InputMap.action_get_events(pair[0]).filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
		assert_eq(keys, pair[1], pair[0])
		assert_true(InputMap.action_get_events(pair[0]).any(func(e): return e is InputEventJoypadMotion), pair[0])

func test_poison_breath_aimed_up_hits_above_not_ahead() -> void:
	var above := _enemy(Vector2(0, -40))
	var ahead := _enemy(Vector2(40, 0))
	_cast("poison_breath", Vector2(0, -1))
	assert_eq(above.hits.size(), 1)
	assert_eq(ahead.hits, [])

func test_water_blade_is_a_crescent_turned_to_the_aim() -> void:
	_cast("water_blade", Vector2(1, 1).normalized(), [3])
	var c: Sprite2D = get_tree().get_nodes_in_group("vfx").filter(func(n): return n is Sprite2D and n.texture == VfxArt.water_slash())[0]
	assert_almost_eq(c.rotation, PI / 4.0, 0.01)
	assert_true(_approx(c.global_position, Vector2(1, 1).normalized() * 24.0))

func test_sticky_thread_aimed_down_hits_below() -> void:
	var below := _enemy(Vector2(0, 50))
	_cast("sticky_thread", Vector2(0, 1))
	assert_eq(below.threads, [1])

func test_hydraulic_propulsion_aimed_up_is_a_vertical_boost() -> void:
	_cast("hydraulic_propulsion", Vector2(0, -1), [100, 120, 140, 160, 180])
	assert_true(_approx(actor.impulses[0], Vector2(0, -380)))

func test_jet_dash_follows_a_diagonal_aim() -> void:
	_cast("jet_dash", Vector2(-1, -1).normalized())
	assert_lt(actor.impulses[0].x, 0.0)
	assert_lt(actor.impulses[0].y, 0.0)

func test_no_aim_still_means_forward() -> void:
	var ahead := _enemy(Vector2(40, 0))
	_cast("poison_breath", Vector2.ZERO)
	assert_eq(ahead.hits.size(), 1)

func test_player_passes_the_held_direction_to_the_ability() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	Input.action_press("aim_up")
	p.use_active(0)
	var hydro: Ability = p._abilities["hydraulic_propulsion"]
	assert_true(_approx(hydro.aim, Vector2(0, -1)))
