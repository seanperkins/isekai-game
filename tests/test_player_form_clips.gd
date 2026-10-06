extends GutTest
## The player as an evolved wolf, goblin or undead plays the form's animated clips (lit, mirrored in the texture): idle, walk and run as fast as it goes,
## the strike when it casts its verb, the flinch when it is hit. A form without clips (a spider's, a slime's) still draws as its picture.

var rules: SkillRulesEngine
var player: Player

func _spawn(species: String) -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = species
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0.0, BodyConfig.BOTTOM + 10.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000.0, 20.0)
	shape.shape = rect
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	await wait_physics_frames(6)

func _evolve(id: String) -> void:
	assert_true(player.advance_form(id, true), id)
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	await wait_physics_frames(3)

func after_each() -> void:
	for a in ["move_right", "move_left", "jump"]:
		Input.action_release(a)
	SkillRules.reset_run()
	Announcer.queue.clear()

func _sprite() -> Sprite2D:
	return player.get_node("Sprite")

func test_an_evolved_wolf_animates_instead_of_standing_as_its_picture() -> void:
	await _spawn("wolf")
	await _evolve("wolf_warg")
	assert_eq(player.still_frame(), "", "no still")
	assert_true(player.form_animates())
	assert_eq(player._animator.state(), "idle")
	assert_true(_sprite().texture is CanvasTexture, "lit by the room's lights")
	assert_eq(_sprite().scale, Vector2.ONE, "at the sheet's own size")

func test_it_walks_and_runs_as_fast_as_it_goes_and_does_not_run_in_place() -> void:
	await _spawn("wolf")
	await _evolve("wolf_warg")
	Input.action_press("move_right")
	await wait_physics_frames(30)
	assert_true(["walk", "run"].has(player._animator.state()), "moving: %s" % player._animator.state())
	assert_gt(absf(player.velocity.x), 20.0)
	var speed := absf(player.velocity.x)
	var expect := "run" if FormPose.running(speed, FormClips.walk_speed_of("wolf_warg")) else "walk"
	assert_eq(player._animator.state(), expect, "run once it is clearly faster than its walk")
	Input.action_release("move_right")
	await wait_physics_frames(40)
	assert_eq(player._animator.state(), "idle")

func test_in_the_air_it_does_not_stand_still() -> void:
	await _spawn("wolf")
	await _evolve("wolf_warg")
	player.global_position.y -= 90.0
	await wait_physics_frames(4)
	assert_ne(player._animator.state(), "idle", "a body in the air shows its running pose")

func test_it_is_mirrored_in_its_texture_when_it_faces_left() -> void:
	await _spawn("wolf")
	await _evolve("wolf_warg")
	Input.action_press("move_left")
	await wait_physics_frames(20)
	assert_false(_sprite().flip_h, "turned round in the texture, so its normals turn with it")
	assert_eq(_sprite().texture, player._sheet.texture_of(player._animator.frame(), true))

func test_casting_its_verb_plays_the_strike_and_then_goes_back_to_its_loop() -> void:
	await _spawn("goblin")
	assert_true(player.become_form("goblin_giant_killer"), "the form and every form before it")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)  # the evolution's shield (it looks like a flinch) is over
	assert_true(player.form_animates())
	assert_eq(player.skillset.slots.use(0), "verb_goblin_giant_killer", "its verb is in the first slot")
	player.use_active(0)
	await wait_physics_frames(2)
	assert_eq(player._animator.state(), "recover", "the follow-through of a blow")
	await wait_seconds(Player.CAST_POSE_SECONDS + 0.25)
	assert_eq(player._animator.state(), "idle")

func test_a_blow_to_it_plays_the_flinch() -> void:
	await _spawn("undead")
	await _evolve("undead_zombie")
	player.receive_hit(1, "physical", player.global_position + Vector2(40.0, 0.0))
	await wait_physics_frames(2)
	assert_eq(player._animator.state(), "hurt")

func test_a_spider_form_still_draws_as_its_picture() -> void:
	await _spawn("spider")
	await _evolve("spider_weavermaid")
	assert_ne(player.still_frame(), "")
	assert_false(player.form_animates())

func test_the_default_goblin_stabs_when_it_casts_its_blow_and_a_wolf_without_a_blow_does_not() -> void:
	await _spawn("goblin")
	assert_false(player.form_animates(), "the base body has its own sheet")
	assert_eq(player.skillset.slots.use(0), "verb_goblin")
	player.use_active(0)
	await wait_physics_frames(2)
	assert_eq(player._animator.state(), "recover", "the follow-through of the jab")
	await wait_seconds(Player.CAST_POSE_SECONDS + 0.25)
	assert_eq(player._animator.state(), "idle")
