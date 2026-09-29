extends GutTest
## Contact damage between a REAL player body and a REAL enemy body. The two boxes block each other
## and can only touch, so the contact test must reach across a touching pair. (A bodiless stub
## player, as in test_enemy_ai.gd, cannot catch this.)

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

func _enemy(id: String, x: float) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills)
	e.position = Vector2(x, BodyConfig.BOTTOM - 6.0)  # its 12px box stands on the same floor
	add_child_autofree(e)
	return e

func test_a_walking_enemy_pressed_against_the_slime_hurts_it() -> void:
	_enemy("lizard", 80.0)
	await wait_physics_frames(200)
	assert_lt(player.health.hp, player.health.max_hp, "the lizard reached the slime and should have bitten")

func test_touching_shapes_count_as_contact() -> void:
	await wait_physics_frames(14)  # the landing squash is over: the slime is its idle frame
	var e := Enemy.new()
	e.use_sheet = false  # its box, so the test measures the slime's drawn edge
	e.setup(creatures["lizard"], skills)
	add_child_autofree(e)
	var right := -INF
	for p in player.hurt_polygon():
		right = maxf(right, p.x)
	e.global_position = Vector2(right + e.BODY_SIZE.x / 2.0, BodyConfig.BOTTOM - 6.0)  # edge to edge with the drawn skin
	assert_true(e.is_touching(player))
	e.global_position.x += 6.0
	assert_false(e.is_touching(player))

func test_a_bodiless_stub_falls_back_to_the_old_distance_check() -> void:
	var stub := Node2D.new()
	add_child_autofree(stub)
	var e := _enemy("lizard", 0.0)
	stub.global_position = Vector2(10, 0)
	assert_true(e.is_touching(stub))
	stub.global_position = Vector2(60, 0)
	assert_false(e.is_touching(stub))

func test_body_rect_follows_the_collision_box_and_spread() -> void:
	var r := player.body_rect()
	assert_eq(r.size, BodyConfig.size())
	assert_almost_eq(r.end.y, player.global_position.y + BodyConfig.BOTTOM, 0.001)
	player.set_spread(true)
	var flat := player.body_rect()
	assert_eq(flat.size, BodyConfig.spread_size())
	assert_almost_eq(flat.end.y, player.global_position.y + BodyConfig.BOTTOM, 0.001)
