class_name RoomPreview
extends RefCounted
## Schematic pictures and text maps of a room or the world for the room MCP. The headless renderer has no texture to read back, so the
## pictures are drawn on the CPU into an Image: no game art and no letters (a CPU image has no font). What the picture cannot say is in
## the legend and the text map.

const MAX_SIDE := 2000
const MIN_SCALE := 0.25

# 8-bit colours, so a pixel read back equals the constant exactly.
const C_AIR := Color8(23, 26, 36)
const C_GRID := Color8(33, 37, 50)
const C_SOLID := Color8(115, 102, 128)
const C_HARD := Color8(242, 204, 77)
const C_WATER := Color8(51, 128, 217)
const C_SPAWN := Color8(242, 64, 64)
const C_FEATURE := Color8(255, 209, 64)
const C_DECOR := Color8(77, 191, 102)
const C_START := Color8(255, 255, 255)
const C_EXIT := Color8(64, 217, 217)
const C_GATE_CLING := Color8(179, 102, 230)
const C_GATE_SWIM := Color8(110, 170, 255)
const C_SHORTCUT := Color8(255, 140, 40)
const C_DIRTY := Color8(255, 235, 60)
const C_ROOM_EDGE := Color8(10, 12, 18)

const CELL := 40.0       # a text-map cell, px
const WIDE_CELL := 80.0  # used when the room is wider than three screens
const MIN_OVERLAP := 8.0 # a thing shows in a text cell when it covers at least this much of it each way

## The scale actually used: `scale` raised to MIN_SCALE and lowered so the longest side stays within MAX_SIDE.
static func clamp_scale(r: RoomDef, scale: float) -> float:
	var longest := maxf(r.pixel_size().x, r.pixel_size().y)
	return minf(maxf(scale, MIN_SCALE), float(MAX_SIDE) / longest)

static func image(r: RoomDef, scale: float) -> Image:
	var s := clamp_scale(r, scale)
	var size := r.pixel_size()
	# The scale was lowered to land exactly on MAX_SIDE for the longest side; float noise must not round that up to MAX_SIDE + 1.
	var img := Image.create_empty(mini(ceili(size.x * s - 0.001), MAX_SIDE), mini(ceili(size.y * s - 0.001), MAX_SIDE), false, Image.FORMAT_RGBA8)
	img.fill(C_AIR)
	for x in range(1, r.size.x):
		_fill(img, Rect2(x * RoomDef.SCREEN.x, 0, 1.0 / s, size.y), s, C_GRID)
	for y in range(1, r.size.y):
		_fill(img, Rect2(0, y * RoomDef.SCREEN.y, size.x, 1.0 / s), s, C_GRID)
	for rect: Rect2 in _rock(r):
		_fill(img, rect, s, C_SOLID)
	for e: Dictionary in r.exits:
		_fill(img, RoomBuilder.gate_rect(size, e), s, _exit_colour(e))
	for w: Rect2 in r.water:
		_fill(img, w, s, C_WATER)
	for h: Rect2 in r.hard_ledges:
		_outline(img, h, s, C_HARD)
	for d: Dictionary in r.decor:
		_mark(img, d["pos"], s, 3, C_DECOR)
	for f: Dictionary in r.features:
		_mark(img, f["pos"] - Vector2(0, 4), s, 5, C_FEATURE)
	for sp: Dictionary in r.spawns:
		_mark(img, sp["pos"], s, 5, C_SPAWN)
	if r.is_start():
		var c := Vector2i(r.start * s)
		img.fill_rect(Rect2i(c.x - 4, c.y, 9, 1), C_START)
		img.fill_rect(Rect2i(c.x, c.y - 4, 1, 9), C_START)
	return img

## One character per cell, a ruler row first and a two-digit row number before each row: '#' rock, '~' water, 'S' spawn, 'F' feature,
## 'd' decor, '=' exit gap, '.' open. Where several share a cell the first of S F = ~ # d wins. Cells are 40 px, or 80 when the room
## is wider than three screens.
static func text_map(r: RoomDef) -> String:
	var cell := WIDE_CELL if r.size.x > 3 else CELL
	var size := r.pixel_size()
	var cols := ceili(size.x / cell)
	var rows := ceili(size.y / cell)
	var rock := _rock(r)
	var gaps: Array = r.exits.map(func(e: Dictionary) -> Rect2: return RoomBuilder.gate_rect(size, e))
	var lines: Array = ["   " + "".join(range(cols).map(func(c: int) -> String: return str(c % 10)))]
	for row in rows:
		var line := "%2d " % row
		for col in cols:
			var box := Rect2(col * cell, row * cell, cell, cell)
			line += _cell_char(r, box, rock, gaps)
		lines.append(line)
	return "\n".join(lines)

static func _cell_char(r: RoomDef, box: Rect2, rock: Array, gaps: Array) -> String:
	for sp: Dictionary in r.spawns:
		if box.has_point(sp["pos"]):
			return "S"
	for f: Dictionary in r.features:
		if box.has_point(f["pos"] - Vector2(0, 1)):
			return "F"
	if _covers(box, gaps):
		return "="
	for w: Rect2 in r.water:
		if w.has_point(box.get_center()):
			return "~"
	if _covers(box, rock):
		return "#"
	for d: Dictionary in r.decor:
		var hangs: bool = str(d.get("anchor", "bottom")) == "top"
		if box.has_point(d["pos"] + Vector2(0, 1 if hangs else -1)):
			return "d"
	return "."

## What the picture cannot label: each spawn, feature and exit with its index, position and name, and the colour key.
static func legend(r: RoomDef) -> String:
	var spawns: Array = []
	for i in r.spawns.size():
		spawns.append("[%d] %s @ %s" % [i, r.spawns[i]["id"], _at(r.spawns[i]["pos"])])
	var features: Array = []
	for i in r.features.size():
		features.append("[%d] %s %s @ %s" % [i, r.features[i]["kind"], r.features[i].get("id", ""), _at(r.features[i]["pos"])])
	var exits: Array = []
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		var extra := ""
		if e.has("gate"):
			extra += " gate " + str(e["gate"])
		if e.has("shortcut"):
			extra += " shortcut " + str(e["shortcut"])
		exits.append("[%d] %s %s-%s -> %s%s" % [i, e["edge"], _n(float(e["from"])), _n(float(e["to"])), e["room"], extra])
	return "\n".join([
		"spawns: " + ("; ".join(spawns) if not spawns.is_empty() else "none"),
		"features: " + ("; ".join(features) if not features.is_empty() else "none"),
		"exits: " + ("; ".join(exits) if not exits.is_empty() else "none"),
		"picture: rock grey, hard ledge outlined gold, water blue, spawn red square, feature gold square, decor green dot, exit gap cyan "
			+ "(violet wall_cling, light blue swim, orange shortcut), start white cross, screen borders faint lines",
	])

## Every room as its world rectangle, filled by area colour (WorldView.AREA_FILL), rooms with unsaved edits outlined in C_DIRTY.
static func world_image(rooms: Dictionary, dirty: Dictionary, width: int) -> Image:
	if rooms.is_empty():
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var bounds := Rect2()
	var first := true
	for id in rooms:
		var w: Rect2 = (rooms[id] as RoomDef).world_rect()
		bounds = w if first else bounds.merge(w)
		first = false
	var height := clampi(ceili(width * bounds.size.y / bounds.size.x), 1, 4000)
	var img := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	img.fill(C_AIR)
	for item: Dictionary in WorldView.layout(rooms, Rect2(0, 0, width, height)):
		var rect: Rect2 = item["rect"]
		var def: RoomDef = rooms[item["id"]]
		_fill(img, rect, 1.0, WorldView.AREA_FILL.get(def.area, WorldView.FILL_UNKNOWN))
		_outline(img, rect, 1.0, C_ROOM_EDGE)
		if dirty.has(item["id"]):
			_outline(img, rect, 1.0, C_DIRTY)
			_outline(img, rect.grow(-1), 1.0, C_DIRTY)
	return img

## One entry per screen of the world, row by row, showing the id of the room that covers it ("." where none does).
static func world_grid(rooms: Dictionary) -> String:
	var at := {}
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	var longest := 1
	for id: String in rooms:
		var def: RoomDef = rooms[id]
		longest = maxi(longest, id.length())
		for y in def.size.y:
			for x in def.size.x:
				at[Vector2i(def.cell.x + x, def.cell.y + y)] = id
		lo = Vector2i(mini(lo.x, def.cell.x), mini(lo.y, def.cell.y))
		hi = Vector2i(maxi(hi.x, def.cell.x + def.size.x), maxi(hi.y, def.cell.y + def.size.y))
	var lines: Array = []
	for y in range(lo.y, hi.y):
		var line := ""
		for x in range(lo.x, hi.x):
			line += str(at.get(Vector2i(x, y), ".")).rpad(longest + 1)
		lines.append(line.rstrip(" "))
	return "\n".join(lines)

# --- drawing helpers ---

static func _rock(r: RoomDef) -> Array:
	var out: Array = r.solids.duplicate()
	for w: Dictionary in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		out.append(w["rect"])
	return out

static func _exit_colour(e: Dictionary) -> Color:
	if e.has("shortcut"):
		return C_SHORTCUT
	match str(e.get("gate", "")):
		"wall_cling":
			return C_GATE_CLING
		"swim":
			return C_GATE_SWIM
	return C_EXIT

## `rect` (room px) filled in output pixels at scale `s`, at least one pixel each way.
static func _fill(img: Image, rect: Rect2, s: float, color: Color) -> void:
	var x0 := floori(rect.position.x * s)
	var y0 := floori(rect.position.y * s)
	img.fill_rect(Rect2i(x0, y0, maxi(ceili(rect.end.x * s) - x0, 1), maxi(ceili(rect.end.y * s) - y0, 1)), color)

static func _outline(img: Image, rect: Rect2, s: float, color: Color) -> void:
	var x0 := floori(rect.position.x * s)
	var y0 := floori(rect.position.y * s)
	var w := maxi(ceili(rect.end.x * s) - x0, 1)
	var h := maxi(ceili(rect.end.y * s) - y0, 1)
	img.fill_rect(Rect2i(x0, y0, w, 1), color)
	img.fill_rect(Rect2i(x0, y0 + h - 1, w, 1), color)
	img.fill_rect(Rect2i(x0, y0, 1, h), color)
	img.fill_rect(Rect2i(x0 + w - 1, y0, 1, h), color)

## A square `side` output pixels wide centred on room position `at`.
static func _mark(img: Image, at: Vector2, s: float, side: int, color: Color) -> void:
	var c := Vector2i(at * s)
	img.fill_rect(Rect2i(c.x - side / 2, c.y - side / 2, side, side), color)

static func _covers(box: Rect2, rects: Array) -> bool:
	for rect: Rect2 in rects:
		var hit := box.intersection(rect)
		if hit.size.x >= MIN_OVERLAP and hit.size.y >= MIN_OVERLAP:
			return true
	return false

static func _n(v: float) -> String:
	return String.num(v, 1).trim_suffix(".0")

static func _at(p: Vector2) -> String:
	return "%s,%s" % [_n(p.x), _n(p.y)]
