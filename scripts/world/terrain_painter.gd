class_name TerrainPainter
extends RefCounted
## Draws a room's solids with the biome's terrain art. Collision is untouched: RoomBuilder still
## makes one StaticBody2D per rect, and this only adds sprites over the same rects.
##
## - A thick rect (a floor, wall, pillar or ceiling) gets stone fill sampled in room coordinates, so
##   neighbouring rects share one texture, plus an edge strip on every side that is open air: a lip
##   on top, a jagged underside, ragged side faces.
## - A thin rect (a ledge) gets a left cap, a repeating middle and a right cap.
## - A side on the room's boundary, or covered by another solid, gets no edge.

const THIN := 24.0        # rects up to this thick are ledges
const MIN_FACE := 24.0    # narrower rects (pillars) skip side faces
const TALL_FACE := 64.0   # side faces at least this tall get the ragged stone strip; shorter ones a clean line
const OUTLINE := Color(44.0 / 255.0, 22.0 / 255.0, 68.0 / 255.0)  # same plum terrain_build.py bakes into the edges

## `solids` is [{"rect": Rect2, "kind": String, optional "hard": bool}] in room-local pixels; `bounds` is the room rect.
## A "hard" ledge is thin but solid from below: it is drawn with a rock underside.
## `only` limits which rects are drawn (a gate paints itself); `solids` still decide what is open air.
static func paint(parent: Node, solids: Array, bounds: Rect2, biome: String, only: Array = []) -> Node2D:
	var root := Node2D.new()
	root.name = "Terrain"
	var rects: Array = []
	var hard: Array = []
	for s in solids:
		rects.append(s["rect"])
		if s.get("hard", false):
			hard.append(s["rect"])
	for r: Rect2 in (only if not only.is_empty() else rects):
		if r.size.y <= THIN and r.size.x > THIN and _inside(r, bounds):
			_ledge(root, r, biome)
			if hard.has(r):
				_underside(root, r, biome)
		else:
			_mass(root, r, rects, bounds, biome)
	parent.add_child(root)
	return root

static func _inside(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x > bounds.position.x + 0.5 and r.end.x < bounds.end.x - 0.5 \
		and r.position.y > bounds.position.y + 0.5 and r.end.y < bounds.end.y - 0.5

static func _mass(root: Node2D, r: Rect2, all: Array, bounds: Rect2, biome: String) -> void:
	var fill := TerrainArt.tile(biome, "fill_a")
	root.add_child(_region(fill, r.position, r.size, r.position))
	var top := TerrainArt.tile(biome, "cap_top")
	if top != null:
		var surface: int = TerrainArt.meta(biome, "cap_top").get("surface", 0)
		for span in _open(r, "top", all, bounds):
			root.add_child(_region(top, Vector2(span.x, r.position.y - surface), Vector2(span.y - span.x, top.get_height()),
				Vector2(span.x, 0)))
	var under := TerrainArt.tile(biome, "cap_bottom")
	if under != null:
		var surface_b: int = TerrainArt.meta(biome, "cap_bottom").get("surface", 0)
		for span in _open(r, "bottom", all, bounds):
			root.add_child(_region(under, Vector2(span.x, r.end.y - surface_b), Vector2(span.y - span.x, under.get_height()),
				Vector2(span.x, 0)))
	var face := TerrainArt.tile(biome, "edge_left")
	if face != null and r.size.x >= MIN_FACE:
		var surface_s: int = TerrainArt.meta(biome, "edge_left").get("surface", 0)
		for span in _open(r, "left", all, bounds):
			if span.y - span.x < TALL_FACE:
				root.add_child(_line(Vector2(r.position.x, span.x), Vector2(1.0, span.y - span.x)))
				continue
			root.add_child(_region(face, Vector2(r.position.x - surface_s, span.x), Vector2(face.get_width(), span.y - span.x),
				Vector2(0, span.x)))
		for span in _open(r, "right", all, bounds):
			if span.y - span.x < TALL_FACE:
				root.add_child(_line(Vector2(r.end.x - 1.0, span.x), Vector2(1.0, span.y - span.x)))
				continue
			var s := _region(face, Vector2(r.end.x - (face.get_width() - surface_s), span.x), Vector2(face.get_width(), span.y - span.x),
				Vector2(0, span.x))
			s.flip_h = true
			root.add_child(s)

## A 1 px outline segment in the terrain's plum, for short faces where the ragged strip would clutter.
static func _line(pos: Vector2, size: Vector2) -> ColorRect:
	var c := ColorRect.new()
	c.name = "Outline"
	c.color = OUTLINE
	c.position = pos
	c.size = size
	return c

static func _ledge(root: Node2D, r: Rect2, biome: String) -> void:
	var left := TerrainArt.tile(biome, "ledge_l")
	var mid := TerrainArt.tile(biome, "ledge_m")
	var right := TerrainArt.tile(biome, "ledge_r")
	if left == null or mid == null or right == null:
		root.add_child(_region(TerrainArt.tile(biome, "fill_a"), r.position, r.size, r.position))
		return
	var surface: int = TerrainArt.meta(biome, "ledge").get("surface", 0)
	var y := r.position.y - surface
	var cap := float(left.get_width())
	var inner := maxf(0.0, r.size.x - cap * 2.0)
	if inner > 0.0:
		root.add_child(_region(mid, Vector2(r.position.x + cap, y), Vector2(inner, mid.get_height()), Vector2.ZERO))
	root.add_child(_region(left, Vector2(r.position.x, y), Vector2(cap, left.get_height()), Vector2.ZERO))
	root.add_child(_region(right, Vector2(r.end.x - cap, y), Vector2(cap, right.get_height()), Vector2.ZERO))

## Rock hanging under a hard ledge: the same jagged underside a mass has, so it reads as solid from below.
static func _underside(root: Node2D, r: Rect2, biome: String) -> void:
	var under := TerrainArt.tile(biome, "cap_bottom")
	if under == null:
		return
	var surface: int = TerrainArt.meta(biome, "cap_bottom").get("surface", 0)
	root.add_child(_region(under, Vector2(r.position.x, r.end.y - surface), Vector2(r.size.x, under.get_height()), Vector2(r.position.x, 0)))

## A Sprite2D that shows `size` px of `tex` starting at `from` in the texture, repeating as needed.
static func _region(tex: Texture2D, pos: Vector2, size: Vector2, from: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.region_enabled = true
	s.region_rect = Rect2(Vector2(fposmod(from.x, tex.get_width()), fposmod(from.y, tex.get_height())), size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return s

## The stretches of one side of `r` that face open air, as Vector2(from, to) along that side.
## The room's own boundary and any side covered by another solid are not open.
static func _open(r: Rect2, side: String, all: Array, bounds: Rect2) -> Array:
	var horizontal := side == "top" or side == "bottom"
	var lo := r.position.x if horizontal else r.position.y
	var hi := r.end.x if horizontal else r.end.y
	match side:
		"top":
			if r.position.y <= bounds.position.y + 0.5: return []
		"bottom":
			if r.end.y >= bounds.end.y - 0.5: return []
		"left":
			if r.position.x <= bounds.position.x + 0.5: return []
		"right":
			if r.end.x >= bounds.end.x - 0.5: return []
	var probe := _probe(r, side)
	var spans: Array = [Vector2(lo, hi)]
	for o: Rect2 in all:
		if o == r or not o.intersects(probe):
			continue
		var a := o.position.x if horizontal else o.position.y
		var b := o.end.x if horizontal else o.end.y
		var next: Array = []
		for s: Vector2 in spans:
			if b <= s.x or a >= s.y:
				next.append(s)
				continue
			if a > s.x:
				next.append(Vector2(s.x, a))
			if b < s.y:
				next.append(Vector2(b, s.y))
		spans = next
	return spans.filter(func(s: Vector2) -> bool: return s.y - s.x >= 4.0)

## A 1 px strip just outside one side of `r`, used to find what covers it.
static func _probe(r: Rect2, side: String) -> Rect2:
	match side:
		"top": return Rect2(r.position.x, r.position.y - 1.0, r.size.x, 1.0)
		"bottom": return Rect2(r.position.x, r.end.y, r.size.x, 1.0)
		"left": return Rect2(r.position.x - 1.0, r.position.y, 1.0, r.size.y)
	return Rect2(r.end.x, r.position.y, 1.0, r.size.y)
