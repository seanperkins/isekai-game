class_name Prefabs
extends RefCounted
## Reusable room pieces, stamped into a room dict by tools/build_world.gd. A stamp expands to plain
## `solids` and `decor` entries, so the game reads the same data as before and never sees a prefab.
##
## Coordinates inside a prefab are relative to its anchor. A floor prefab stands on the anchor
## (y grows up, so solids use negative y) and `width` is its extent to the right. A ceiling prefab
## hangs from the anchor (y grows down). `flip` mirrors it in x.
##
## Rules for authors: keep every step at most 54 px (the slime's ledge limit), never place a prefab
## in front of an exit (tests/test_prefabs.gd keeps 64 px clear there), and keep gaps between
## floating solids at least 36 px so the 28 px body fits.

const GLOW := Color(0.35, 0.95, 0.7)
const TEAL := Color(0.3, 1.0, 0.9)
const PURPLE := Color(0.8, 0.4, 1.0)
const BLUE := Color(0.3, 0.5, 1.0)
const ROSE := Color(1.0, 0.55, 0.75)
const GOLD := Color(1.0, 0.85, 0.4)
const PRISM := Color(0.95, 0.85, 1.0)

## Which prefabs give each biome its own silhouette. The shared ones (mound, outcrop, stalactites,
## scatter) appear everywhere; the rest are the biome's signature shapes.
const SETS := {
	"cave": ["mound", "arch", "pillars", "outcrop", "stalactites", "scatter"],
	"grotto": ["cap_stairs", "hummock", "mound", "stalactites", "scatter"],
	"flooded": ["sunken_steps", "colonnade", "outcrop", "stalactites", "scatter"],
}

static func ids_for(biome: String) -> Array:
	return SETS.get(biome, SETS["cave"])

## id -> {"width": px, "ceiling": bool, "walkable": bool, "solids": [Rect2], "decor": [{id, pos, ...}]}
## `walkable` prefabs are meant to be climbed, so every step stays within the slime's ledge limit.
static func library() -> Dictionary:
	return {
		# GROTTO: shelf mushrooms climbing like a spiral stair, 48 px per shelf (36 px of headroom under each).
		"cap_stairs": {"width": 220, "walkable": true, "solids": [Rect2(0, -48, 84, 12), Rect2(70, -96, 84, 12), Rect2(136, -144, 84, 12)],
			"decor": [{"id": "glow_fungus", "pos": Vector2(20, -48), "light": GLOW}, {"id": "flowers", "pos": Vector2(170, -96)},
				{"id": "glow_fungus", "pos": Vector2(190, -144), "light": GLOW}]},
		# GROTTO: a broad, soft hummock of earth with mushrooms on its shoulders, one 32 px rise.
		"hummock": {"width": 200, "walkable": true, "solids": [Rect2(0, -32, 200, 32), Rect2(50, -64, 100, 32)],
			"decor": [{"id": "glow_fungus", "pos": Vector2(60, -64), "light": GLOW}, {"id": "glow_fungus", "pos": Vector2(140, -64), "light": GLOW},
				{"id": "flowers", "pos": Vector2(20, -32)}]},
		# FLOODED: long, low, water-worn steps: three 24 px risings.
		"sunken_steps": {"width": 240, "walkable": true, "solids": [Rect2(0, -24, 240, 24), Rect2(40, -48, 160, 24), Rect2(90, -72, 60, 24)],
			"decor": [{"id": "puddle_glow", "pos": Vector2(24, -24), "light": TEAL}, {"id": "rubble", "pos": Vector2(210, -24)}]},
		# FLOODED: a row of stone pillars with 64 px gaps to walk between (not a route: they stand 72 high).
		"colonnade": {"width": 224, "solids": [Rect2(0, -72, 32, 72), Rect2(96, -72, 32, 72), Rect2(192, -72, 32, 72)],
			"decor": [{"id": "root_hang", "pos": Vector2(112, -72), "anchor": "top"}, {"id": "glow_fungus", "pos": Vector2(64, 0), "light": TEAL},
				{"id": "flowers", "pos": Vector2(160, 0)}]},
		# A stepped mass of rock the slime hops up, 32 px per step.
		"mound": {"width": 160, "walkable": true, "solids": [Rect2(0, -32, 160, 32), Rect2(24, -64, 112, 32), Rect2(56, -96, 48, 32)],
			"decor": [{"id": "glow_fungus", "pos": Vector2(20, -32), "light": GLOW},
				{"id": "rubble", "pos": Vector2(140, -32)}]},
		# Two legs and a lintel: walk under, the top is a vista rather than a route.
		"arch": {"width": 160, "solids": [Rect2(0, -96, 32, 96), Rect2(128, -96, 32, 96), Rect2(0, -128, 160, 32)],
			"decor": [{"id": "root_hang", "pos": Vector2(80, -96), "anchor": "top"},
				{"id": "glow_fungus", "pos": Vector2(80, 0), "light": GLOW}]},
		# Two uneven stone pillars with a glowing crystal between them.
		"pillars": {"width": 128, "solids": [Rect2(0, -140, 32, 140), Rect2(96, -100, 32, 100)],
			"decor": [{"id": "crystal_prism", "pos": Vector2(64, 0), "light": PRISM},
				{"id": "stalagmite", "pos": Vector2(20, 0)}]},
		# A crystal-studded outcrop, half a body high.
		"outcrop": {"width": 96, "walkable": true, "solids": [Rect2(0, -48, 96, 48)],
			"decor": [{"id": "wall_crystal", "pos": Vector2(48, -48), "light": PRISM},
				{"id": "crystal_gold", "pos": Vector2(84, -48), "light": GOLD}]},
		# Stalactite mass hanging from the ceiling, widest at the top.
		"stalactites": {"width": 120, "ceiling": true, "solids": [Rect2(0, 0, 120, 32), Rect2(24, 32, 72, 32), Rect2(48, 64, 24, 32)],
			"decor": [{"id": "lichen_hang", "pos": Vector2(100, 32), "anchor": "top", "light": GLOW}]},
		# Mossy rocks, flowers and a glowing spring: decor only.
		"scatter": {"width": 120, "solids": [],
			"decor": [{"id": "rubble", "pos": Vector2(10, 0)}, {"id": "flowers", "pos": Vector2(60, 0)},
				{"id": "puddle_glow", "pos": Vector2(96, 0), "light": TEAL}]},
	}

## The decor sprite for `id` in `biome`. The Cave uses the plain ids; every other biome ships the same
## set under a prefix (grotto_glow_fungus, flooded_glow_fungus, ...) so one prefab dresses any biome.
static func decor_id(id: String, biome: String) -> String:
	return id if biome == "cave" else "%s_%s" % [biome, id]

## Appends prefab `id` to `room` (a dict with optional "solids" and "decor" arrays), anchored at
## `origin` in room-local pixels. Returns the prefab's bounding Rect2 in room coordinates.
## `biome` picks the decor art (see decor_id).
static func stamp(room: Dictionary, id: String, origin: Vector2, flip := false, biome := "cave") -> Rect2:
	var p: Dictionary = library()[id]
	var width: float = p["width"]
	var solids: Array = room.get("solids", [])
	var decor: Array = room.get("decor", [])
	var bounds := Rect2(origin, Vector2.ZERO)
	for r: Rect2 in p["solids"]:
		var placed := _place(r, origin, width, flip)
		solids.append(placed)
		bounds = placed if bounds.size == Vector2.ZERO else bounds.merge(placed)
	for d: Dictionary in p["decor"]:
		var copy := d.duplicate()
		copy["id"] = decor_id(d["id"], biome)
		var x: float = d["pos"].x
		copy["pos"] = origin + Vector2(width - x if flip else x, d["pos"].y)
		decor.append(copy)
	room["solids"] = solids
	room["decor"] = decor
	return bounds

static func _place(r: Rect2, origin: Vector2, width: float, flip: bool) -> Rect2:
	var x := width - r.end.x if flip else r.position.x
	return Rect2(origin + Vector2(x, r.position.y), r.size)

## A climb of alternating ledges under a floor hole: `width` wide, alternately at `west_x` and `west_x + offset`,
## `step` apart from `top_y` down to just above `floor_y`. The top ledge sits flush with the hole's west edge.
## Plain solids, so the game never sees a prefab (this is not in library(): it is a placement helper).
static func ledge_chain(room: Dictionary, west_x: float, width: float, offset: float, top_y: float, step: float, floor_y: float) -> void:
	var solids: Array = room.get("solids", [])
	var i := 0
	while top_y + step * i < floor_y - 8.0:
		solids.append(Rect2(west_x if i % 2 == 0 else west_x + offset, top_y + step * i, width, 12))
		i += 1
	room["solids"] = solids

## A climb UP from `floor_y` to `walk_y` in a shaft `x0`..`x1` wide: ledges `step` apart, alternating between the
## shaft's two sides (`width` wide each). The top ledge sits `step` below `walk_y`.
static func shaft_climb(room: Dictionary, x0: float, x1: float, width: float, walk_y: float, step: float, floor_y: float) -> void:
	var solids: Array = room.get("solids", [])
	var k := 1
	while walk_y + step * k < floor_y - 8.0:
		solids.append(Rect2(x0 if k % 2 == 1 else x1 - width, walk_y + step * k, width, 12))
		k += 1
	room["solids"] = solids

