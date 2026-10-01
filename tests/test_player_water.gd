extends GutTest

var water: PlayerWater
var pool: DeepWater

func before_each() -> void:
	water = PlayerWater.new()
	pool = DeepWater.make(Rect2(0, 0, 200, 200))
	add_child_autofree(pool)

func test_the_edges_and_the_clock() -> void:
	var out := water.step(get_tree(), Vector2(500, 500), 0.5)
	assert_false(out["entered"] or out["exited"])
	assert_false(water.in_water)
	out = water.step(get_tree(), Vector2(100, 100), 0.5)
	assert_true(out["entered"])
	assert_true(water.in_water)
	assert_eq(water.rect, Rect2(0, 0, 200, 200))
	assert_eq(out["submerged"], 0)
	out = water.step(get_tree(), Vector2(100, 100), 0.5)
	assert_eq(out["submerged"], 1, "once a second")
	out = water.step(get_tree(), Vector2(100, 100), 2.0)
	assert_eq(out["submerged"], 2)
	out = water.step(get_tree(), Vector2(500, 500), 0.1)
	assert_true(out["exited"])
	assert_eq(out["submerged"], 0, "nothing counts out of water")

func test_a_non_swimmer_walks_slow_and_sinks_no_faster_than_the_cap() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(140, 900), false, false, Vector2.ZERO, 120.0, 1.0, false, false, 0.0)
	assert_almost_eq(v.x, 140.0 * PlayerWater.WALK_SCALE, 0.001)
	assert_eq(v.y, PlayerWater.SINK_CAP, "a fall is capped at the sink speed")

func test_gravity_in_water_is_a_third_of_ordinary() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	# player.gd adds the dry gravity first (900 * delta); adjust replaces it with 0.35 of it
	var delta := 0.05
	var v := water.adjust(Vector2(0, 900.0 * delta), false, false, Vector2.ZERO, 120.0, 1.0, false, false, delta)
	assert_almost_eq(v.y, 900.0 * delta * PlayerWater.WATER_GRAVITY, 0.001)

func test_the_entry_edge_caps_a_dry_jump_at_the_bob() -> void:
	water.step(get_tree(), Vector2(500, 500), 0.016)
	water.step(get_tree(), Vector2(100, 100), 0.016)  # entered
	var v := water.adjust(Vector2(0, -330), false, false, Vector2.ZERO, 120.0, 1.0, false, true, 0.0)
	assert_almost_eq(v.y, -PlayerWater.BOB_VELOCITY, 0.001, "a base jump rises no faster than the bob")
	var boosted := water.adjust(Vector2(0, -330 * 1.36), false, false, Vector2.ZERO, 120.0, 1.36, false, true, 0.0)
	assert_almost_eq(boosted.y, -PlayerWater.BOB_VELOCITY * 1.36, 0.001, "the bob is boosted like a jump")

func test_the_cap_applies_only_on_entry_and_never_to_a_swimmer() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(0, -400), false, false, Vector2.ZERO, 120.0, 1.0, false, false, 0.0)
	assert_lt(v.y, -PlayerWater.BOB_VELOCITY, "Hydraulic Propulsion mid-water is not capped")
	var swimmer := water.adjust(Vector2(0, -330), false, true, Vector2.ZERO, 120.0, 1.0, false, true, 0.0)
	assert_eq(swimmer, Vector2.ZERO, "a swimmer's velocity comes from the input, never the cap")

func test_a_swimmer_moves_eight_way_at_its_speed_with_no_gravity() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(0, 50), false, true, Vector2(1, -1).normalized(), 150.0, 1.0, false, false, 1.0 / 60.0)
	assert_almost_eq(v.length(), 150.0, 0.01)
	assert_gt(v.x, 0.0)
	assert_lt(v.y, 0.0)
	var still := water.adjust(Vector2(0, 50), false, true, Vector2.ZERO, 150.0, 1.0, false, false, 1.0 / 60.0)
	assert_eq(still, Vector2.ZERO, "no gravity: it hangs where it is")

func test_a_dashing_swimmer_keeps_its_impulse_and_slows_it() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(300, 0), false, true, Vector2(-1, 0), 150.0, 1.0, true, false, 1.0 / 60.0)
	assert_gt(v.x, 0.0, "input is ignored while a hit or a tackle lock runs")
	assert_lt(v.x, 300.0, "water drags it")

func test_dry_land_is_untouched() -> void:
	var v := water.adjust(Vector2(140, 300), true, false, Vector2.ZERO, 120.0, 1.0, false, false, 0.016)
	assert_eq(v, Vector2(140, 300))

func test_a_bob_only_from_the_floor() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var bob = water.jump(Vector2.ZERO, true, false, 1.0, Vector2(100, 100))
	assert_almost_eq((bob as Vector2).y, -PlayerWater.BOB_VELOCITY, 0.001)
	assert_null(water.jump(Vector2.ZERO, false, false, 1.0, Vector2(100, 100)), "no mid-water jump")
	var boosted = water.jump(Vector2.ZERO, true, false, 1.44, Vector2(100, 100))
	assert_almost_eq((boosted as Vector2).y, -PlayerWater.BOB_VELOCITY * 1.44, 0.001)

func test_a_jump_press_on_dry_land_does_nothing_here() -> void:
	assert_null(water.jump(Vector2.ZERO, true, false, 1.0, Vector2(500, 500)))

func test_a_swimmer_launches_from_within_the_surface_reach_only() -> void:
	water.step(get_tree(), Vector2(100, 10), 0.016)  # 10 below the top edge
	var up = water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 10))
	assert_almost_eq((up as Vector2).y, Player.JUMP_VELOCITY, 0.001, "the normal jump velocity")
	assert_true(water.ballistic)
	water.reset()
	water.step(get_tree(), Vector2(100, 100), 0.016)  # 100 below
	assert_null(water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 100)))

func test_a_ballistic_launch_ignores_input_and_gravity_until_the_centre_leaves_the_rect() -> void:
	water.step(get_tree(), Vector2(100, 10), 0.016)
	water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 10))
	# player.gd has already added the dry gravity (900 * delta) when adjust runs: the launch keeps its speed, as the spec says
	var delta := 1.0 / 60.0
	var v := water.adjust(Vector2(0, -330 + 900.0 * delta), false, true, Vector2(1, 0), 150.0, 1.0, false, false, delta)
	assert_almost_eq(v.y, -330.0, 0.001, "no gravity inside the rect, and the next frame's input does not overwrite the launch")
	assert_eq(v.x, 0.0)
	assert_true(water.ballistic)
	water.step(get_tree(), Vector2(100, -5), 0.016)  # out of the rect
	assert_false(water.ballistic)

func test_reset_forgets_the_water() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	water.reset()
	assert_false(water.in_water)
	assert_eq(water.rect, Rect2())

func test_a_room_change_does_not_fire_an_exit_and_enter_pair() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	pool.free()  # the old room is gone this frame
	var next := DeepWater.make(Rect2(0, 0, 200, 200))  # the next room's water covers the same point
	add_child_autofree(next)
	var out := water.step(get_tree(), Vector2(100, 100), 0.016)
	assert_false(out["exited"] or out["entered"], "the state carries across")

func test_the_bob_apex_is_the_spec_number() -> void:
	assert_almost_eq(PlayerWater.bob_apex(185.0), 75.2, 0.05)
	assert_almost_eq(PlayerWater.bob_apex(155.0), 63.0, 0.05)

func test_a_ballistic_launch_ends_when_it_stops_rising() -> void:
	# blocked by a ceiling or an eel, or at its peak: the swimmer must get its swimming back, not stay a falling body in the water
	water.step(get_tree(), Vector2(100, 10), 0.016)
	water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 10))
	assert_true(water.ballistic)
	var v := water.adjust(Vector2(0, 15), false, true, Vector2(1, 0), 150.0, 1.0, false, false, 1.0 / 60.0)
	assert_false(water.ballistic, "a velocity that is no longer upward ends the launch")
	assert_eq(v, Vector2(150, 0), "and the input steers again")

func test_a_swimmer_holding_up_stops_at_the_surface_instead_of_leaving_it() -> void:
	pool.free()
	pool = DeepWater.make(Rect2(0, 50, 200, 150))   # a pool whose top is a surface in the room, not a door
	add_child_autofree(pool)
	water.step(get_tree(), Vector2(100, 51), 0.016)
	assert_false(water.reaches_top)
	var v := water.adjust(Vector2.ZERO, false, true, Vector2(0, -1), 120.0, 1.0, false, false, 1.0 / 60.0)
	assert_eq(v.y, 0.0, "it cannot swim out through the surface (dry gravity would pull it back and loop it in and out)")
	water.step(get_tree(), Vector2(100, 60), 0.016)
	v = water.adjust(Vector2.ZERO, false, true, Vector2(0, -1), 120.0, 1.0, false, false, 1.0 / 60.0)
	assert_eq(v.y, -120.0, "below the surface it swims up freely")

func test_a_rect_that_reaches_the_room_top_is_a_door_the_swimmer_may_cross() -> void:
	water.step(get_tree(), Vector2(100, 1), 0.016)   # the shared pool's top is y 0: a room-top edge
	assert_true(water.reaches_top)
	var v := water.adjust(Vector2.ZERO, false, true, Vector2(0, -1), 120.0, 1.0, false, false, 1.0 / 60.0)
	assert_eq(v.y, -120.0, "not clamped: swimming out through the top is how it climbs F2's column")
