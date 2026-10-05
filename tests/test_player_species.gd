extends GutTest
## A Player that is not a slime: it moves with its species' profile and verbs, is drawn with its look and fights with its signature.

var rules: SkillRulesEngine
var player: Player
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func after_each() -> void:
	for a in ["move_right", "move_left", "jump", "tackle", "predate", "aim_down", "aim_up"]:
		Input.action_release(a)
	SkillRules.reset_run()
	Announcer.queue.clear()

## A player of `species` standing on a floor wide enough to run on.
func _spawn(species: String) -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = species
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var body := StaticBody2D.new()
	body.position = Vector2(0, BodyConfig.BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	await wait_physics_frames(6)

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func _top_speed(frames: int) -> float:
	var top := 0.0
	for _k in frames:
		await get_tree().physics_frame
		top = maxf(top, absf(player.velocity.x))
	return top

func test_a_slime_player_has_no_species_body() -> void:
	await _spawn("slime")
	assert_null(player.species_body)
	assert_false(player.uses_species_body())

func test_a_wolf_player_has_a_wolf_body() -> void:
	await _spawn("wolf")
	assert_true(player.uses_species_body())
	assert_eq(player.species_body.profile.id, "wolf")
	assert_eq(player.form.species, "wolf")

func test_a_wolf_runs_faster_than_a_slime() -> void:
	await _spawn("wolf")
	Input.action_press("move_right")
	var wolf := await _top_speed(40)
	player.queue_free()
	await wait_physics_frames(2)
	await _spawn("slime")
	Input.action_press("move_right")
	var slime := await _top_speed(40)
	assert_gt(wolf, 200.0)
	assert_lt(slime, 145.0)

func test_a_wolf_jumps_with_its_profile() -> void:
	await _spawn("wolf")
	var y0 := player.global_position.y
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	var top := y0
	for _k in 60:
		await get_tree().physics_frame
		top = minf(top, player.global_position.y)
	assert_between(y0 - top, 25.0, 70.0, "a wolf's cut jump, from jump_velocity 403")

func test_a_wolf_pounce_hits_an_enemy_it_reaches() -> void:
	await _spawn("wolf")
	var lizard := _enemy("lizard", Vector2(40, 0))
	lizard.health.max_hp = 100
	lizard.health.hp = 100
	Input.action_press("move_right")
	await wait_physics_frames(6)
	Input.action_press("tackle")
	await wait_physics_frames(2)
	Input.action_release("tackle")
	await wait_physics_frames(25)
	assert_lt(lizard.health.hp, 100, "the pounce landed")

func test_a_wolf_is_drawn_with_its_own_sheet_and_has_a_hurt_shape() -> void:
	await _spawn("wolf")
	assert_eq(player.body_sheet(), player.body_sheet())
	assert_true(player.body_sheet().has_frame("idle_1") or player.body_sheet().frame_names().size() > 0)
	assert_ne(player.body_sheet(), SpriteSheet.load_set("slime"), "not the slime's")
	assert_true(player.get_node("Sprite").visible)
	assert_gte(player.hurt_polygon().size(), 3)

func test_an_ability_impulse_moves_a_wolf() -> void:
	await _spawn("wolf")
	player.apply_impulse(Vector2(300, 0))
	await wait_physics_frames(3)
	assert_gt(player.velocity.x, 250.0)
	assert_almost_eq(player.species_body.state.velocity.x, player.velocity.x, 1.0, "the species state agrees with the body")

func test_a_velocity_written_from_outside_is_taken_up() -> void:
	await _spawn("wolf")
	var y0 := player.global_position.y
	player.velocity = Vector2(0.0, -400.0)  # what the world's room slide does to the player it carries
	await wait_physics_frames(4)
	assert_lt(player.global_position.y, y0 - 8.0, "it rose")

func test_a_hit_knocks_a_wolf_back_and_up() -> void:
	await _spawn("wolf")
	var x0 := player.global_position.x
	player.receive_hit(3, "physical", Vector2(x0 - 20.0, 0.0))
	await wait_physics_frames(4)
	assert_gt(player.global_position.x, x0 + 3.0, "away from the attacker")

func test_a_wolf_can_eat() -> void:
	await _spawn("wolf")
	var lizard := _enemy("lizard", Vector2(10, 0))
	lizard.status.stun(5.0)
	Input.action_press("move_right")
	Input.action_press("predate")
	await wait_physics_frames(6)
	assert_true(player.predation.active(), "the hold began")
	assert_almost_eq(player.velocity.x, 0.0, 1.0, "and it does not walk while it eats")

func test_the_wolf_evolves_and_keeps_its_body() -> void:
	await _spawn("wolf")
	player.progression.add_xp(Progression.stage_total(player.progression.stage))
	assert_true(player.advance_form("wolf_warg"))
	assert_eq(player.species_body.profile.id, "wolf")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	Input.action_press("move_right")
	assert_gt(await _top_speed(40), 150.0, "and runs on afterwards")

func test_a_species_with_no_sheet_still_moves_and_draws_something() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = "wolf"
	player.use_sheet = false  # what a missing sheet looks like to the player
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, BodyConfig.BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	await wait_physics_frames(6)
	assert_true(player.uses_species_body())
	Input.action_press("move_right")
	assert_gt(await _top_speed(30), 150.0)
	assert_true(player.get_node("Sprite").visible)
	assert_gte(player.hurt_polygon().size(), 3, "the body box stands in for the traced shape")
