extends GutTest
## The Grotto: the rooms validate, are two-way, are dressed, pay the planned XP, and nothing stands over a hole.

const BODY := Vector2(28, 24)  # the 2x slime's body box

var rooms := {}
var creatures := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func test_the_shipped_world_validates_with_creature_ids() -> void:
	var errs := WorldValidator.validate(rooms, creatures.keys())
	assert_eq(errs.size(), 0, str(errs))

func test_the_grotto_has_its_rooms_in_the_right_cells_and_sizes() -> void:
	var want := {"G1": [Vector2i(5, 5), Vector2i(2, 1)], "G2": [Vector2i(7, 5), Vector2i(3, 2)],
		"G3": [Vector2i(8, 7), Vector2i(2, 2)], "G4": [Vector2i(10, 7), Vector2i(1, 1)]}
	for id in want:
		assert_true(rooms.has(id), id)
		assert_eq([(rooms[id] as RoomDef).cell, (rooms[id] as RoomDef).size], want[id], id)
		assert_eq((rooms[id] as RoomDef).area, "grotto", id)

func test_c5_opens_into_g1_and_spawn_keys_are_unique() -> void:
	assert_true((rooms["C5"] as RoomDef).exits.any(func(e): return e["room"] == "G1" and e["edge"] == "bottom"))
	var seen := {}
	for id in rooms:
		for i in (rooms[id] as RoomDef).spawns.size():
			var k := "%s:%d" % [id, i]
			assert_false(seen.has(k), k)
			seen[k] = true

# --- pacing: one rule, summing spawn xp directly (a Progression stops paying at the cap) ---

## The shipped rooms the start reaches without a gate or a shortcut. The walk passes through any room (a new room on the route
## is a real content change, and the shipped list is applied after it), so an added room never moves the pinned numbers.
func _reach_ungated() -> Array:
	return WorldValidator.reachable(rooms, true).filter(func(id): return ShippedRooms.IDS.has(id))

func test_the_pacing_rule() -> void:
	var open := _reach_ungated()
	assert_true(open.has("G4"), "G4 is on the ungated route")
	var cave := open.filter(func(id): return (rooms[id] as RoomDef).area == "cave")
	assert_eq(ShippedRooms.first_time(rooms, creatures, cave), 108, "the ungated Cave is worth 108 of its 124")
	var through_g4 := ShippedRooms.first_time(rooms, creatures, cave) + ShippedRooms.first_time(rooms, creatures, ["G1", "G2", "G3", "G4"])
	var through_g3 := ShippedRooms.first_time(rooms, creatures, cave) + ShippedRooms.first_time(rooms, creatures, ["G1", "G2", "G3"])
	assert_gte(through_g4, Progression.stage_total(1), "Cave + G1..G4 reaches the cap (%d)" % through_g4)
	assert_lt(through_g3, Progression.stage_total(1), "Cave + G1..G3 does not: the evolution lands in G4 (%d)" % through_g3)
	var all_cave := ShippedRooms.only(rooms).keys().filter(func(id): return (rooms[id] as RoomDef).area == "cave")
	assert_lt(ShippedRooms.first_time(rooms, creatures, all_cave), Progression.stage_total(1), "the Cave alone stays under the cap")

func test_a_g1_life_can_reach_the_cap_from_the_ungated_xp() -> void:
	var p := Progression.new()
	p.start_at(3)
	var pool := ShippedRooms.first_time(rooms, creatures, _reach_ungated())
	assert_gte(pool, 245, "a level-3 start needs 245 XP")
	p.add_xp(pool)
	assert_true(p.at_cap())

# --- the holes ---

func test_nothing_spawns_or_stands_over_a_floor_hole() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["over_hole"]), "")

# --- the climb back (directed, with headroom) ---

## The lower room's rock in its own coordinates: its bands and masses, and the upper room's floor bands seen from
## below (rock from y -40 to 0 outside the hole). Ledges are one-way, so a body rises through them: they are no headroom.
func _rock(lower: RoomDef, hole: Vector2) -> Array:
	var out: Array = []
	for w in RoomBuilder.edge_walls(lower.pixel_size(), lower.exits):
		out.append(w["rect"])
	out.append(Rect2(-2000, -RoomDef.FLOOR, 2000 + hole.x, RoomDef.FLOOR))
	out.append(Rect2(hole.y, -RoomDef.FLOOR, lower.pixel_size().x + 2000 - hole.y, RoomDef.FLOOR))
	for s in lower.solids:
		if not RoomBuilder.is_one_way(s):
			out.append(s)
	return out

func test_ledges_are_not_headroom_rock() -> void:
	for id in ["G1", "G3"]:
		var lower: RoomDef = rooms[id]
		assert_true(lower.solids.any(func(s: Rect2) -> bool: return RoomBuilder.is_one_way(s)), "%s has ledges" % id)
		var rock := _rock(lower, Vector2(220, 380))
		for s: Rect2 in lower.solids:
			assert_eq(rock.has(s), not RoomBuilder.is_one_way(s), "%s: %s is rock only if it is not a ledge" % [id, s])

## The rising body's column over the hop must not touch any rock (other than the surface it stands on).
func _sweep_clear(rock: Array, x: float, from_top: float, to_top: float, skip: Array) -> bool:
	var column := Rect2(x - BODY.x / 2.0, to_top - BODY.y, BODY.x, from_top - to_top + BODY.y - 0.5)
	for r: Rect2 in rock:
		if skip.has(r):
			continue
		if column.intersects(r):
			return false
	return true

## True when a body standing on `p` can hop to `q`: rise within RoomLint.REACH_RISE, a take-off column with headroom that is
## within RoomLint.REACH_GAP of q sideways.
func _hop(rock: Array, p: Rect2, q: Rect2) -> bool:
	var rise := p.position.y - q.position.y
	if rise > RoomLint.REACH_RISE:
		return false
	var x := p.position.x + BODY.x / 2.0
	while x <= p.end.x - BODY.x / 2.0 + 0.01:
		var gap := maxf(0.0, maxf(q.position.x - (x + BODY.x / 2.0), (x - BODY.x / 2.0) - q.end.x))
		if gap <= RoomLint.REACH_GAP and (rise <= 0.0 or _sweep_clear(rock, x, p.position.y, q.position.y, [p])):
			return true
		x += 4.0
	return false

## Climb from the lower room's floor to `target` (a surface of the upper room, in the lower room's coordinates).
func _climbs(lower: RoomDef, hole: Vector2, target: Rect2) -> bool:
	var rock := _rock(lower, hole)
	var floor_top := lower.pixel_size().y - RoomDef.FLOOR
	var surfaces: Array = lower.solids.filter(func(s: Rect2) -> bool: return s.size.y <= 24.0 and s.size.x > 20.0)
	surfaces.append(target)
	var reached: Array = []
	var frontier: Array = [Rect2(RoomDef.WALL, floor_top, lower.pixel_size().x - 2.0 * RoomDef.WALL, 1)]
	while not frontier.is_empty():
		var p: Rect2 = frontier.pop_back()
		for q: Rect2 in surfaces:
			if reached.has(q):
				continue
			if _hop(rock, p, q):
				reached.append(q)
				frontier.append(q)
	return reached.has(target)

func test_a_player_dropped_into_g1_can_climb_back_to_c5s_west_piece() -> void:
	var hole := Vector2(220, 380)
	var g1: RoomDef = rooms["G1"]
	assert_true(_climbs(g1, hole, Rect2(0, -RoomDef.FLOOR, hole.x, 1)))

func test_a_player_dropped_into_g3_can_climb_back_to_g2s_west_piece() -> void:
	var hole := Vector2(160, 320)  # G3's local span; G2's floor west of it runs from G2's west wall
	var g3: RoomDef = rooms["G3"]
	assert_true(_climbs(g3, hole, Rect2(-640, -RoomDef.FLOOR, 640.0 + hole.x, 1)))

func test_the_headroom_term_sees_a_hop_under_the_ceiling_band() -> void:
	# a ledge east of the hole, under the ceiling band, cannot hop up into the hole's top ledge: the body bonks at 23 px
	var g1: RoomDef = rooms["G1"]
	var rock := _rock(g1, Vector2(220, 380))
	var under := Rect2(400, 66, 90, 12)
	var top := Rect2(300, 14, 80, 12)
	assert_false(_hop(rock, under, top), "bonks the ceiling band")
	assert_true(_hop(rock, Rect2(290, 66, 90, 12), Rect2(220, 14, 90, 12)), "the real chain's second hop is fine")

func test_g2s_west_piece_reaches_the_g1_sill_and_its_east_piece_reaches_out_too() -> void:
	var g2: RoomDef = rooms["G2"]
	var sill := Rect2(20, 320, 420, 12)
	assert_true(g2.solids.has(sill), "the walkway holds G1's sill level (y 320)")
	var rock: Array = []
	for w in RoomBuilder.edge_walls(g2.pixel_size(), g2.exits):
		rock.append(w["rect"])
	for s in g2.solids:
		if not RoomBuilder.is_one_way(s):
			rock.append(s)
	var surfaces: Array = g2.solids.filter(func(s: Rect2) -> bool: return s.size.y <= 24.0 and s.size.x > 20.0)
	var west_floor := Rect2(20, 680, 780, 1)
	var east_floor := Rect2(960, 680, 940, 1)
	for start in [west_floor, east_floor]:
		var reached: Array = []
		var frontier: Array = [start]
		while not frontier.is_empty():
			var p: Rect2 = frontier.pop_back()
			for q: Rect2 in surfaces:
				if not reached.has(q) and _hop(rock, p, q):
					reached.append(q)
					frontier.append(q)
		assert_true(reached.has(sill), "from %s the G1 sill is reachable" % [start])

# --- the optional slice: G5 and its wall-cling gate ---

func test_g5_holds_one_pale_moth_and_is_gated_off_the_ungated_route() -> void:
	var g5: RoomDef = rooms["G5"]
	assert_eq(g5.cell, Vector2i(7, 7))
	assert_eq(g5.area, "grotto")
	assert_eq(g5.spawns.map(func(s): return s["id"]), ["pale_moth"])
	assert_true((rooms["G3"] as RoomDef).exits.any(func(e): return e["room"] == "G5" and e.get("gate", "") == "wall_cling"))
	assert_false(_reach_ungated().has("G5"))
	assert_eq(ShippedRooms.first_time(rooms, creatures, ["G5"]), 16, "the pale moth is worth 16 first time and never counts toward the pacing")

## The highest jump apex a body can reach from a stage-1 or stage-2 form: Leap at the stage's cap plus the best
## jump_height bonus among that stage's forms, from Player's own jump constants.
func _max_apex_stages_1_and_2() -> float:
	var leap: SkillDef = null
	for d in DefLoader.load_dir("res://data/skills"):
		if d.id == "leap":
			leap = d
	var forms := FormLoader.load_all()
	var best := 0.0
	for stage in [1, 2]:
		var cap: int = Form.STAGE_CAPS[stage - 1]
		var jump_height := 100 + int(SkillEffects.value_at(leap.effects[0], cap))
		var form_bonus := 0
		for f in forms.values():
			if (f as FormDef).stage == stage:
				form_bonus = maxi(form_bonus, int((f as FormDef).stats.get("jump_height", 0)))
		var boost := sqrt(float(jump_height + form_bonus) / 100.0)
		var v: float = -Player.JUMP_VELOCITY * boost
		best = maxf(best, v * v / (2.0 * Player.GRAVITY))
	return best

func test_the_chimney_screens_the_g5_opening_below_every_early_jump() -> void:
	var g3: RoomDef = rooms["G3"]
	var opening: Dictionary = {}
	for e in g3.exits:
		if e["room"] == "G5":
			opening = e
	assert_false(opening.is_empty())
	var lip: float = opening["to"]  # the opening's lower lip (its sill), in G3's local y
	var t := _max_apex_stages_1_and_2() + 3.0
	assert_almost_eq(t, 96.775, 0.01, "Leap 8 plus Echo's +10 gives 93.775, plus the 3 px margin")
	# the hanging wall: thin (<= 20 wide), from the ceiling band down to at least T below the lip
	var wall := Rect2()
	for s: Rect2 in g3.solids:
		if s.size.x <= 20.0 and s.size.y > 24.0 and s.position.y <= RoomDef.WALL + 1.0 and s.position.x < 200.0:
			wall = s
	assert_gt(wall.size.x, 0.0, "the chimney's hanging wall exists")
	assert_gte(wall.end.y, lip + t, "it hangs at least T below the lip (%.1f)" % (lip + t))
	# nothing between the hanging wall and the west wall above its bottom (no ledge inside the chimney)
	for s: Rect2 in g3.solids:
		if s == wall:
			continue
		assert_false(Rect2(RoomDef.WALL, 0, wall.position.x - RoomDef.WALL, wall.end.y).intersects(s), "a solid inside the chimney: %s" % s)

func test_no_base_jump_path_reaches_the_g5_sill() -> void:
	var g3: RoomDef = rooms["G3"]
	var sill := Rect2(-20, 320, 40, 1)
	var rock: Array = []
	for w in RoomBuilder.edge_walls(g3.pixel_size(), g3.exits):
		rock.append(w["rect"])
	for s in g3.solids:
		if RoomBuilder.is_one_way(s, g3.hard_ledges):
			continue  # a ledge is one-way: a body rises through it, so it is no headroom rock
		rock.append(s)
	var surfaces: Array = g3.solids.filter(func(s: Rect2) -> bool: return s.size.y <= 24.0 and s.size.x > 20.0)
	surfaces.append(sill)
	var reached: Array = []
	var frontier: Array = [Rect2(RoomDef.WALL, 680, g3.pixel_size().x - 2.0 * RoomDef.WALL, 1)]
	while not frontier.is_empty():
		var p: Rect2 = frontier.pop_back()
		for q: Rect2 in surfaces:
			if not reached.has(q) and _hop(rock, p, q):
				reached.append(q)
				frontier.append(q)
	assert_false(reached.has(sill), "the opening is beyond every base jump")


func test_nothing_spawns_near_a_rebirth_pool() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["pool_clearance"]), "")

