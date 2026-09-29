extends GutTest
## The death effects: each cause plays its own procedural effect on the creature's sprite, ends in
## the creature lying downed, and starts the 5 s eat window only then. Real physics for the tackle.

var creatures := {}
var skills := {}
var floor_body: StaticBody2D

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func before_each() -> void:
	floor_body = StaticBody2D.new()
	floor_body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)

func _enemy(id: String = "toad", x: float = 0.0) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills)
	e.position = Vector2(x, 0)  # its 12 px box stands on the floor at y=6
	add_child_autofree(e)
	return e

func _fx(e: Enemy) -> DeathFx:
	for c in e.get_children():
		if c is DeathFx:
			return c
	return null

func _sprite(e: Enemy) -> Sprite2D:
	return e.get_node("Sprite")

func _run_out(e: Enemy) -> void:
	var guard := 0
	while e.status.state == EnemyStatus.DYING and guard < 400:
		await wait_physics_frames(1)
		guard += 1

func test_durations_are_short_and_known() -> void:
	assert_eq(DeathFx.duration("tackle"), DeathFx.TACKLE_SECONDS)
	assert_eq(DeathFx.duration("poison"), DeathFx.POISON_SECONDS)
	assert_eq(DeathFx.duration("blade"), DeathFx.BLADE_SECONDS)
	assert_gt(DeathFx.duration("other"), 0.0)
	assert_gt(DeathFx.duration("nonsense"), 0.0, "an unknown cause still ends")

func test_every_cause_ends_downed_with_the_sprite_restored() -> void:
	for cause in ["tackle", "poison", "blade", "other"]:
		var e := _enemy()
		await wait_physics_frames(2)
		e.receive_hit(9999, "physical", Vector2(-20, 0), cause)
		assert_not_null(_fx(e), cause)
		await _run_out(e)
		assert_eq(e.status.state, EnemyStatus.DOWNED, cause)
		var s := _sprite(e)
		assert_eq(s.rotation, 0.0, cause)
		assert_eq(s.scale, Vector2.ONE, cause)
		assert_eq(s.modulate, Color.WHITE, cause)
		if cause == "blade":
			assert_false(s.visible, "a cut creature stays in two pieces: the whole sprite does not come back")
			assert_not_null(e.cut_corpse(), "the halves stay as the corpse")
		else:
			assert_true(s.visible, cause)
		assert_null(_fx(e), "%s: the effect node is gone" % cause)
		e.queue_free()

func test_the_eat_window_starts_when_the_effect_ends() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	e.receive_hit(9999, "poison", Vector2(-20, 0), "poison")
	assert_false(e.can_be_predated())
	await wait_seconds(0.5)
	assert_false(e.can_be_predated(), "still melting")
	await _run_out(e)
	assert_true(e.can_be_predated())
	e.status.update(4.9)
	assert_eq(e.status.state, EnemyStatus.DOWNED, "a full 5 s window from the end of the effect")
	e.status.update(0.2)
	assert_eq(e.status.state, EnemyStatus.GONE)

func test_a_tackle_kill_knocks_the_body_away_and_it_settles_in_eat_range() -> void:
	var e := _enemy("toad", 0.0)
	await wait_physics_frames(3)
	var tackler := Vector2(-20, 0)
	var start := e.global_position
	e.receive_hit(9999, "physical", tackler, "tackle")
	await _run_out(e)
	assert_lte(absf(e.global_position.x - start.x), DeathFx.TACKLE_MAX_TRAVEL + 0.5)
	assert_gt(e.global_position.x, start.x - 0.5, "away from the tackler")
	assert_lte(e.global_position.distance_to(tackler), DeathFx.SETTLE_RANGE + 0.5, "inside eat range")
	assert_true(e.is_on_floor(), "it landed")

func test_a_tackle_kill_at_a_ledge_stays_on_the_ledge() -> void:
	floor_body.queue_free()
	var edge := StaticBody2D.new()
	edge.position = Vector2(-390, 16)  # the floor ends at x = 10
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800, 20)
	shape.shape = box
	edge.add_child(shape)
	add_child_autofree(edge)
	var e := _enemy("toad", 0.0)
	await wait_physics_frames(3)
	e.receive_hit(9999, "physical", Vector2(-1, 0), "tackle")  # point blank: the full 24 px would clear the edge
	await _run_out(e)
	assert_true(e.is_on_floor())
	assert_lt(e.global_position.x, 10.0, "still over the ground")

func test_a_blade_kill_shows_two_halves_that_slide_apart_and_leave_nothing() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	e.receive_hit(9999, "physical", Vector2(-40, 0), "blade")
	var fx := _fx(e)
	assert_false(_sprite(e).visible, "the whole sprite is replaced by the halves")
	var halves: Array = []
	for c in fx.get_children():
		if c is Sprite2D:
			halves.append(c)
	assert_eq(halves.size(), 2)
	var gap0: float = halves[0].position.distance_to(halves[1].position)
	await wait_seconds(0.3)
	assert_gt(halves[0].position.distance_to(halves[1].position), gap0, "they slide apart")
	await _run_out(e)
	assert_false(_sprite(e).visible, "the halves do not reconnect into the whole sprite")
	assert_null(_fx(e), "the effect node is gone")
	var corpse := e.cut_corpse()
	assert_not_null(corpse)
	var pieces: Array = []
	for c in corpse.get_children():
		if c is Sprite2D:
			pieces.append(c)
	assert_eq(pieces.size(), 2, "still two pieces")
	assert_gt(pieces[0].position.distance_to(pieces[1].position), 4.0, "still apart")

func test_the_blade_halves_come_to_rest_on_the_floor_not_through_it() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	var base_y := _sprite(e).position.y
	var tex_h := float(_sprite(e).texture.get_height())
	e.receive_hit(9999, "physical", Vector2(-40, 0), "blade")
	var halves: Array = []
	for c in _fx(e).get_children():
		if c is Sprite2D:
			halves.append(c)
	await wait_seconds(DeathFx.BLADE_SECONDS * 0.9)
	for h in halves:
		assert_lte(h.position.y, base_y + tex_h / 2.0 + 0.5, "no half sinks below where the body's bottom was")
	var grounded: Sprite2D = halves[0] if halves[0].position.y < halves[1].position.y else halves[1]
	assert_lte(grounded.position.y, base_y + 0.5, "the lower half never moves: it is already on the floor")
	await _run_out(e)

func test_a_poison_kill_melts_toward_the_floor_and_turns_green() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	e.receive_hit(9999, "poison", Vector2(-20, 0), "poison")
	await wait_seconds(0.6)
	var s := _sprite(e)
	assert_lt(s.scale.y, 0.9, "squashing down")
	assert_gt(s.modulate.g, s.modulate.r, "turning green")
	var bottom := s.position.y + s.texture.get_height() * s.scale.y / 2.0
	assert_almost_eq(bottom, Enemy.BODY_BOTTOM, 0.5, "it melts toward the floor, not through it")

func test_a_creature_freed_mid_effect_leaves_nothing_behind() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	e.receive_hit(9999, "physical", Vector2(-40, 0), "blade")
	var fx := _fx(e)
	e.free()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(fx))

func test_a_dying_creature_cannot_be_hit_again_or_start_a_second_effect() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	e.receive_hit(9999, "physical", Vector2(-40, 0), "blade")
	var fx := _fx(e)
	e.receive_hit(9999, "poison", Vector2(-40, 0), "poison")
	assert_same(_fx(e), fx)
	var count := 0
	for c in e.get_children():
		if c is DeathFx:
			count += 1
	assert_eq(count, 1)

func test_a_dying_creature_runs_no_ai() -> void:
	var lizard := _enemy("lizard", 0.0)
	await wait_physics_frames(2)
	lizard._charge = "windup"
	lizard.receive_hit(9999, "physical", Vector2(-30, 0), "other")
	assert_eq(lizard.charge_state(), "", "a lethal blow cancels a telegraph")


func test_a_cut_corpse_stays_cut_through_the_eat_window_and_goes_with_the_creature() -> void:
	var e := _enemy()
	await wait_physics_frames(2)
	e.receive_hit(9999, "physical", Vector2(-40, 0), "blade")
	await _run_out(e)
	for i in 30:
		await wait_physics_frames(1)
		assert_false(_sprite(e).visible, "frame %d: the whole sprite never reappears while the corpse lies there" % i)
	var corpse := e.cut_corpse()
	e.consume()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(corpse), "eaten: the halves go with it")

func test_only_a_blade_kill_leaves_a_cut_corpse() -> void:
	for cause in ["tackle", "poison", "other"]:
		var e := _enemy()
		await wait_physics_frames(2)
		e.receive_hit(9999, "physical", Vector2(-20, 0), cause)
		await _run_out(e)
		assert_null(e.cut_corpse(), cause)
		e.free()
