extends GutTest
## The player in water, through the real physics: the modifiers, the bob, the swim, the entry cap, the shock lock and the events.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var player: Player
var events: Array

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

func _floor(y := 100.0) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, y + 10.0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _pool(rect: Rect2) -> DeepWater:
	var w := DeepWater.make(rect)
	add_child_autofree(w)
	return w

func _names() -> Array:
	return events.map(func(e): return e[0])

## Grants skills the way a rebirth kit does: quietly, after start_run.
func _give(skill_ids: Array) -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": skill_ids})

func test_submerged_is_emitted_once_a_second_and_only_in_water() -> void:
	_floor()
	_pool(Rect2(-100, -200, 200, 300))
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(130)
	assert_gte(_names().count("submerged"), 2)
	assert_lte(_names().count("submerged"), 3)
	events.clear()
	player.global_position = Vector2(900, 80)
	await wait_physics_frames(120)
	assert_eq(_names().count("submerged"), 0)

func test_entering_and_leaving_water_emit_the_audio_events() -> void:
	_floor()
	_pool(Rect2(-100, -200, 200, 300))
	var seen: Array = []
	var f := func(n: String, _t: Dictionary) -> void: seen.append(n)
	EventBus.world_event.connect(f)
	player.global_position = Vector2(900, 80)
	await wait_physics_frames(3)
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(3)
	player.global_position = Vector2(900, 80)
	await wait_physics_frames(3)
	EventBus.world_event.disconnect(f)
	assert_eq(seen.filter(func(n): return n.begins_with("water_")), ["water_entered", "water_exited"])

func test_a_non_swimmer_in_water_walks_at_sixty_percent() -> void:
	_floor()
	_pool(Rect2(-300, -200, 600, 300))
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(10)
	Input.action_press("move_right")
	await wait_physics_frames(10)
	var v := player.velocity.x
	Input.action_release("move_right")
	assert_almost_eq(v, Player.SPEED * 0.6, 2.0)

func test_a_jump_from_the_floor_in_water_is_a_bob() -> void:
	_floor()
	_pool(Rect2(-300, -200, 600, 300))
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(15)
	assert_true(player.is_on_floor())
	player.do_jump()
	assert_almost_eq(player.velocity.y, -PlayerWater.BOB_VELOCITY, 0.5)

func test_no_wall_bob_in_water_without_swim() -> void:
	# Wall Cling's wall jump is a dry-land move: in water a wall gives a non-swimmer nothing
	_give(["wall_cling"])
	_pool(Rect2(-300, -300, 600, 600))
	var wall := StaticBody2D.new()
	wall.position = Vector2(30, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 400)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	player.global_position = Vector2(0, 0)
	Input.action_press("move_right")
	await wait_physics_frames(40)
	Input.action_release("move_right")
	assert_true(player.is_on_wall(), "pressed against the wall")
	player.do_jump()
	assert_gt(player.velocity.y, -1.0, "no upward velocity: a wall gives no bob")

func test_a_dry_jump_carried_into_water_is_capped_at_the_bob() -> void:
	_pool(Rect2(-300, -400, 600, 300))  # water above the origin
	player.global_position = Vector2(0, 0)  # dry, just under the pool
	await wait_physics_frames(1)
	player.global_position = Vector2(0, -200)  # inside the water: the next frame is the entry edge
	player.velocity = Vector2(0, -330)
	await wait_physics_frames(1)
	assert_gte(player.velocity.y, -PlayerWater.BOB_VELOCITY - 5.0, "the entry edge caps a dry jump's upward speed")

func test_hydraulic_propulsion_style_impulse_mid_water_is_not_capped() -> void:
	_pool(Rect2(-300, -600, 600, 900))
	player.global_position = Vector2(0, -200)
	await wait_physics_frames(3)  # already in water: no entry edge
	player.apply_impulse(Vector2(0, -380))
	await wait_physics_frames(1)
	assert_lt(player.velocity.y, -PlayerWater.BOB_VELOCITY - 20.0, "mid-water impulses keep their speed (the Grotto's traversal-skill rule)")

func test_a_swimmer_hangs_in_water_with_no_gravity() -> void:
	_give(["swim"])
	assert_true(player.skillset.has("swim"))
	_pool(Rect2(-300, -300, 600, 600))
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(30)
	assert_almost_eq(player.global_position.y, 0.0, 1.0, "no gravity, no input: it hangs where it is")
	assert_eq(player.velocity, Vector2.ZERO)

func test_a_swimmer_swims_at_the_swim_speed_in_any_direction() -> void:
	_give(["swim"])
	_pool(Rect2(-300, -300, 600, 600))
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(5)
	Input.action_press("move_right")
	Input.action_press("aim_up")
	await wait_physics_frames(10)
	var v := player.velocity
	Input.action_release("move_right")
	Input.action_release("aim_up")
	assert_gt(v.x, 0.0)
	assert_lt(v.y, 0.0)
	assert_almost_eq(v.length(), float(player.stats.get_stat("swim_speed")), 1.0)

func test_a_swimmer_leaves_through_the_surface_jump() -> void:
	_give(["swim"])
	_pool(Rect2(-300, 0, 600, 300))  # the surface is at y 0
	player.global_position = Vector2(0, 10)  # centre 10 below the top edge: inside the surface reach
	await wait_physics_frames(2)
	player.do_jump()
	assert_almost_eq(player.velocity.y, Player.JUMP_VELOCITY, 1.0, "the normal jump velocity")
	assert_true(player._water.ballistic)
	await wait_physics_frames(30)
	assert_false(player._water.in_water, "out of the rect")
	assert_false(player._water.ballistic, "ballistic ends with the water")
	assert_lt(player.global_position.y, 0.0)

func test_a_swimmer_deeper_than_the_surface_reach_cannot_jump_out() -> void:
	_give(["swim"])
	_pool(Rect2(-300, 0, 600, 300))
	player.global_position = Vector2(0, 100)
	await wait_physics_frames(2)
	player.do_jump()
	assert_gt(player.velocity.y, Player.JUMP_VELOCITY * 0.5)
	assert_false(player._water.ballistic)

func test_a_non_swimmers_swim_speed_stat_is_the_base_and_the_skill_raises_it() -> void:
	assert_eq(player.stats.get_stat("swim_speed"), 120)
	_give(["swim"])
	assert_eq(player.stats.get_stat("swim_speed"), 120, "level 1 adds 0")

func test_a_shock_hit_locks_input_for_at_least_the_shock_lock_after_the_knockback_block() -> void:
	player.receive_hit(2, "shock", Vector2(-10, 0))
	assert_gte(player._dash, Player.SHOCK_STUN - 0.001)
	player._dash = 0.0
	player._invuln = 0.0
	player.receive_hit(2, "physical", Vector2(-10, 0))
	assert_almost_eq(player._dash, 0.2, 0.001, "a physical hit keeps the knockback lock")

func test_a_shock_during_invulnerability_does_not_rearm_the_lock() -> void:
	player.receive_hit(2, "shock", Vector2(-10, 0))
	player._dash = 0.0  # the lock ran out
	player.receive_hit(2, "shock", Vector2(-10, 0))  # still invulnerable: refused
	assert_eq(player._dash, 0.0)

func test_a_new_life_forgets_the_water() -> void:
	_pool(Rect2(-100, -200, 200, 300))
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(3)
	assert_true(player._water.in_water)
	rules.start_run()
	assert_false(player._water.in_water)

func test_a_wall_clinging_swimmer_swims_down_a_wall_at_full_speed() -> void:
	_give(["swim", "wall_cling"])
	_pool(Rect2(-300, -300, 600, 600))
	var wall := StaticBody2D.new()
	wall.position = Vector2(30, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 400)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	player.stats.set_modifiers("test_swim_boost", [{"stat": "swim_speed", "op": "add", "value": 100}])  # 220 px/s: a diagonal's vertical part clears the slide cap
	player.global_position = Vector2(0, -100)
	Input.action_press("move_right")
	Input.action_press("aim_down")
	await wait_physics_frames(20)
	var v := player.velocity
	Input.action_release("move_right")
	Input.action_release("aim_down")
	assert_true(player.is_on_wall())
	assert_gt(v.y, Player.WALL_SLIDE_SPEED, "the wall slide's cap does not apply to a swimmer in water")
