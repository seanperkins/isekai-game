extends GutTest
## The tackle must reach a creature whose drawn body is already touching the slime's: contact is
## decided by the drawn shapes, so a tackle measured from body centres can be out of reach while
## the creature is already biting.

var rules: SkillRulesEngine
var player: Player
var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

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
	box.size = Vector2(800, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _enemy(id: String, dx: float) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills)
	add_child_autofree(e)
	e.set_physics_process(false)
	e.facing = -1
	e.global_position = Vector2(player.global_position.x + dx, player.global_position.y + Player.BODY_BOTTOM - Enemy.BODY_BOTTOM)
	e._update_visual(0.0)
	return e

func test_a_toad_whose_body_touches_the_slime_can_be_tackled() -> void:
	await wait_physics_frames(14)
	var e := _enemy("toad", 43.0)
	assert_true(e.is_touching(player), "the setup: the shapes touch")
	player.do_tackle()
	assert_eq(e.status.state, EnemyStatus.STUNNED, "it was tackled, not bitten first")

func test_a_toad_a_short_gap_away_is_still_within_the_dash() -> void:
	await wait_physics_frames(14)
	var e := _enemy("toad", 56.0)
	assert_false(e.is_touching(player))
	player.do_tackle()
	assert_eq(e.status.state, EnemyStatus.STUNNED, "the dash closes a small gap")

func test_a_creature_well_out_of_reach_is_not_tackled() -> void:
	await wait_physics_frames(14)
	var e := _enemy("toad", 140.0)
	player.do_tackle()
	assert_eq(e.status.state, EnemyStatus.ACTIVE)

func test_a_lizard_touching_the_slime_can_be_tackled_from_behind() -> void:
	await wait_physics_frames(14)
	var e := _enemy("lizard", 50.0)
	e.facing = 1  # facing away: the tackle comes from behind
	assert_true(e.is_touching(player))
	player.do_tackle()
	assert_eq(e.status.state, EnemyStatus.STUNNED)

func test_the_armored_front_still_is_not_stunned() -> void:
	await wait_physics_frames(14)
	var e := _enemy("lizard", 50.0)
	player.do_tackle()
	assert_eq(e.status.state, EnemyStatus.ACTIVE, "unchanged: only a hit from behind stuns a lizard")

func test_a_corpse_in_front_does_not_swallow_the_tackle() -> void:
	await wait_physics_frames(14)
	var corpse := _enemy("toad", 30.0)
	corpse.receive_hit(9999, "physical", Vector2(-1000, 0), "other")
	corpse.finish_dying()
	assert_eq(corpse.status.state, EnemyStatus.DOWNED)
	var live := _enemy("toad", 50.0)
	player.do_tackle()
	assert_eq(live.status.state, EnemyStatus.STUNNED, "the live toad behind the corpse is the one that is tackled")

func test_a_dying_creature_is_not_a_tackle_target_either() -> void:
	await wait_physics_frames(14)
	var dying := _enemy("toad", 30.0)
	dying.set_physics_process(false)
	dying.receive_hit(9999, "physical", Vector2(-1000, 0), "poison")
	assert_eq(dying.status.state, EnemyStatus.DYING)
	assert_null(player._tackle_target())
