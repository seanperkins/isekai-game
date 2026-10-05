class_name WorldSize
extends RefCounted
## How big the world is next to Super Metroid and next to the room budget in docs/research/area-level-design.md section 17.
## Pure functions over a Dictionary of id to RoomDef. The World view in the room editor and tools/world_size.sh both read it.
## Informational only: nothing tests the world against these numbers and nothing is gated on them.
## Super Metroid's figures are counted from the room data of vg-json-data/sm-json-data (Zebes only, Ceres left out): 255 rooms, 1,274 map tiles.

const SM_ROOMS := 255
const SM_SCREENS := 1274
const SM_SCREENS_PER_ROOM := 5.0
## An estimate, not a measurement: a Super Metroid screen against ours, scaled by body size (a 16 by 32 pixel Samus, a 28 by 28 slime).
const BODY_SCALED_SCREENS := 560

## Suggested rooms per area (sums to 256), in the order the areas are planned. An area with no rooms yet still shows, at 0.
const TARGETS := {
	"cave": 18, "grotto": 20, "flooded": 20, "deep": 26, "forest": 24, "swamp": 20, "village": 18,
	"sacred": 40, "volcano": 26, "demon": 26, "last": 16, "serpent": 2,
}

## {rooms, screens, avg, median, largest, single, bounds (in screens), per_area: {area: {rooms, screens}}}
static func measure(rooms: Dictionary) -> Dictionary:
	var screens := 0
	var sizes: Array = []
	var per_area := {}
	var extent := Rect2()
	var first := true
	for id in rooms:
		var def: RoomDef = rooms[id]
		var n := def.size.x * def.size.y
		screens += n
		sizes.append(n)
		var a: Dictionary = per_area.get(def.area, {"rooms": 0, "screens": 0})
		per_area[def.area] = {"rooms": a["rooms"] + 1, "screens": a["screens"] + n}
		extent = def.world_rect() if first else extent.merge(def.world_rect())
		first = false
	sizes.sort()
	var count := sizes.size()
	return {
		"rooms": count, "screens": screens,
		"avg": float(screens) / float(maxi(1, count)),
		"median": sizes[count >> 1] if count > 0 else 0,
		"largest": sizes[count - 1] if count > 0 else 0,
		"single": sizes.count(1),
		"bounds": (extent.size / RoomDef.SCREEN).floor(),
		"per_area": per_area,
	}

## The three ways to read "as big as Super Metroid": [{label, now, target, frac}], frac may pass 1.
static func yardsticks(m: Dictionary) -> Array:
	return [
		_yardstick("rooms", m["rooms"], SM_ROOMS),
		_yardstick("screens, body-scaled", m["screens"], BODY_SCALED_SCREENS),
		_yardstick("screens, strict", m["screens"], SM_SCREENS),
	]

## One row per budgeted area in TARGETS order, then any other area the rooms use: [{area, rooms, target, screens, frac}].
static func area_rows(m: Dictionary) -> Array:
	var per_area: Dictionary = m["per_area"]
	var out: Array = []
	for area in TARGETS:
		var a: Dictionary = per_area.get(area, {"rooms": 0, "screens": 0})
		out.append(_area_row(area, a["rooms"], TARGETS[area], a["screens"]))
	for area in per_area:
		if not TARGETS.has(area):
			var a: Dictionary = per_area[area]
			out.append(_area_row(area, a["rooms"], a["rooms"], a["screens"]))
	return out

static func target_total() -> int:
	var total := 0
	for area in TARGETS:
		total += TARGETS[area]
	return total

static func _yardstick(label: String, now: int, target: int) -> Dictionary:
	return {"label": label, "now": now, "target": target, "frac": float(now) / float(maxi(1, target))}

static func _area_row(area: String, rooms: int, target: int, screens: int) -> Dictionary:
	return {"area": area, "rooms": rooms, "target": target, "screens": screens, "frac": float(rooms) / float(maxi(1, target))}
