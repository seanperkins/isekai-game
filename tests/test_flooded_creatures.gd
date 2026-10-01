extends GutTest
## The Flooded's swimmers: confined to their water, stalking and diving, shocking on contact; the jelly drifts without puffing
## and cannot be tackled.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(_a: int, _t: int, _s: float) -> void:
		pass

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")

func _pool(rect: Rect2) -> DeepWater:
	var w := DeepWater.make(rect)
	add_child_autofree(w)
	return w

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func test_the_eels_are_swoopers_and_the_jelly_stays_a_drifter() -> void:
	_pool(Rect2(-100, -100, 200, 200))
	assert_eq(_enemy("glass_eel", Vector2.ZERO).kind, Enemy.Kind.SWOOPER)
	assert_eq(_enemy("drift_jelly", Vector2.ZERO).kind, Enemy.Kind.DRIFTER)
	assert_eq(_enemy("cave_crayfish", Vector2(50, 0)).kind, Enemy.Kind.CHARGER)

func test_an_eel_stays_inside_its_water_rect() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, -40))
	fake_player.global_position = Vector2(400, -40)  # beyond the rect: the eel should not leave to chase
	await wait_physics_frames(120)
	assert_true(rect.grow(1.0).has_point(eel.global_position))
	eel.velocity = Vector2(900, 900)
	await wait_physics_frames(30)
	assert_true(rect.grow(1.0).has_point(eel.global_position), "a hard shove is clamped")

func test_an_eel_is_alerted_only_by_a_player_in_its_own_rect() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, -40))
	fake_player.global_position = Vector2(150, -40)  # in sight, near, but outside the rect
	await wait_physics_frames(10)
	assert_false(eel.is_alert())
	fake_player.global_position = Vector2(60, -40)
	await wait_physics_frames(10)
	assert_true(eel.is_alert())

func test_an_eel_telegraphs_then_dives_and_a_contact_is_a_shock_hit() -> void:
	var rect := Rect2(-200, -150, 400, 250)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(-120, -40))
	fake_player.global_position = Vector2(0, -40)
	var saw_warn := false
	for i in 240:
		await wait_physics_frames(1)
		if eel.swoop_state() == "warn":
			saw_warn = true
			assert_true(eel.telegraphing())
		if not fake_player.hits.is_empty():
			break
	assert_true(saw_warn, "it flashes before it dives")
	assert_false(fake_player.hits.is_empty(), "the dive reached the player")
	assert_eq(fake_player.hits[0][1], "shock")

func test_a_stunned_eel_sinks_to_the_bottom_of_its_rect_and_stays() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, -40))
	eel.status.stun()
	await wait_physics_frames(120)
	assert_almost_eq(eel.global_position.y, rect.end.y - 6.0, 2.0, "held at the bottom by the clamp")
	assert_eq(eel.velocity.y, 0.0, "the clamp zeroes the fall instead of letting it grow")

func test_a_swimmer_with_no_water_idles() -> void:
	var eel := _enemy("glass_eel", Vector2(0, 0))
	fake_player.global_position = Vector2(40, 0)
	await wait_physics_frames(30)
	assert_eq(eel.velocity, Vector2.ZERO)

func test_a_spawn_on_the_rect_corner_is_inside_after_the_first_frame() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(-100, -100))  # the top-left corner: Rect2.has_point includes the top and left edges
	await wait_physics_frames(3)
	assert_true(rect.has_point(eel.global_position))

func test_a_spawn_on_the_right_or_bottom_edge_is_outside_and_idles_like_lint_says() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(100, -40))  # Rect2.has_point excludes the right edge: no home water, and swimmer_dry reports it
	fake_player.global_position = Vector2(60, -40)
	await wait_physics_frames(10)
	assert_eq(eel.velocity, Vector2.ZERO)

func test_a_jelly_drifts_inside_a_narrow_rect_and_turns_at_the_wall() -> void:
	var rect := Rect2(-60, -100, 120, 100)  # narrower than the drifter's own +-96 loop
	_pool(rect)
	var jelly := _enemy("drift_jelly", Vector2(0, -50))
	var lo := INF
	var hi := -INF
	for i in 400:
		await wait_physics_frames(1)
		lo = minf(lo, jelly.global_position.x)
		hi = maxf(hi, jelly.global_position.x)
	assert_true(rect.has_point(jelly.global_position))
	assert_gt(hi - lo, 20.0, "it kept moving instead of pinning itself to one wall")

func test_a_jelly_never_drops_a_puff() -> void:
	_pool(Rect2(-200, -200, 400, 300))
	var jelly := _enemy("drift_jelly", Vector2(0, -60))
	fake_player.global_position = Vector2(60, -60)
	await wait_physics_frames(int((Enemy.PUFF_INTERVAL + 1.0) * 60.0))
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is SporePuff).size(), 0)
	assert_false(jelly.telegraphing())

func test_a_jelly_is_skipped_by_a_tackle_and_never_swallows_one_aimed_beyond_it() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	var player := Player.new()
	player.setup(rules, compendium, creature_list, func(_n, _t): pass)
	add_child_autofree(player)
	rules.start_run()
	var jelly := _enemy("drift_jelly", Vector2(14, 0))
	jelly.set_physics_process(false)
	var bat := _enemy("bat", Vector2(30, 0))
	bat.set_physics_process(false)
	player.global_position = Vector2.ZERO
	assert_eq(player._tackle_target(), bat, "the jelly is not a target; the bat behind it is")

func test_contact_reads_the_creatures_damage_type() -> void:
	# a crayfish's contact is physical, an eel's is shock (the call sits at the end of Enemy._physics_process)
	_pool(Rect2(-100, -100, 200, 200))
	var eel := _enemy("glass_eel", Vector2(0, 0))
	fake_player.global_position = Vector2(2, 0)
	await wait_physics_frames(5)
	assert_eq(fake_player.hits[0][1], "shock")

func test_a_rect_smaller_than_the_body_centres_the_swimmer_instead_of_inverting_the_clamp() -> void:
	var rect := Rect2(-5, -5, 10, 10)  # smaller than the 16x12 body: lint's water_rect forbids it, the runtime survives it
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, 0))
	await wait_physics_frames(5)
	assert_almost_eq(eel.global_position.x, 0.0, 0.01)
	assert_almost_eq(eel.global_position.y, 0.0, 0.01)
