extends GutTest

func _world() -> FakeSurfaceWorld:
	return FakeSurfaceWorld.build_spike_terrain()

func test_sweep_stops_at_a_wall_and_reports_its_normal() -> void:
	var w := _world()
	w.pos = Vector2(180, -12)
	var hit: Dictionary = w.input().sweep.call(Vector2(10, 0))
	assert_false(hit.is_empty())
	assert_almost_eq((hit["travel"] as Vector2).x, 6.0, 0.01)
	assert_eq(hit["normal"], Vector2.LEFT)

func test_sweep_is_free_in_open_space_and_ignores_a_ledge_sideways() -> void:
	var w := _world()
	w.pos = Vector2(600, -300)
	assert_true((w.input().sweep.call(Vector2(50, 0)) as Dictionary).is_empty())
	w.pos = Vector2(830, -47)  # level with the one-way ledge, 6 px short of its left end
	assert_true((w.input().sweep.call(Vector2(20, 0)) as Dictionary).is_empty(), "a one-way ledge never blocks from the side")

func test_sweep_along_the_floor_does_not_catch_on_it() -> void:
	var w := _world()
	w.pos = Vector2(40, -12)
	assert_true((w.input().sweep.call(Vector2(2.3, 0)) as Dictionary).is_empty())

func test_ray_reports_hard_and_oneway_and_respects_hard_only() -> void:
	var w := _world()
	w.pos = Vector2(900, -100)
	var i := w.input()
	assert_eq(i.ray.call(Vector2.ZERO, Vector2(0, 100), false), 2, "the ledge top is hit first")
	assert_eq(i.ray.call(Vector2.ZERO, Vector2(0, 100), true), 1, "hard only passes it and meets the floor")
	assert_eq(i.ray.call(Vector2.ZERO, Vector2(0, 30), true), 0)
	w.pos = Vector2(100, -20)
	assert_eq(w.input().ray.call(Vector2.ZERO, Vector2(0, 40), false), 1)

func test_the_box_swaps_on_a_wall() -> void:
	var w := _world()
	w.pos = Vector2(180, -14)
	w.n = Vector2.LEFT
	var hit: Dictionary = w.input().sweep.call(Vector2(10, 0))
	assert_almost_eq((hit["travel"] as Vector2).x, 8.0, 0.01, "24 wide on a wall: 12 half width")
	w.n = Vector2.UP
	hit = w.input().sweep.call(Vector2(10, 0))
	assert_almost_eq((hit["travel"] as Vector2).x, 6.0, 0.01, "28 wide on a floor: 14 half width")

func test_apply_moves_the_body_and_takes_the_new_normal() -> void:
	var w := _world()
	var s := MoveState.new()
	s.surface_shift = Vector2(3, -2)
	s.surface_n = Vector2.LEFT
	w.pos = Vector2(10, 10)
	w.apply(s)
	assert_eq(w.pos, Vector2(13, 8))
	assert_eq(w.n, Vector2.LEFT)
