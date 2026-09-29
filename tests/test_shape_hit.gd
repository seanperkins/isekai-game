extends GutTest
## Hits are decided by the traced shapes, in global points. Needs a real Player with the slime sheet.

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

func _square(at: Vector2, size: float = 10.0) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(size, 0), at + Vector2(size, size), at + Vector2(0, size)])

func test_overlapping_shapes_overlap_and_apart_ones_do_not() -> void:
	assert_true(ShapeHit.overlap(_square(Vector2.ZERO), _square(Vector2(5, 5))))
	assert_false(ShapeHit.overlap(_square(Vector2.ZERO), _square(Vector2(30, 0))))

func test_touching_shapes_count_with_the_margin_and_not_without() -> void:
	var a := _square(Vector2.ZERO)
	var touching := _square(Vector2(10, 0))
	assert_true(ShapeHit.overlap(a, touching, 2.0))
	var gap := _square(Vector2(13, 0))
	assert_false(ShapeHit.overlap(a, gap, 2.0), "3 px apart is beyond a 2 px margin")

func test_empty_shapes_never_overlap() -> void:
	assert_false(ShapeHit.overlap(PackedVector2Array(), _square(Vector2.ZERO)))
	assert_false(ShapeHit.overlap(_square(Vector2.ZERO), PackedVector2Array([Vector2.ZERO, Vector2.ONE])))

func test_a_point_is_near_a_shape_within_its_radius() -> void:
	var sq := _square(Vector2.ZERO)
	assert_true(ShapeHit.point_near(sq, Vector2(5, 5), 0.0), "inside")
	assert_true(ShapeHit.point_near(sq, Vector2(13, 5), 4.0), "3 px outside, radius 4")
	assert_false(ShapeHit.point_near(sq, Vector2(20, 5), 4.0))

func test_the_player_hurt_shape_is_the_drawn_frame_standing_on_the_floor_line() -> void:
	await wait_physics_frames(14)
	var poly := player.hurt_polygon()
	assert_gt(poly.size(), 3)
	var lowest := -INF
	var xs: Array = []
	for p in poly:
		lowest = maxf(lowest, p.y)
		xs.append(p.x)
	assert_almost_eq(lowest, player.global_position.y + Player.BODY_BOTTOM, 0.6, "its lowest point is the floor line")
	assert_gt(xs.max() - xs.min(), BodyConfig.size().x, "the shape follows the wider drawn skin, not the 28 px box")

func test_a_player_without_a_sheet_falls_back_to_its_box() -> void:
	var bare := Player.new()
	bare.use_sheet = false
	bare.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(bare)
	var poly := bare.hurt_polygon()
	assert_eq(poly.size(), 4)
	assert_eq(Rect2(poly[0], Vector2.ZERO).expand(poly[2]), bare.body_rect())

func test_an_enemy_without_a_sheet_uses_its_box_as_its_hurt_shape() -> void:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures["toad"], skills)
	e.position = Vector2(100, 0)
	add_child_autofree(e)
	e.set_physics_process(false)
	var poly := e.hurt_polygon()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	assert_eq(r.size, Enemy.BODY_SIZE)

func test_contact_follows_the_shapes_not_the_centres() -> void:
	await wait_physics_frames(14)
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures["lizard"], skills)
	add_child_autofree(e)
	e.set_physics_process(false)
	var reach := player.hurt_polygon()
	var right := -INF
	for p in reach:
		right = maxf(right, p.x)
	e.global_position = Vector2(right + Enemy.BODY_SIZE.x / 2.0 + 1.0, player.global_position.y + Player.BODY_BOTTOM - Enemy.BODY_BOTTOM)
	assert_true(e.is_touching(player), "the enemy's box against the slime's drawn edge is contact")
	e.global_position.x += 8.0
	assert_false(e.is_touching(player))

func test_a_glob_hits_the_slime_where_it_is_drawn_and_misses_where_it_is_not() -> void:
	await wait_physics_frames(14)
	var poly := player.hurt_polygon()
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= poly.size()
	assert_true(SpitBlob.hits(player, centre))
	assert_false(SpitBlob.hits(player, centre + Vector2(80, 0)))

func test_a_glob_that_arrives_at_the_floor_hits_a_spread_slime() -> void:
	await wait_physics_frames(14)
	Input.action_press("aim_down")
	await wait_physics_frames(6)
	assert_true(player.spreading)
	var poly := player.hurt_polygon()
	var top := INF
	for p in poly:
		top = minf(top, p.y)
	assert_lt(top, player.global_position.y + Player.BODY_BOTTOM, "the puddle has height")
	assert_true(SpitBlob.hits(player, Vector2(player.global_position.x, player.global_position.y + Player.BODY_BOTTOM - 3.0)))
	assert_false(SpitBlob.hits(player, Vector2(player.global_position.x, top - 12.0)), "a glob passing well above a puddle misses")
	Input.action_release("aim_down")
