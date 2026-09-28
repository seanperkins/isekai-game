extends SceneTree
## Generates res://data/rooms/*.tres. This file is the source of truth for room geometry;
## edit here, then re-run:
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_world.gd
## Positions are local to each room. Floors, ceilings and side walls are generated from each
## room's size and exits (RoomBuilder.edge_walls): floor top = height - 40, walls 20 thick.

const TEAL := Color(0.3, 1.0, 0.9)
const PURPLE := Color(0.8, 0.4, 1.0)
const BLUE := Color(0.3, 0.5, 1.0)
const FIRE := Color(1.0, 0.6, 0.25)

func _init() -> void:
	var failures := 0
	for r in rooms():
		failures += _save(r)
	quit(1 if failures > 0 else 0)

func _save(r: RoomDef) -> int:
	var path := "res://data/rooms/%s.tres" % r.id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(r, path)
	if err != OK:
		printerr("failed to save %s: %s" % [path, error_string(err)])
		return 1
	print("wrote ", path)
	return 0

static func _room(f: Dictionary) -> RoomDef:
	var r := RoomDef.new()
	for k in f:
		r.set(k, f[k])
	return r

static func _exit(edge: String, from: float, to: float, room: String, extra: Dictionary = {}) -> Dictionary:
	var e := {"edge": edge, "from": from, "to": to, "room": room}
	e.merge(extra)
	return e

static func _lit(id: String, pos: Vector2, color: Color) -> Dictionary:
	return {"id": id, "pos": pos, "light": color}

static func _hang(id: String, pos: Vector2) -> Dictionary:
	return {"id": id, "pos": pos, "anchor": "top"}

static func _s(id: String, pos: Vector2) -> Dictionary:
	return {"id": id, "pos": pos}

static func rooms() -> Array:
	return [c1(), c2(), c3(), c4(), c5(), c6()]

## C1 Start (2×1): the original lower hall. Floor top 320.
static func c1() -> RoomDef:
	return _room({"id": "C1", "area": "cave", "cell": Vector2i(0, 2), "size": Vector2i(2, 1),
		"start": Vector2(60, 310),
		"exits": [_exit("right", 200, 320, "C2"), _exit("top", 840, 900, "C6", {"shortcut": "c6_drop"})],
		"solids": [Rect2(260, 266, 120, 12), Rect2(420, 214, 100, 12), Rect2(760, 140, 16, 180),
			Rect2(900, 266, 140, 12), Rect2(1060, 214, 100, 12)],
		"decor": [_lit("crystal_teal", Vector2(110, 320), TEAL), _lit("crystal_purple", Vector2(610, 320), PURPLE),
			_lit("crystal_blue", Vector2(1010, 320), BLUE), _lit("crystal_purple", Vector2(470, 214), PURPLE),
			_lit("torch", Vector2(330, 236), FIRE), _hang("vine", Vector2(300, 278)), _hang("vine", Vector2(980, 278)),
			_hang("stalactite", Vector2(470, 226)), _hang("stalactite", Vector2(1110, 226))],
		"spawns": [_s("bat", Vector2(300, 200)), _s("bat", Vector2(470, 170)), _s("bat", Vector2(980, 180)),
			_s("toad", Vector2(200, 300)), _s("toad", Vector2(420, 300)), _s("toad", Vector2(680, 300)),
			_s("toad", Vector2(1100, 300)), _s("lizard", Vector2(860, 300)), _s("water_pool", Vector2(150, 316))]})

## C2 Thread Gap (2×1): spiders under the ceiling; a chimney up to C3 needs Wall Cling.
static func c2() -> RoomDef:
	return _room({"id": "C2", "area": "cave", "cell": Vector2i(2, 2), "size": Vector2i(2, 1),
		"exits": [_exit("left", 200, 320, "C1"), _exit("right", 200, 320, "C4"),
			_exit("top", 300, 380, "C3", {"gate": "wall_cling"})],
		"solids": [Rect2(280, 20, 16, 220), Rect2(384, 20, 16, 220),
			Rect2(160, 266, 90, 12), Rect2(40, 214, 90, 12),
			Rect2(560, 266, 120, 12), Rect2(740, 214, 120, 12), Rect2(920, 266, 120, 12)],
		"decor": [_lit("torch", Vector2(800, 184), FIRE), _lit("crystal_teal", Vector2(500, 320), TEAL),
			_lit("crystal_blue", Vector2(1200, 320), BLUE), _hang("vine", Vector2(620, 20)),
			_hang("stalactite", Vector2(1150, 20))],
		"spawns": [_s("spider", Vector2(700, 32)), _s("spider", Vector2(1000, 32)),
			_s("lizard", Vector2(600, 300)), _s("lizard", Vector2(1100, 300))]})

## C3 Spider Loft (1×2): a climb of ledges; entered from C2's chimney below.
static func c3() -> RoomDef:
	return _room({"id": "C3", "area": "cave", "cell": Vector2i(2, 0), "size": Vector2i(1, 2),
		"exits": [_exit("bottom", 300, 380, "C2", {"gate": "wall_cling"}), _exit("left", 560, 680, "C6")],
		"solids": [Rect2(60, 626, 100, 12), Rect2(200, 574, 100, 12), Rect2(60, 522, 100, 12),
			Rect2(200, 470, 100, 12), Rect2(340, 418, 120, 12), Rect2(500, 366, 100, 12),
			Rect2(340, 314, 100, 12), Rect2(180, 262, 100, 12), Rect2(40, 210, 120, 12)],
		"decor": [_lit("crystal_teal", Vector2(100, 210), TEAL), _lit("torch", Vector2(390, 388), FIRE),
			_hang("vine", Vector2(560, 20)), _hang("vine", Vector2(120, 20))],
		"spawns": [_s("spider", Vector2(240, 32)), _s("spider", Vector2(520, 32)), _s("bat", Vector2(450, 300))]})

## C4 Glow Pool (1×1): rest here.
static func c4() -> RoomDef:
	return _room({"id": "C4", "area": "cave", "cell": Vector2i(4, 2), "size": Vector2i(1, 1),
		"exits": [_exit("left", 200, 320, "C2"), _exit("right", 200, 320, "C5")],
		"solids": [Rect2(100, 266, 100, 12), Rect2(440, 266, 100, 12)],
		"features": [{"kind": "glow_pool", "id": "c4_pool", "pos": Vector2(320, 320)}],
		"decor": [_lit("torch", Vector2(150, 236), FIRE), _lit("crystal_teal", Vector2(470, 266), TEAL),
			_lit("crystal_blue", Vector2(250, 320), BLUE), _lit("crystal_blue", Vector2(390, 320), BLUE)],
		"spawns": [_s("toad", Vector2(520, 300))]})

## C5 Drop Shaft (1×3): a zigzag of ledges down to the floor. Plan 2 opens its floor to G1.
static func c5() -> RoomDef:
	var solids: Array = [Rect2(20, 320, 180, 12)]  # entry ledge by the left exit
	for k in range(1, 14):
		solids.append(Rect2(100.0 if k % 2 == 1 else 240.0, 1040.0 - 52.0 * k, 100, 12))
	return _room({"id": "C5", "area": "cave", "cell": Vector2i(5, 2), "size": Vector2i(1, 3),
		"exits": [_exit("left", 200, 320, "C4")],
		"solids": solids,
		"decor": [_lit("torch", Vector2(150, 290), FIRE), _lit("torch", Vector2(290, 490), FIRE),
			_lit("crystal_purple", Vector2(500, 1040), PURPLE), _lit("crystal_teal", Vector2(150, 1040), TEAL),
			_hang("stalactite", Vector2(400, 20))],
		"spawns": [_s("bat", Vector2(450, 500)), _s("bat", Vector2(420, 800)), _s("lizard", Vector2(400, 1020)),
			_s("spider", Vector2(500, 32)), _s("water_pool", Vector2(560, 1036))]})

## C6 nook (1×1): a quiet crystal cavern with a tablet, and the switch that opens the floor
## down into C1 for good.
static func c6() -> RoomDef:
	return _room({"id": "C6", "area": "cave", "cell": Vector2i(1, 1), "size": Vector2i(1, 1),
		"exits": [_exit("right", 200, 320, "C3"), _exit("bottom", 200, 260, "C1", {"shortcut": "c6_drop"})],
		"solids": [Rect2(440, 266, 120, 12)],
		"features": [
			{"kind": "tablet", "id": "c6_tablet", "pos": Vector2(480, 320), "title": "Worn tablet",
				"text": "Eat what hunts by sound in the dark, and you will hear as it does.", "hint": "echolocation"},
			{"kind": "switch", "id": "c6_switch", "shortcut": "c6_drop", "pos": Vector2(290, 320)}],
		"decor": [_lit("crystal_purple", Vector2(100, 320), PURPLE), _lit("crystal_purple", Vector2(160, 320), PURPLE),
			_lit("crystal_blue", Vector2(380, 320), BLUE), _lit("crystal_teal", Vector2(500, 266), TEAL)]})
