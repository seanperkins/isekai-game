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

# --- the biped and the spider (Task 3) ---

## A solid block, `r` in world coordinates (the test floor's top is y BodyConfig.BOTTOM).
func _block(r: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = r.position + r.size / 2.0
	var s := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	s.shape = rect
	b.add_child(s)
	add_child_autofree(b)
	return b

func test_a_goblin_and_an_undead_use_the_biped_profile_and_the_goblin_sheet() -> void:
	for species in ["goblin", "undead"]:
		await _spawn(species)
		assert_eq(player.species_body.profile.id, "biped", species)
		assert_eq(player.body_sheet().frame_size("idle_1"), SpriteSheet.load_set("goblin").frame_size("idle_1"), species)
		player.queue_free()
		await wait_physics_frames(2)

func test_a_roll_is_untouchable_while_it_is_invulnerable_and_not_after() -> void:
	await _spawn("goblin")
	Input.action_press("tackle")
	await wait_physics_frames(2)
	Input.action_release("tackle")
	assert_eq(player.species_body.state.verb, "roll")
	var hp := player.health.hp
	player.receive_hit(5, "physical")
	player.receive_poison(3, 1, 2.0)
	assert_eq(player.health.hp, hp, "the first 0.2 s of a roll cannot be hurt")
	await wait_seconds(0.8)
	assert_eq(player.species_body.state.verb, "", "the roll is over")
	player.receive_hit(5, "physical")
	assert_lt(player.health.hp, hp, "and after it a hit lands")

func test_a_running_biped_slides_flat_and_stands_again() -> void:
	await _spawn("goblin")
	Input.action_press("move_right")
	await wait_physics_frames(25)
	Input.action_press("tackle")
	await wait_physics_frames(2)
	Input.action_release("tackle")
	assert_eq(player.species_body.state.verb, "slide")
	assert_eq(player.body_rect().size, BodyConfig.spread_size(), "the low box while it slides")
	Input.action_release("move_right")
	await wait_seconds(0.9)
	assert_eq(player.body_rect().size, BodyConfig.size(), "standing again")

func test_a_biped_mantles_a_ledge_in_the_game() -> void:
	await _spawn("goblin")
	var half := BodyConfig.size().x / 2.0
	_block(Rect2(half + 2.0, BodyConfig.BOTTOM - 30.0, 300, 80))  # a ledge 30 px up, its wall 2 px from the body
	await wait_physics_frames(2)
	Input.action_press("move_right")
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	await wait_seconds(1.2)
	assert_almost_eq(player.global_position.y, -30.0, 3.0, "standing on the ledge")
	assert_gt(player.global_position.x, half, "past its lip")

func test_a_biped_kicks_off_a_wall() -> void:
	await _spawn("goblin")
	var half := BodyConfig.size().x / 2.0
	_block(Rect2(half + 2.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))  # a tall wall: no ledge to mantle
	await wait_physics_frames(2)
	Input.action_press("move_right")
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	await wait_physics_frames(14)
	Input.action_press("jump")
	await wait_physics_frames(3)
	assert_lt(player.velocity.x, -60.0, "kicked back off the wall")

func test_a_spider_crawls_up_a_wall_in_the_game() -> void:
	await _spawn("spider")
	var y0 := player.global_position.y
	_block(Rect2(60.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_physics_frames(90)
	assert_true(player.species_body.is_crawling())
	assert_lt(player.species_body.state.surface_n.x, -0.9, "on the wall's left face")
	assert_lt(player.global_position.y, y0 - 20.0, "and climbing it")
	assert_eq(player.body_rect().size, SurfaceStep.box_size(player.species_body.state.surface_n))

func test_a_spider_zips_to_a_solid_and_is_pulled() -> void:
	await _spawn("spider")
	_block(Rect2(120.0, -300.0, 40, 300.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	var x0 := player.global_position.x
	Input.action_press("move_right")  # the aim
	Input.action_press("tackle")
	await wait_physics_frames(2)
	Input.action_release("tackle")
	assert_ne(player.species_body.state.zip_dir, Vector2.ZERO, "a thread pulls")
	await wait_seconds(0.6)
	assert_gt(player.global_position.x, x0 + 60.0, "pulled toward the solid")

func test_a_spider_drops_on_a_thread_from_a_ceiling() -> void:
	await _spawn("spider")
	_block(Rect2(-200.0, -200.0, 400, 20))  # a ceiling 190 px above the feet
	player.global_position.y = -120.0
	await wait_physics_frames(2)
	Input.action_press("aim_down")
	await wait_physics_frames(6)
	assert_gt(player.species_body.state.drop_up, 0.0, "hanging on a thread")
	Input.action_release("aim_down")

func test_a_crawling_spider_that_is_hit_lets_go_and_is_not_left_in_a_solid() -> void:
	await _spawn("spider")
	_block(Rect2(60.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_physics_frames(80)
	assert_true(player.species_body.is_crawling())
	Input.action_release("move_right")
	player.receive_hit(2, "physical", player.global_position + Vector2(40, 0))
	await wait_physics_frames(30)
	assert_false(player.test_move(player.global_transform, Vector2.ZERO), "free of every solid")
	assert_eq(player.body_rect().size, BodyConfig.size(), "its box is the standing one once it has fallen")

func test_a_crawling_spider_that_dies_ends_cleanly() -> void:
	await _spawn("spider")
	_block(Rect2(60.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_physics_frames(80)
	player.health.take_hit(999, "physical")
	await wait_physics_frames(10)
	assert_true(player.health.is_dead())
	assert_true(player.is_inside_tree())

func test_a_biped_with_no_sheet_still_rolls() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = "undead"
	player.use_sheet = false
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	_block(Rect2(-2000.0, BodyConfig.BOTTOM, 4000.0, 20.0))
	await wait_physics_frames(6)
	Input.action_press("tackle")
	await wait_physics_frames(2)
	assert_eq(player.species_body.state.verb, "roll")
	assert_true(player.get_node("Sprite").visible)

func test_a_spider_carried_off_its_surface_falls() -> void:
	await _spawn("spider")
	await wait_physics_frames(3)
	assert_true(player.species_body.is_crawling(), "on the floor it is on a surface")
	player.global_position += Vector2(0.0, -150.0)  # Recall, or a placement
	await wait_physics_frames(3)
	assert_false(player.species_body.is_crawling(), "and in the air it is not")
	assert_gt(player.velocity.y, 0.0, "falling")

func test_a_spider_on_a_wall_is_drawn_turned_to_it_and_with_legs_that_follow_the_distance() -> void:
	await _spawn("spider")
	_block(Rect2(60.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_physics_frames(100)
	var sprite: Sprite2D = player.get_node("Sprite")
	assert_gt(absf(sprite.rotation), 1.0, "turned a quarter turn to the wall")
	var first := sprite.texture
	await wait_physics_frames(12)
	assert_ne(sprite.texture, first, "a leg frame later")
	Input.action_release("move_right")
	await wait_physics_frames(6)
	var still := sprite.texture
	await wait_physics_frames(10)
	assert_eq(sprite.texture, still, "the legs stop when it does")

func test_a_zipping_spider_shows_its_thread() -> void:
	await _spawn("spider")
	_block(Rect2(120.0, -300.0, 40, 300.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	Input.action_press("tackle")
	await wait_physics_frames(3)
	Input.action_release("tackle")
	assert_true(player.rope_line.visible)
	assert_eq(player.rope_line.points.size(), 2)
	await wait_seconds(1.0)
	assert_false(player.rope_line.visible, "gone once the pull is over")

func test_a_crawling_spiders_hurt_shape_is_its_body_box() -> void:
	await _spawn("spider")
	_block(Rect2(60.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_physics_frames(80)
	assert_true(player.species_body.is_crawling())
	assert_eq(player.hurt_polygon().size(), 4, "a rectangle")
