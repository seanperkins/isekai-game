class_name AreaPlacement
extends AreaModule
## Puts the new creatures in the world's rooms (docs/research/areas-f2.md, "Placement of creatures"): the plan (tools/creature_areas.json, written
## by tools/build_creatures.py) gives each creature its areas and class, the lairs a rare may stand in and the rooms nothing stands in. Each
## creature, the hardest to place first, goes to the emptiest room of its areas (a rare's lairs first) at the spot on a surface of that room
## where it has the most clear floor around it and every spawn rule of RoomLint holds. A spot also keeps the creature's drawn size in mind: its
## head room, the doorways clear, no overlap with a neighbour. The spawns are marked `by: PL`, so the builder strips them on the next run; the
## hand-made spawns and the area modules' own are never touched. A creature no room can hold is in `unplaced` and is reported.

const PLAN_PATH := "res://tools/creature_areas.json"
const MARK := "PL"
const WEIGHT := {"common": 1.0, "elite": 2.0, "rare": 3.0}
const CLASS_RANK := {"rare": 0, "elite": 1, "common": 2}
## x spacing of the spots tried along a surface.
const STEP := 24.0
## Clear floor between two creatures on one surface, and from a surface's end.
const GAP := 14.0
const EDGE := 12.0
## Clear height over a creature, times its drawn height: under a block or the ceiling, and under a ledge it could jump through.
const HEAD := 1.1
const LEDGE_HEAD := 0.7
## Two spawns whose y differs by less than this stand on the same level.
const LEVEL := 60.0
## A hovering creature's height above the room's top.
const HOVER_Y := 150.0
const FALLBACK_SIZE := Vector2(32.0, 32.0)

## The ids no room could hold.
var unplaced: Array = []
var _plan: Dictionary
var _defs: Dictionary

## `plan` is the plan's JSON (the file's when empty); `defs` the creatures by id (the game's when empty).
func _init(plan := {}, defs := {}) -> void:
	_plan = plan if not plan.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	_defs = defs
	if _defs.is_empty():
		for c in DefLoader.load_dir("res://data/creatures"):
			_defs[c.id] = c

func area() -> String:
	return "placement"

func prefix() -> String:
	return MARK

## The drawn size of a creature: its sheet's frame, or the creature it wears, times its `sprite_size`.
static func size_of(def: CreatureDef) -> Vector2:
	var s := Vector2.ZERO
	if def.sprite_set != "" and SpriteSheet.available(def.sprite_set):
		s = SpriteSheet.load_set(def.sprite_set).frame_size(def.sprite_frame if def.sprite_frame != "" else "idle_1")
	elif def.wears != "":
		s = RoomLint.creature_extent(def.wears)
	if s == Vector2.ZERO:
		s = FALLBACK_SIZE
	return s * (def.sprite_size if def.sprite_size > 0.0 else 1.0)

func build(world: Dictionary) -> void:
	unplaced = []
	var quiet: Array = _plan.get("quiet", [])
	var lairs: Array = _plan.get("lairs", [])
	var by_area := {}
	var loads := {}
	for id in world:
		var r: RoomDef = world[id]
		loads[id] = float(r.spawns.size())
		if r.is_start() or not r.boss.is_empty() or quiet.has(id):
			continue
		by_area[r.area] = by_area.get(r.area, []) + [id]
	for cid in _order():
		var row: Dictionary = _plan["creatures"][cid]
		var cls: String = row["class"]
		var def: CreatureDef = _defs.get(cid)
		if def == null:
			unplaced.append(cid)
			push_error("placement: %s is in the plan but is not a creature" % cid)
			continue
		var size := size_of(def)
		var spot = null
		var home := ""
		for room_id in _rooms_for(row, cls, by_area, lairs, loads, world):
			spot = _find_spot(world[room_id], cid, size)
			if spot != null:
				home = room_id
				break
		if spot == null:
			unplaced.append(cid)
			push_error("placement: %s has no room in %s" % [cid, row["areas"]])
			continue
		(world[home] as RoomDef).spawns.append({"id": cid, "pos": spot, "by": MARK})
		loads[home] = float(loads[home]) + float(WEIGHT[cls])

## The plan's creatures, rares first and the ones with the fewest areas first, then by id.
func _order() -> Array:
	var ids: Array = (_plan["creatures"] as Dictionary).keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra: Dictionary = _plan["creatures"][a]
		var rb: Dictionary = _plan["creatures"][b]
		if ra["class"] != rb["class"]:
			return int(CLASS_RANK[ra["class"]]) < int(CLASS_RANK[rb["class"]])
		if ra["areas"].size() != rb["areas"].size():
			return ra["areas"].size() < rb["areas"].size()
		return a < b)
	return ids

## The rooms of the creature's areas, a rare's lairs first, then the emptiest per screen, then by id.
func _rooms_for(row: Dictionary, cls: String, by_area: Dictionary, lairs: Array, loads: Dictionary, world: Dictionary) -> Array:
	var ids: Array = []
	for a in row["areas"]:
		for id in by_area.get(a, []):
			if not ids.has(id):
				ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		if cls == "rare" and lairs.has(a) != lairs.has(b):
			return lairs.has(a)
		var la := float(loads[a]) / float((world[a] as RoomDef).size.x * (world[a] as RoomDef).size.y)
		var lb := float(loads[b]) / float((world[b] as RoomDef).size.x * (world[b] as RoomDef).size.y)
		if not is_equal_approx(la, lb):
			return la < lb
		return a < b)
	return ids

## The best spot in room `r` for creature `cid`, or null.
func _find_spot(r: RoomDef, cid: String, size: Vector2):
	if RoomLint.creature_kind(cid) == "flier":
		return _hover_spot(r, cid, size)
	var surfaces: Array = RoomLint.standable(r)
	surfaces.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if not is_equal_approx(a.position.y, b.position.y):
			return a.position.y > b.position.y
		return a.position.x < b.position.x)
	for surface: Rect2 in surfaces:
		if surface.size.x < size.x + 2.0 * EDGE:
			continue
		var best = null
		var best_gap := -1.0
		var x := surface.position.x + size.x / 2.0 + EDGE
		while x <= surface.end.x - size.x / 2.0 - EDGE:
			var pos := Vector2(x, AreaKit.stand(surface.position.y))
			if _headroom(r, pos.x, surface.position.y, size) and _doors_clear(r, pos.x, surface.position.y, size.x) and _fits(r, cid, pos):
				var gap := _gap_to_others(r, pos, size)
				if gap >= GAP and gap > best_gap:
					best = pos
					best_gap = gap
			x += STEP
		if best != null:
			return best
	return null

## A hovering creature: along the room at HOVER_Y, with the most clear air around it.
func _hover_spot(r: RoomDef, cid: String, size: Vector2):
	var best = null
	var best_gap := -1.0
	var x := RoomDef.WALL + RoomLint.CLEAR
	while x <= r.pixel_size().x - RoomDef.WALL - RoomLint.CLEAR:
		var pos := Vector2(x, HOVER_Y)
		if _fits(r, cid, pos):
			var gap := _gap_to_others(r, pos, size)
			if gap >= GAP and gap > best_gap:
				best = pos
				best_gap = gap
		x += STEP * 2.0
	return best

## Nothing overhead comes closer than it should: a solid block or the ceiling no closer than HEAD times the creature's height, a ledge it could
## jump through no closer than LEDGE_HEAD times (it may overlap one a little, as it does in the hand-made rooms).
func _headroom(r: RoomDef, x: float, top: float, size: Vector2) -> bool:
	for rect: Rect2 in RoomLint.rock(r):
		if rect.end.y < top - 0.5 and rect.position.x < x + size.x / 2.0 and rect.end.x > x - size.x / 2.0:
			var need := (LEDGE_HEAD if RoomBuilder.is_one_way(rect, r.hard_ledges) else HEAD) * size.y
			if top - rect.end.y < need:
				return false
	return true

## The doorways at a left or right edge stay clear: no creature on the doorway's level within the clear zone in front of it.
func _doors_clear(r: RoomDef, x: float, top: float, width: float) -> bool:
	var w := r.pixel_size().x
	for e: Dictionary in r.exits:
		var edge: String = e["edge"]
		if edge != "left" and edge != "right":
			continue
		if top < float(e["from"]) - 40.0 or top > float(e["to"]) + 60.0:
			continue
		var from_wall := x - RoomDef.WALL if edge == "left" else w - RoomDef.WALL - x
		if from_wall - width / 2.0 < RoomLint.CLEAR:
			return false
	return true

## Whether every spawn rule of RoomLint holds for a creature at `pos` in `r` (checked on a copy of the room with that one spawn).
func _fits(r: RoomDef, cid: String, pos: Vector2) -> bool:
	var probe := RoomDef.new()
	probe.id = r.id
	probe.area = r.area
	probe.cell = r.cell
	probe.size = r.size
	probe.solids = r.solids
	probe.hard_ledges = r.hard_ledges
	probe.exits = r.exits
	probe.features = r.features
	probe.water = r.water
	probe.spawns = [{"id": cid, "pos": pos}]
	return RoomLint.spawn_findings(probe).is_empty()

## The clear distance from a creature at `pos` to the nearest spawn of the room on its level (INF when none).
func _gap_to_others(r: RoomDef, pos: Vector2, size: Vector2) -> float:
	var gap := INF
	for s: Dictionary in r.spawns:
		var other: Vector2 = s["pos"]
		if absf(other.y - pos.y) >= LEVEL:
			continue
		var theirs := _width_of(str(s["id"]))
		gap = minf(gap, absf(other.x - pos.x) - (size.x + theirs) / 2.0)
	return gap

func _width_of(id: String) -> float:
	if _defs.has(id):
		return size_of(_defs[id]).x
	var ext := RoomLint.creature_extent(id)
	return ext.x if ext != Vector2.ZERO else FALLBACK_SIZE.x
