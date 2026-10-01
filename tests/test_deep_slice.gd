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
	assert_eq(t.essences, {"thread": 3, "poison": 2})
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

func test_d6_sits_above_d2_behind_the_wall_cling_gate_and_holds_one_taratect() -> void:
	var d6: RoomDef = rooms["D6"]
	assert_eq(d6.cell, Vector2i(19, 5))
	assert_eq(d6.size, Vector2i(1, 1))
	assert_eq(d6.area, "deep")
	var gated := []
	for id in ["D1", "D2", "D3", "D4", "D5"]:
		for e in (rooms[id] as RoomDef).exits:
			if e.has("gate"):
				gated.append("%s:%s" % [id, e["gate"]])
	assert_eq(gated, ["D2:wall_cling"], "D2's top exit (D6's own half carries the gate too, but is outside D1 to D5)")
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

## The Taratect must hang clear of D6's floor hole (a stunned or dying hanging creature falls straight down: over the hole it would fall out of the
## room and could not be eaten) and within a creature's sight of a place the player can stand (it is alerted under CHASE_RANGE, and drops when the
## player is under it), or it never drops on anyone.
func test_the_taratect_hangs_clear_of_the_floor_hole_and_within_sight_of_a_perch() -> void:
	var d6: RoomDef = rooms["D6"]
	var hole: Dictionary = d6.exits.filter(func(e): return e["edge"] == "bottom")[0]
	var spawn: Vector2 = d6.spawns[0]["pos"]
	assert_true(spawn.x <= float(hole["from"]) - 40.0 or spawn.x >= float(hole["to"]) + 40.0, "at least 40 px from the hole's span")
	var perch := d6.solids.any(func(s):
		var r: Rect2 = s
		return r.size.y <= 12.0 and absf(spawn.x - (r.position.x + r.size.x * 0.5)) <= r.size.x * 0.5 \
			and r.position.y > spawn.y and (r.position.y - 12.0 - spawn.y) < Enemy.CHASE_RANGE)
	assert_true(perch, "a ledge under it that a standing player is within CHASE_RANGE of")
