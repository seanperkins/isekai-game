extends GutTest
## A kill leaves its parts on the floor and the player picks them up by standing on them; a corpse that times out uneaten is a deed.

class FakeBody extends Node2D:
	var got: Array = []
	func collect_part(id: String) -> void:
		got.append(id)

class SpentBody extends FakeBody:
	func can_collect_parts() -> bool:
		return false

var parts := {}
var skills_by_id := {}
var creatures := {}

func before_all() -> void:
	parts = PartLoader.load_all()
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _body(at := Vector2.ZERO, in_player_group := true) -> FakeBody:
	var b := FakeBody.new()
	b.position = at
	add_child_autofree(b)
	if in_player_group:
		b.add_to_group("player")
	return b

func _pickup(id: String, at: Vector2) -> PartPickup:
	var p := PartPickup.new()
	p.setup(parts[id], at)
	add_child_autofree(p)
	return p

func test_a_pickup_is_the_colour_of_its_part_and_sits_where_it_is_put() -> void:
	var p := _pickup("moonstone", Vector2(30, 40))
	assert_eq(p.position, Vector2(30, 40))
	assert_eq((p.get_node("Gem") as Polygon2D).color, parts["moonstone"].color)
	assert_true(p.is_in_group("pickups"))

func test_the_player_on_a_pickup_collects_it_once_and_it_is_gone() -> void:
	var body := _body()
	var p := _pickup("claw", Vector2(PartPickup.COLLECT_RANGE - 1.0, 0))
	p._physics_process(0.016)
	p._physics_process(0.016)
	assert_eq(body.got, ["claw"])
	assert_true(p.is_queued_for_deletion())

func test_a_pickup_out_of_reach_stays() -> void:
	var body := _body()
	var p := _pickup("claw", Vector2(PartPickup.COLLECT_RANGE + 1.0, 0))
	p._physics_process(0.016)
	assert_eq(body.got, [])
	assert_false(p.is_queued_for_deletion())

func test_something_that_is_not_the_player_does_not_collect() -> void:
	var other := _body(Vector2.ZERO, false)
	var p := _pickup("claw", Vector2.ZERO)
	p._physics_process(0.016)
	assert_eq(other.got, [])
	assert_false(p.is_queued_for_deletion())

func test_a_player_that_cannot_collect_leaves_it_where_it_lies() -> void:
	var odd := Node2D.new()
	add_child_autofree(odd)
	odd.add_to_group("player")
	var p := _pickup("claw", Vector2.ZERO)
	p._physics_process(0.016)
	assert_false(p.is_queued_for_deletion())

func test_a_pickup_that_was_just_dropped_waits_out_its_delay() -> void:
	var body := _body()
	var p := _pickup("claw", Vector2.ZERO)
	p.delay = 0.5
	p._physics_process(0.3)
	p._physics_process(0.3)
	assert_eq(body.got, [], "still lying")
	p._physics_process(0.3)
	assert_eq(body.got, ["claw"])

func test_a_body_that_cannot_take_parts_leaves_it_where_it_lies() -> void:
	var spent := SpentBody.new()
	add_child_autofree(spent)
	spent.add_to_group("player")
	var p := _pickup("claw", Vector2.ZERO)
	p._physics_process(0.016)
	assert_eq(spent.got, [])
	assert_false(p.is_queued_for_deletion())

func test_two_pickups_under_the_player_are_both_collected() -> void:
	var body := _body()
	var a := _pickup("claw", Vector2(3, 0))
	var b := _pickup("skull", Vector2(-3, 0))
	a._physics_process(0.016)
	b._physics_process(0.016)
	assert_eq(body.got, ["claw", "skull"])

# --- the room: a downed enemy leaves what it drops; a corpse that times out is a deed ---

func _game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	return game

func _with_drops(game: Node, drops: Array) -> void:
	var d: CreatureDef = game._creatures["bat"].duplicate()
	d.drops = drops
	game._creatures["bat"] = d

func _bat(game: Node) -> Enemy:
	var e: Enemy = game._spawn("bat", game.player.global_position + Vector2(120, -40))
	game.world.room.add_child(e)
	return e

func _pickups() -> Array:
	return get_tree().get_nodes_in_group("pickups")

func test_a_certain_drop_is_left_where_the_enemy_fell() -> void:
	var game = await _game()
	_with_drops(game, [{"part": "claw", "chance": 1.0}])
	var e := _bat(game)
	var at := e.position
	e.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(1)
	var found := _pickups().filter(func(p: Node) -> bool: return p.part.id == "claw")
	assert_eq(found.size(), 1)
	assert_eq(found[0].position, at, "one drop lies right where it fell")

func test_every_drop_of_a_creature_is_left() -> void:
	var game = await _game()
	_with_drops(game, [{"part": "claw", "chance": 1.0}, {"part": "skull", "chance": 1.0}])
	_bat(game).receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(1)
	var ids := _pickups().map(func(p: Node) -> String: return p.part.id)
	ids.sort()
	assert_eq(ids, ["claw", "skull"])
	var at := _pickups().map(func(p: Node) -> Vector2: return p.position)
	assert_gt(at[0].distance_to(at[1]), PartPickup.RADIUS, "side by side, not stacked")

func test_a_creature_with_no_drops_leaves_nothing() -> void:
	var game = await _game()
	_with_drops(game, [])
	_bat(game).receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(1)
	assert_eq(_pickups().size(), 0)

func test_a_corpse_that_times_out_uneaten_is_a_corpse_left_deed() -> void:
	var game = await _game()
	_with_drops(game, [])
	var e := _bat(game)
	e.receive_hit(999, "physical", game.player.global_position)
	e.finish_dying()
	e._physics_process(EnemyStatus.DOWNED_SECONDS + 1.0)
	await wait_physics_frames(1)
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": Deeds.CORPSE_LEFT, "tags": {"source": "bat"}, "n": 1}), 1)

func test_a_corpse_that_is_eaten_is_not() -> void:
	var game = await _game()
	_with_drops(game, [])
	var e := _bat(game)
	e.receive_hit(999, "physical", game.player.global_position)
	e.finish_dying()
	e.consume()
	e._physics_process(EnemyStatus.DOWNED_SECONDS + 1.0)
	await wait_physics_frames(1)
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": Deeds.CORPSE_LEFT, "tags": {}, "n": 1}), 0)

func test_a_corpse_still_in_its_window_has_not_yet_been_left() -> void:
	var game = await _game()
	_with_drops(game, [])
	var e := _bat(game)
	e.receive_hit(999, "physical", game.player.global_position)
	e.finish_dying()
	e._physics_process(1.0)
	await wait_physics_frames(1)
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": Deeds.CORPSE_LEFT, "tags": {}, "n": 1}), 0)

func test_a_live_enemy_that_vanishes_is_not_a_corpse_left() -> void:
	var game = await _game()
	_with_drops(game, [])
	var e := _bat(game)
	e.queue_free()
	await wait_physics_frames(2)
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": Deeds.CORPSE_LEFT, "tags": {}, "n": 1}), 0)
