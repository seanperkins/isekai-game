extends GutTest
## The Grotto: the rooms validate, are two-way, are dressed, pay the planned XP, and nothing stands over a hole.

const BODY := Vector2(28, 24)  # the 2x slime's body box
const RISE := 55.0
const GAP := 60.0

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

func _reach_ungated() -> Array:
	var seen := ["C1"]
	var frontier := ["C1"]
	while not frontier.is_empty():
		var id: String = frontier.pop_back()
		for e in (rooms[id] as RoomDef).exits:
			if e.has("gate") or e.has("shortcut"):
				continue
			if not seen.has(e["room"]):
				seen.append(e["room"])
				frontier.append(e["room"])
	return seen

## First-time XP of a pass through `room_ids`: each spawn pays its xp for the down and again for the eat.
func _first_time(room_ids: Array) -> int:
	var total := 0
	for id in room_ids:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			total += c.xp * (1 if c.id == "water_pool" else 2)
	return total

func test_the_pacing_rule() -> void:
	var open := _reach_ungated()
	assert_true(open.has("G4"), "G4 is on the ungated route")
	var cave := open.filter(func(id): return (rooms[id] as RoomDef).area == "cave")
	assert_eq(_first_time(cave), 108, "the ungated Cave is worth 108 of its 124")
	var through_g4 := _first_time(cave) + _first_time(["G1", "G2", "G3", "G4"])
	var through_g3 := _first_time(cave) + _first_time(["G1", "G2", "G3"])
	assert_gte(through_g4, Progression.stage_total(1), "Cave + G1..G4 reaches the cap (%d)" % through_g4)
	assert_lt(through_g3, Progression.stage_total(1), "Cave + G1..G3 does not: the evolution lands in G4 (%d)" % through_g3)
	var all_cave := rooms.keys().filter(func(id): return (rooms[id] as RoomDef).area == "cave")
	assert_lt(_first_time(all_cave), Progression.stage_total(1), "the Cave alone stays under the cap")

func test_a_g1_life_can_reach_the_cap_from_the_ungated_xp() -> void:
	var p := Progression.new()
	p.start_at(3)
	var pool := _first_time(_reach_ungated())
	assert_gte(pool, 245, "a level-3 start needs 245 XP")
	p.add_xp(pool)
	assert_true(p.at_cap())

# --- the holes ---

func test_nothing_spawns_or_stands_over_a_floor_hole() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		for e in r.exits:
			if e["edge"] != "bottom" or e.has("gate") or e.has("shortcut"):
				continue  # the Cave's chimney and shortcut holes are gated, and were dressed before this rule
			var span := Vector2(e["from"], e["to"])
			var floor_y := r.pixel_size().y - RoomDef.FLOOR
			for s in r.spawns:
				assert_false(_over(span, floor_y, s["pos"], Vector2(16, 12)), "%s spawn %s over its hole" % [id, s])
			for d in r.decor:
				assert_false(_over(span, floor_y, d["pos"], Vector2(24, 24)), "%s decor %s over its hole" % [id, d])
			for p in r.dressing:
				var size := DressingLib.size(r.area, p["piece"])
				assert_false(_over(span, floor_y, p["pos"], size), "%s dressing %s over its hole" % [id, p])

## `pos` with `extent` (centred in x) overlaps the span horizontally and sits within 120 px above the floor line or below it.
func _over(span: Vector2, floor_y: float, pos: Vector2, extent: Vector2) -> bool:
	var x_overlap := pos.x + extent.x / 2.0 > span.x and pos.x - extent.x / 2.0 < span.y
	return x_overlap and pos.y >= floor_y - 120.0

# --- the climb back (directed, with headroom) ---

## The lower room's rock in its own coordinates: its bands and ledges, and the upper room's floor bands seen from
## below (rock from y -40 to 0 outside the hole).
func _rock(lower: RoomDef, hole: Vector2) -> Array:
	var out: Array = []
	for w in RoomBuilder.edge_walls(lower.pixel_size(), lower.exits):
		out.append(w["rect"])
	out.append(Rect2(-2000, -RoomDef.FLOOR, 2000 + hole.x, RoomDef.FLOOR))
	out.append(Rect2(hole.y, -RoomDef.FLOOR, lower.pixel_size().x + 2000 - hole.y, RoomDef.FLOOR))
	for s in lower.solids:
		out.append(s)
	return out

## The rising body's column over the hop must not touch any rock (other than the surface it stands on).
func _sweep_clear(rock: Array, x: float, from_top: float, to_top: float, skip: Array) -> bool:
	var column := Rect2(x - BODY.x / 2.0, to_top - BODY.y, BODY.x, from_top - to_top + BODY.y - 0.5)
	for r: Rect2 in rock:
		if skip.has(r):
			continue
		if column.intersects(r):
			return false
	return true

## True when a body standing on `p` can hop to `q`: rise within RISE, a take-off column with headroom that is
## within GAP of q sideways.
func _hop(rock: Array, p: Rect2, q: Rect2) -> bool:
	var rise := p.position.y - q.position.y
	if rise > RISE:
		return false
	var x := p.position.x + BODY.x / 2.0
	while x <= p.end.x - BODY.x / 2.0 + 0.01:
		var gap := maxf(0.0, maxf(q.position.x - (x + BODY.x / 2.0), (x - BODY.x / 2.0) - q.end.x))
		if gap <= GAP and (rise <= 0.0 or _sweep_clear(rock, x, p.position.y, q.position.y, [p])):
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
	var under := Rect2(400, 62, 90, 12)
	var top := Rect2(300, 10, 80, 12)
	assert_false(_hop(rock, under, top), "bonks the ceiling band")
	assert_true(_hop(rock, Rect2(290, 62, 90, 12), Rect2(220, 10, 90, 12)), "the real chain's second hop is fine")

func test_g2s_west_piece_reaches_the_g1_sill_and_its_east_piece_reaches_out_too() -> void:
	var g2: RoomDef = rooms["G2"]
	var sill := Rect2(20, 320, 420, 12)
	assert_true(g2.solids.has(sill), "the walkway holds G1's sill level (y 320)")
	var rock: Array = []
	for w in RoomBuilder.edge_walls(g2.pixel_size(), g2.exits):
		rock.append(w["rect"])
	for s in g2.solids:
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
