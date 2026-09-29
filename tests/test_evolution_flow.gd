extends GutTest
## The evolution moment (glow, swell, a short lock and shield), the debug shortcut, and a scripted run
## through the whole tree.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var body := StaticBody2D.new()
	body.position = Vector2(0, BodyConfig.BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func after_each() -> void:
	Input.action_release("move_right")
	SkillRules.reset_run()
	Announcer.queue.clear()

func _to_cap() -> void:
	player.progression.add_xp(Progression.stage_total(player.progression.stage))

func test_evolving_starts_a_short_moment_and_it_ends() -> void:
	await wait_physics_frames(14)
	_to_cap()
	assert_false(player.evolving())
	player.advance_form("weaver")
	assert_true(player.evolving())
	assert_gt(player.evolve_glow(), 0.9, "it starts at full glow")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	assert_false(player.evolving())
	assert_eq(player.evolve_glow(), 0.0)

func test_the_moment_swells_then_settles_to_the_forms_own_size_and_stays_visible() -> void:
	await wait_physics_frames(14)
	_to_cap()
	player.advance_form("tide")
	await wait_physics_frames(3)
	var s: Sprite2D = player.get_node("Sprite")
	var rest := player.body_scale()
	assert_gt(s.scale.x, rest, "swollen")
	assert_true(s.visible)
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	player._update_visual(0.016)
	assert_eq(s.scale, Vector2.ONE * rest)
	assert_eq(s.modulate, player.body_tint())
	assert_true(s.visible)

func test_input_is_locked_and_the_slime_cannot_be_hurt_during_the_moment() -> void:
	await wait_physics_frames(14)
	_to_cap()
	player.advance_form("weaver")
	var x0 := player.global_position.x
	Input.action_press("move_right")
	await wait_physics_frames(20)
	assert_almost_eq(player.global_position.x, x0, 0.5, "no walking while evolving")
	var hp := player.health.hp
	player.receive_hit(5, "physical", Vector2(100, 0))
	assert_eq(player.health.hp, hp, "shielded")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	await wait_physics_frames(20)
	assert_gt(player.global_position.x, x0 + 5.0, "walking again afterwards")

func test_an_eat_in_progress_is_cancelled_by_evolving() -> void:
	await wait_physics_frames(14)
	_to_cap()
	player.advance_form("weaver")
	assert_false(player.predation.active())
	assert_true(player.get_node("Sprite").visible)

func test_the_debug_shortcut_grants_xp_to_the_cap() -> void:
	player.debug_grant_xp(Progression.stage_total(1))
	assert_true(player.progression.can_evolve())
	player.debug_grant_xp(50)
	assert_eq(player.progression.level, Progression.LEVEL_CAP)

func test_the_evolve_launch_argument_is_recognised() -> void:
	assert_true(Game.wants_evolve(["--evolve"]))
	assert_true(Game.wants_evolve(["--foo", "--evolve"]))
	assert_false(Game.wants_evolve([]))
	assert_false(Game.wants_evolve(["--evolved"]))

func test_a_scripted_run_takes_the_slime_through_the_whole_weaver_line() -> void:
	var path := ["weaver", "arachne", "silkbound"]
	for i in path.size():
		_to_cap()
		assert_true(player.progression.can_evolve(), "stage %d at the cap" % (i + 1))
		assert_true(player.advance_form(path[i]), path[i])
		assert_eq(player.form.stage, i + 2)
		assert_eq(rules.stage_cap, Form.STAGE_CAPS[i + 1])
	assert_eq(player.form.form_id, "silkbound")
	assert_true(rules.owned().has("sticky_thread"))
	assert_true(rules.owned().has("wall_cling"))
	assert_eq(player.body_sheet().frame_size("idle_1").x, SpriteSheet.load_set("form_silkbound").frame_size("idle_1").x)
	_to_cap()
	assert_false(player.progression.can_evolve(), "the last stage")

func test_every_branch_of_the_tree_can_be_walked_to_its_sovereign() -> void:
	var sovereigns := {}
	for lineage in ["weaver", "tide", "toxic", "bulwark", "echo", "greater_slime"]:
		for child_index in [0, 1]:
			rules.start_run()
			_to_cap()
			assert_true(player.advance_form(lineage), lineage)
			var kids: Array = FormLoader.children_of(player.forms, lineage)
			_to_cap()
			assert_true(player.advance_form((kids[child_index] as FormDef).id), (kids[child_index] as FormDef).id)
			var last: Array = FormLoader.children_of(player.forms, player.form.form_id)
			_to_cap()
			assert_true(player.advance_form((last[0] as FormDef).id))
			sovereigns[player.form.form_id] = true
			assert_eq(player.form.stage, 4)
	assert_eq(sovereigns.size(), 6)

func test_the_weaver_lineage_eats_using_its_own_cover_frames() -> void:
	await wait_physics_frames(14)
	_to_cap()
	player.advance_form("weaver")
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	var toad := Enemy.new()
	for c in DefLoader.load_dir("res://data/creatures"):
		if c.id == "toad":
			toad.setup(c, skills)
	toad.position = Vector2(player.global_position.x + 24.0, player.global_position.y)
	add_child_autofree(toad)
	toad.set_physics_process(false)
	toad.status.stun()
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	player.begin_predate()
	assert_not_null(player._cover)
	assert_same(player._cover.cover.texture, player.body_sheet().frame_texture("cover_1"))
	player.cancel_predate()
