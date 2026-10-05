extends GutTest
## The rare slice: the Taratect on the spider's behaviour, D6 above D2's chimney behind the Wall Cling gate.

var rooms: Dictionary
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func test_the_taratect_is_the_spiders_dropper_on_bigger_numbers() -> void:
	var t: CreatureDef = creatures["taratect"]
	assert_eq(t.xp, 12)
	assert_eq(t.essences, {"water": 2, "dark": 2})
	assert_eq([t.stats["max_hp"], t.stats["atk"], t.stats["def"]], [24, 9, 2], "level 10: x1.72")
	assert_eq(t.stats["spd"], 120)
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(t, skills_by_id)
	assert_eq(e.kind, Enemy.Kind.DROPPER)
	e.free()

func _pick(creature: String, o: Dictionary = {}) -> String:
	return EnemyState.pick(creature, o.get("status", EnemyStatus.ACTIVE), "", "idle", false, false, o.get("on_ceiling", false), o.get("on_floor", true), false, false)

func test_the_taratect_has_clips_an_arm_and_a_portrait() -> void:
	assert_eq(_pick("taratect", {"on_ceiling": true}), "hang")
	assert_eq(_pick("taratect", {"on_floor": false}), "drop")
	assert_eq(_pick("taratect"), "crawl")
	assert_true(SkillScreen.PORTRAIT_FRAME.has("taratect"))

func test_d6_is_the_two_screen_arena_beside_d7_and_holds_one_taratect() -> void:
	var d6: RoomDef = rooms["D6"]
	assert_eq(d6.cell, Vector2i(19, 5))
	assert_eq(d6.size, Vector2i(2, 1))
	assert_eq(d6.area, "deep")
	var gated := []
	for id in ["D1", "D2", "D3", "D4", "D5"]:
		for e in (rooms[id] as RoomDef).exits:
			if e.has("gate"):
				gated.append("%s:%s" % [id, e["gate"]])
	assert_eq(gated, ["D2:wall_cling"], "D2's top exit climbs to D7, the antechamber (D7's own half carries the gate too, but is outside D1 to D5)")
	assert_eq(d6.spawns.size(), 1)
	assert_eq(d6.spawns[0]["id"], "taratect")

## The chimney (C2's arch shape): two facing walls hang from the ceiling to at least 80 px above the floor, flank the opening's span with
## nothing between them, so no base jump reaches the opening and the floor underneath still walks.
func test_the_chimney_walls_hang_from_the_ceiling_and_leave_the_floor_walkable() -> void:
	var d2: RoomDef = rooms["D2"]
	var top: Dictionary = d2.exits.filter(func(e): return e["edge"] == "top")[0]
	var floor_top := d2.pixel_size().y - RoomDef.FLOOR
	var walls: Array = d2.solids.filter(func(s): return (s as Rect2).position.y <= RoomDef.WALL + 0.5 and (s as Rect2).size.y > 100.0)
	walls.sort_custom(func(a, b): return (a as Rect2).position.x < (b as Rect2).position.x)
	assert_eq(walls.size(), 2)
	var left: Rect2 = walls[0]
	var right: Rect2 = walls[1]
	assert_lte(left.end.x, float(top["from"]), "the left wall flanks the opening")
	assert_gte(right.position.x, float(top["to"]), "the right wall flanks the opening")
	assert_lte(left.end.y, floor_top - 80.0, "an arch: at least 80 px of walking height under it")
	assert_lte(right.end.y, floor_top - 80.0)
	for s in d2.solids:
		var r: Rect2 = s
		if r == left or r == right:
			continue
		assert_false(r.position.x > left.end.x and r.end.x < right.position.x and r.position.y < left.end.y, "nothing stands between the walls")

## A C2-style walk: D2's floor is walkable from its west door to its east door with no skill (the exit graph cannot see a solid across
## the route).
func test_a_player_can_walk_d2s_floor_under_the_chimney() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.world.enter_at("D2", Vector2(100, 308))
	for n in get_tree().get_nodes_in_group("actors"):
		if n != game.player:
			n.free()  # this is about the geometry: a frozen body would block the way too
	var rect: Rect2 = game.world.current_rect()
	Input.action_press("move_right")
	var best := 0.0
	for i in 900:
		await get_tree().physics_frame
		best = maxf(best, game.player.global_position.x - rect.position.x)
		if best >= 1150.0:
			break
	Input.action_release("move_right")
	assert_gte(best, 1150.0, "walked from x 100 to the east door along the floor (reached %.0f)" % best)

## The arena has no hole in its floor (nothing may fall out), and the Taratect hangs from the ceiling with the room to drop.
func test_the_arena_has_no_floor_hole_and_the_taratect_hangs_from_the_ceiling() -> void:
	var d6: RoomDef = rooms["D6"]
	assert_eq(d6.exits.filter(func(e): return e["edge"] == "bottom").size(), 0)
	var spawn: Vector2 = d6.spawns[0]["pos"]
	assert_lt(spawn.y, 120.0, "up by the ceiling")
	assert_eq(RoomLint.creature_kind("taratect"), "ceiling")

## A floor-bound player in the arena draws the awake Taratect down: hunting, it creeps along its ceiling until it is over them, then drops.
class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	func receive_hit(_raw: int, _type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

func test_a_floor_bound_player_in_the_arena_draws_the_awake_taratect_down() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	var p := StubPlayer.new()
	add_child_autofree(p)
	p.add_to_group("player")
	p.global_position = Vector2(300, 0)
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures["taratect"], skills_by_id)
	e.position = Vector2(0, -240)  # on its ceiling, 240 px up and 300 px to the side
	e.hunting = true
	add_child_autofree(e)
	assert_true(e._on_ceiling)
	for _k in 600:
		await get_tree().physics_frame
		if not e._on_ceiling:
			break
	assert_false(e._on_ceiling, "it dropped")
	assert_lt(absf(e.global_position.x - 300.0), 60.0, "over the player when it did")
