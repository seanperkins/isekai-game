extends GutTest
## A twin is one still frame, so it is moved instead of animated: it breathes (a slow squash of its height, its feet fixed), hops and leans as it
## walks, and holds rigid when it is stunned or down. Two creatures of one kind do not breathe in step.

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _twin(key := "T:1") -> Enemy:
	var e := Enemy.new()
	e.setup(creatures["twin_wolf_fenrir"], skills_by_id)
	e.spawn_key = key
	e.set_physics_process(false)  # the test drives the clock
	add_child_autofree(e)
	return e

func _sprite(e: Enemy) -> Sprite2D:
	return e.get_node("Sprite")

func _draw_at(e: Enemy, t: float) -> void:
	e._anim_t = t
	e._update_visual(0.0)

func _feet(e: Enemy) -> float:
	var s := _sprite(e)
	var h: float = (s.texture as AtlasTexture).region.size.y * s.scale.y
	return s.position.y + h / 2.0

func test_a_still_breathes_within_three_percent_and_its_feet_stay_on_the_floor() -> void:
	var e := _twin()
	var size: float = creatures["twin_wolf_fenrir"].sprite_size
	var low := INF
	var high := -INF
	for i in 40:
		_draw_at(e, i * 0.1)
		var y := _sprite(e).scale.y
		low = minf(low, y)
		high = maxf(high, y)
		assert_almost_eq(_feet(e), Enemy.BODY_BOTTOM, 0.01, "feet on the floor at t=%s" % (i * 0.1))
	assert_gt(high - low, size * 0.04, "it moves")
	assert_lt(high, size * 1.031)
	assert_gt(low, size * 0.969)

func test_a_still_that_walks_hops_and_leans_towards_where_it_faces() -> void:
	var e := _twin()
	e.velocity = Vector2(60, 0)
	e.facing = 1
	var rose := 0.0
	var lean := 0.0
	for i in 40:
		_draw_at(e, i * 0.05)
		rose = maxf(rose, Enemy.BODY_BOTTOM - _feet(e))
		lean = maxf(lean, _sprite(e).rotation)
	assert_gt(rose, 1.0, "it leaves the floor at the top of a hop")
	assert_lte(rose, 4.01)
	assert_gt(lean, 0.02, "leaning right")
	e.facing = -1
	_draw_at(e, 0.2)
	assert_lte(_sprite(e).rotation, 0.0, "leaning left when it faces left")

func test_a_still_standing_does_not_hop_or_lean() -> void:
	var e := _twin()
	for i in 20:
		_draw_at(e, i * 0.1)
		assert_eq(_sprite(e).rotation, 0.0)

func test_a_stunned_or_downed_still_holds_rigid() -> void:
	var e := _twin()
	e.velocity = Vector2(60, 0)
	e.status.stun(5.0)
	_draw_at(e, 0.37)
	var size: float = creatures["twin_wolf_fenrir"].sprite_size
	assert_eq(_sprite(e).scale, Vector2.ONE * size)
	assert_eq(_sprite(e).rotation, 0.0)
	var d := _twin("T:2")
	d.status.state = EnemyStatus.DOWNED
	_draw_at(d, 0.37)
	assert_eq(_sprite(d).scale, Vector2.ONE * size)
	assert_eq(_sprite(d).rotation, 0.0)

func test_two_creatures_do_not_breathe_in_step() -> void:
	var a := _twin("A:1")
	var b := _twin("B:2")
	var apart := 0
	for i in 30:
		_draw_at(a, i * 0.1)
		_draw_at(b, i * 0.1)
		if absf(_sprite(a).scale.y - _sprite(b).scale.y) > 0.005:
			apart += 1
	assert_gt(apart, 10, "different phases")
	var c := _twin("A:1")
	_draw_at(a, 0.7)
	_draw_at(c, 0.7)
	assert_eq(_sprite(a).scale, _sprite(c).scale, "the same key breathes the same")

func test_a_creature_that_is_not_a_still_is_untouched() -> void:
	var e := Enemy.new()
	e.setup(creatures["lizard"], skills_by_id)
	e.set_physics_process(false)
	add_child_autofree(e)
	_draw_at(e, 0.3)
	assert_eq(_sprite(e).scale, Vector2.ONE)
	assert_eq(_sprite(e).rotation, 0.0)
