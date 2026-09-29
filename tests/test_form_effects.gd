extends GutTest
## Becoming a form: the stage, the level reset, the skill cap, the stats and traits, the granted skills
## and the look, without ever changing the collision box.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _to_cap() -> void:
	player.progression.add_xp(Progression.stage_total(player.progression.stage))

func test_evolving_to_weaver_sets_the_stage_resets_the_level_and_raises_the_cap() -> void:
	_to_cap()
	var ep := player.progression.ep
	assert_true(player.advance_form("weaver"))
	assert_eq(player.form.stage, 2)
	assert_eq(player.form.form_id, "weaver")
	assert_eq(player.progression.stage, 2)
	assert_eq(player.progression.level, 1)
	assert_eq(player.progression.ep, ep, "EP persists")
	assert_eq(rules.stage_cap, 8)

func test_the_level_bonuses_survive_the_reset() -> void:
	var hp_before := player.stats.get_stat("max_hp")
	_to_cap()
	var hp_at_cap := player.stats.get_stat("max_hp")
	assert_gt(hp_at_cap, hp_before)
	player.advance_form("weaver")
	var weaver: FormDef = player.forms["weaver"]
	assert_eq(player.stats.get_stat("max_hp"), hp_at_cap + int(weaver.stats["max_hp"]), "level bonuses kept, the form's added once")

func test_the_form_can_only_be_chosen_at_the_cap() -> void:
	assert_false(player.advance_form("weaver"), "level 1 cannot evolve")
	assert_eq(player.form.stage, 1)
	_to_cap()
	assert_false(player.advance_form("snare"), "not a child of the base slime")
	assert_eq(player.form.stage, 1)
	assert_false(player.advance_form("no_such_form"))
	assert_true(player.advance_form("weaver"))

func test_a_force_advance_skips_the_cap_for_tests_and_debugging() -> void:
	assert_true(player.advance_form("weaver", true))
	assert_eq(player.form.stage, 2)

func test_stat_changes_replace_rather_than_stack_from_stage_to_stage() -> void:
	_to_cap()
	player.advance_form("weaver")
	_to_cap()
	player.advance_form("snare")
	var w: FormDef = player.forms["weaver"]
	var s: FormDef = player.forms["snare"]
	var levels_hp := player.stats.level_bonus("max_hp")
	assert_eq(player.stats.get_stat("max_hp"), Player.BASE_STATS["max_hp"] + levels_hp + int(s.stats["max_hp"]), "only the current form's stats apply")
	assert_ne(int(s.stats["max_hp"]), int(w.stats["max_hp"]))

func test_a_new_run_removes_the_form() -> void:
	_to_cap()
	player.advance_form("weaver")
	rules.start_run()
	assert_eq(player.form.stage, 1)
	assert_eq(player.form.form_id, "slime")
	assert_eq(rules.stage_cap, 5)
	assert_eq(player.progression.stage, 1)
	assert_eq(player.stats.get_stat("max_hp"), Player.BASE_STATS["max_hp"])
	assert_false(player.skillset.has("trait_spinner"))

func test_a_form_grants_its_skills_once() -> void:
	_to_cap()
	assert_false(rules.owned().has("sticky_thread"))
	player.advance_form("weaver")
	assert_true(rules.owned().has("sticky_thread"))
	assert_true(player.skillset.slots.slots.has("sticky_thread"), "an active skill lands in a slot")
	_to_cap()
	player.advance_form("arachne")
	assert_true(rules.owned().has("wall_cling"))
	assert_eq(rules.owned().count("sticky_thread"), 1, "granting again changes nothing")

func test_evolving_rechecks_skills_straight_to_the_new_cap() -> void:
	for i in 40 + 20 * 12:
		rules.handle_event("jumped", {"from": "ground"})
	assert_eq(rules.level_of("leap"), 5, "held at the stage-1 cap")
	_to_cap()
	player.advance_form("greater_slime")
	assert_eq(rules.level_of("leap"), 8, "the events earned while capped are kept")

func test_the_collision_box_never_changes() -> void:
	var before := player.body_rect().size
	_to_cap()
	player.advance_form("weaver")
	_to_cap()
	player.advance_form("arachne")
	_to_cap()
	player.advance_form("silkbound")
	assert_eq(player.body_rect().size, before)

func test_every_room_exit_still_fits_the_biggest_body() -> void:
	# the box is the same at every stage, so the room geometry that fits stage 1 fits stage 4
	_to_cap()
	player.advance_form("greater_slime")
	assert_eq(player.body_rect().size, BodyConfig.size())

func test_traits_change_mp_costs_and_damage() -> void:
	_to_cap()
	player.advance_form("weaver")
	assert_eq(FormEffects.mp_cost(player.skillset.capabilities, "sticky_thread", 3), 2, "spinner")
	assert_eq(FormEffects.mp_cost(player.skillset.capabilities, "poison_breath", 4), 4, "not a thread skill")
	assert_eq(FormEffects.mp_cost(player.skillset.capabilities, "sticky_thread", 1), 1, "never below 1")
	rules.start_run()
	_to_cap()
	player.advance_form("toxic")
	assert_eq(player.skillset.incoming("poison", 30, 30)["percent_off"], FormEffects.VENOM_PERCENT)
	rules.start_run()
	_to_cap()
	player.advance_form("bulwark")
	assert_eq(player.skillset.incoming("physical", 30, 30)["flat_off"], FormEffects.SHELL_FLAT)

func test_a_form_without_art_wears_the_base_sheet_tinted_and_scaled() -> void:
	_to_cap()
	player.advance_form("tide")
	var def: FormDef = player.forms["tide"]
	assert_eq(def.sprite_set, "")
	assert_eq(player.body_tint(), def.tint)
	assert_eq(player.body_scale(), def.size)
	assert_same(player.body_sheet(), player._base_sheet)

func test_the_base_slime_wears_its_own_sheet_plain() -> void:
	assert_eq(player.body_tint(), Color.WHITE)
	assert_eq(player.body_scale(), 1.0)
	assert_same(player.body_sheet(), player._base_sheet)

func test_the_drawn_sprite_follows_the_form_and_stands_on_the_floor_line() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, Player.BODY_BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(600, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	await wait_physics_frames(14)
	_to_cap()
	player.advance_form("tide")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.2)  # the evolution moment swells and glows the sprite; let it settle
	player._update_visual(0.016)
	var s: Sprite2D = player.get_node("Sprite")
	var def: FormDef = player.forms["tide"]
	assert_eq(s.scale, Vector2.ONE * def.size)
	assert_eq(s.modulate, def.tint)
	assert_almost_eq(s.position.y + s.texture.get_height() * s.scale.y / 2.0, Player.BODY_BOTTOM, 0.01, "still on the floor line")

func test_the_hit_shape_grows_with_the_sprite() -> void:
	await wait_physics_frames(2)
	player._update_visual(0.016)
	var plain := player.hurt_polygon()
	_to_cap()
	player.advance_form("tide")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.2)
	player._update_visual(0.016)
	var grown := player.hurt_polygon()
	var w0 := 0.0
	var w1 := 0.0
	for p in plain:
		w0 = maxf(w0, absf(p.x - player.global_position.x))
	for p in grown:
		w1 = maxf(w1, absf(p.x - player.global_position.x))
	assert_almost_eq(w1 / w0, (player.forms["tide"] as FormDef).size, 0.05)

func test_a_body_swap_while_eating_leaves_the_slime_visible_afterwards() -> void:
	_to_cap()
	player.advance_form("tide")
	assert_true(player.get_node("Sprite").visible)
