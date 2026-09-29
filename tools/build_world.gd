extends SceneTree
## Generates res://data/rooms/*.tres. This file is the source of truth for room geometry;
## edit here, then re-run:
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_world.gd
## Positions are local to each room. Floors, ceilings and side walls are generated from each
## room's size and exits (RoomBuilder.edge_walls): floor top = height - 40, walls 20 thick.

const TEAL := Color(0.3, 1.0, 0.9)
const PURPLE := Color(0.8, 0.4, 1.0)
const BLUE := Color(0.3, 0.5, 1.0)
const ROSE := Color(1.0, 0.55, 0.75)
const GOLD := Color(1.0, 0.85, 0.4)
const PRISM := Color(0.95, 0.85, 1.0)
const GLOW := Color(0.35, 0.95, 0.7)  # glow fungus and lichen; nothing in the wilderness burns

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

## Set dressing: a scenery prop behind the play plane. `factor` is its depth: 0.1-0.3 far (arches,
## pillars, floating ledges, waterfalls), 0.4-0.55 middle (crystals, mushroom groves, stalactites), 0.65-0.8
## near (hanging roots at the edges). A prop appears at `pos` when the camera is as close to it as the
## room allows and drifts by depth from there (see SetDressing).
static func _dress(piece: String, pos: Vector2, factor: float, flip := false) -> Dictionary:
	var d := {"piece": piece, "pos": pos, "factor": factor}
	if flip:
		d["flip"] = true
	return d

static func rooms() -> Array:
	return [c1(), c2(), c3(), c4(), c5(), c6()]

## C1 Start (2×1): the original lower hall. Floor top 320.
static func c1() -> RoomDef:
	var f := {"id": "C1", "area": "cave", "cell": Vector2i(0, 2), "size": Vector2i(2, 1),
		"start": Vector2(60, 308),  # body centre is 12 px above the floor top (320)
		"features": [{"kind": "rebirth_pool", "id": "C1", "area": "cave", "kit": {}, "pos": Vector2(140, 320)}],
		"exits": [_exit("right", 200, 320, "C2"), _exit("top", 840, 900, "C6", {"shortcut": "c6_drop"})],
		"solids": [Rect2(260, 266, 120, 12), Rect2(420, 214, 100, 12), Rect2(760, 140, 16, 180),
			Rect2(900, 266, 140, 12), Rect2(1060, 214, 100, 12)],
		"decor": [_lit("crystal_teal", Vector2(110, 320), TEAL), _lit("crystal_prism", Vector2(610, 320), PRISM),
			_lit("crystal_rose", Vector2(1010, 320), ROSE), _lit("crystal_gold", Vector2(470, 214), GOLD),
			_lit("glow_fungus", Vector2(320, 266), GLOW), _hang("vine", Vector2(300, 278)), _hang("vine", Vector2(980, 278)),
			_hang("stalactite", Vector2(470, 226)), _hang("stalactite", Vector2(1110, 226))],
		"dressing": [_dress("stone_arch", Vector2(250, 330), 0.2), _dress("rock_pillar", Vector2(700, 330), 0.25),
			_dress("stone_arch", Vector2(1100, 330), 0.18, true), _dress("mossy_ledge", Vector2(330, 120), 0.22),
			_dress("mossy_ledge", Vector2(820, 130), 0.3, true), _dress("waterfall_ribbon", Vector2(640, 20), 0.3),
			_dress("mushroom_grove", Vector2(520, 330), 0.45), _dress("crystal_cluster", Vector2(930, 330), 0.5),
			_dress("stalactite_cluster", Vector2(400, 20), 0.4), _dress("stalactite_cluster", Vector2(860, 20), 0.35, true),
			_dress("hanging_roots", Vector2(180, 20), 0.7), _dress("hanging_roots", Vector2(1150, 20), 0.65)],
		"spawns": [_s("bat", Vector2(300, 200)), _s("bat", Vector2(470, 170)), _s("bat", Vector2(980, 180)),
			_s("toad", Vector2(200, 300)), _s("toad", Vector2(420, 300)), _s("toad", Vector2(680, 300)),
			_s("toad", Vector2(1100, 300)), _s("lizard", Vector2(860, 300)), _s("water_pool", Vector2(150, 316))]}
	Prefabs.stamp(f, "outcrop", Vector2(480, 320))
	Prefabs.stamp(f, "scatter", Vector2(640, 320))
	Prefabs.stamp(f, "stalactites", Vector2(300, 20))
	Prefabs.stamp(f, "stalactites", Vector2(980, 20), true)
	return _room(f)

## C2 Thread Gap (2×1): spiders under the ceiling; a chimney up to C3 needs Wall Cling.
static func c2() -> RoomDef:
	var f := {"id": "C2", "area": "cave", "cell": Vector2i(2, 2), "size": Vector2i(2, 1),
		"exits": [_exit("left", 200, 320, "C1"), _exit("right", 200, 320, "C4"),
			_exit("top", 300, 380, "C3", {"gate": "wall_cling"})],
		"solids": [Rect2(280, 20, 16, 220), Rect2(384, 20, 16, 220),
			Rect2(160, 266, 90, 12), Rect2(40, 214, 90, 12),
			Rect2(560, 266, 120, 12), Rect2(740, 214, 120, 12), Rect2(920, 266, 120, 12)],
		"decor": [_lit("glow_fungus", Vector2(800, 214), GLOW), _lit("crystal_teal", Vector2(500, 320), TEAL),
			_lit("crystal_blue", Vector2(1200, 320), BLUE), _hang("vine", Vector2(620, 20)),
			_hang("stalactite", Vector2(1150, 20))],
		"dressing": [_dress("stone_arch", Vector2(300, 330), 0.2), _dress("stone_arch", Vector2(980, 330), 0.22, true),
			_dress("rock_pillar", Vector2(650, 330), 0.3), _dress("mossy_ledge", Vector2(450, 140), 0.25),
			_dress("waterfall_ribbon", Vector2(1050, 20), 0.28), _dress("mushroom_grove", Vector2(150, 330), 0.45),
			_dress("crystal_cluster", Vector2(1150, 330), 0.5), _dress("stalactite_cluster", Vector2(500, 20), 0.4),
			_dress("stalactite_cluster", Vector2(900, 20), 0.4, true), _dress("hanging_roots", Vector2(100, 20), 0.7),
			_dress("hanging_roots", Vector2(700, 20), 0.65), _dress("hanging_roots", Vector2(1220, 20), 0.7)],
		"spawns": [_s("spider", Vector2(700, 32)), _s("spider", Vector2(1000, 32)),
			_s("lizard", Vector2(600, 300)), _s("lizard", Vector2(1100, 300))]}
	Prefabs.stamp(f, "arch", Vector2(420, 320))
	Prefabs.stamp(f, "stalactites", Vector2(760, 20))
	Prefabs.stamp(f, "scatter", Vector2(980, 320))
	return _room(f)

## C3 Spider Loft (1×2): a climb of ledges; entered from C2's chimney below.
static func c3() -> RoomDef:
	var f := {"id": "C3", "area": "cave", "cell": Vector2i(2, 0), "size": Vector2i(1, 2),
		"exits": [_exit("bottom", 300, 380, "C2", {"gate": "wall_cling"}), _exit("left", 560, 680, "C6")],
		"solids": [Rect2(60, 626, 100, 12), Rect2(200, 574, 100, 12), Rect2(60, 522, 100, 12),
			Rect2(200, 470, 100, 12), Rect2(340, 418, 120, 12), Rect2(500, 366, 100, 12),
			Rect2(340, 314, 100, 12), Rect2(180, 262, 100, 12), Rect2(40, 210, 120, 12)],
		"decor": [_lit("crystal_gold", Vector2(100, 210), GOLD), _lit("glow_fungus", Vector2(390, 418), GLOW),
			_hang("vine", Vector2(560, 20)), _hang("vine", Vector2(120, 20))],
		"dressing": [_dress("stalactite_cluster", Vector2(400, 20), 0.4), _dress("hanging_roots", Vector2(100, 20), 0.7),
			_dress("waterfall_ribbon", Vector2(520, 20), 0.25), _dress("mossy_ledge", Vector2(300, 220), 0.25),
			_dress("mossy_ledge", Vector2(300, 400), 0.3, true), _dress("hanging_roots", Vector2(280, 445), 0.3),
			_dress("mossy_ledge", Vector2(140, 560), 0.25), _dress("stalactite_cluster", Vector2(140, 605), 0.25),
			_dress("stone_arch", Vector2(320, 710), 0.2), _dress("crystal_cluster", Vector2(100, 710), 0.5),
			_dress("mushroom_grove", Vector2(520, 710), 0.45)],
		"spawns": [_s("spider", Vector2(240, 32)), _s("spider", Vector2(520, 32)), _s("bat", Vector2(450, 300))]}
	Prefabs.stamp(f, "pillars", Vector2(450, 680))
	Prefabs.stamp(f, "stalactites", Vector2(60, 20))
	return _room(f)

## C4 Glow Pool (1×1): rest here.
static func c4() -> RoomDef:
	var f := {"id": "C4", "area": "cave", "cell": Vector2i(4, 2), "size": Vector2i(1, 1),
		"exits": [_exit("left", 200, 320, "C2"), _exit("right", 200, 320, "C5")],
		"solids": [Rect2(100, 266, 100, 12), Rect2(440, 266, 100, 12)],
		"features": [{"kind": "glow_pool", "id": "c4_pool", "pos": Vector2(320, 320)}],
		"decor": [_lit("glow_fungus", Vector2(150, 266), GLOW), _lit("crystal_teal", Vector2(470, 266), TEAL),
			_lit("crystal_rose", Vector2(250, 320), ROSE), _lit("crystal_prism", Vector2(390, 320), PRISM)],
		"dressing": [_dress("stone_arch", Vector2(320, 330), 0.2), _dress("waterfall_ribbon", Vector2(320, 20), 0.3),
			_dress("crystal_cluster", Vector2(110, 330), 0.5), _dress("mushroom_grove", Vector2(540, 330), 0.45),
			_dress("stalactite_cluster", Vector2(160, 20), 0.4), _dress("stalactite_cluster", Vector2(480, 20), 0.35, true),
			_dress("hanging_roots", Vector2(60, 20), 0.7), _dress("hanging_roots", Vector2(600, 20), 0.65)],
		"spawns": [_s("toad", Vector2(520, 300))]}
	Prefabs.stamp(f, "stalactites", Vector2(250, 20))
	Prefabs.stamp(f, "scatter", Vector2(100, 320))
	return _room(f)

## C5 Drop Shaft (1×3): a zigzag of ledges down to the floor. Plan 2 opens its floor to G1.
static func c5() -> RoomDef:
	var solids: Array = [Rect2(20, 320, 70, 12)]  # entry ledge by the left exit; it stops short of the k=13 platform (x 100+) so the taller slime has full headroom there
	for k in range(1, 14):
		solids.append(Rect2(100.0 if k % 2 == 1 else 240.0, 1040.0 - 52.0 * k, 100, 12))
	var f := {"id": "C5", "area": "cave", "cell": Vector2i(5, 2), "size": Vector2i(1, 3),
		"exits": [_exit("left", 200, 320, "C4")],
		"solids": solids,
		"decor": [_lit("glow_fungus", Vector2(150, 364), GLOW), _lit("glow_fungus", Vector2(290, 520), GLOW),
			_lit("crystal_prism", Vector2(500, 1040), PRISM), _lit("crystal_teal", Vector2(150, 1040), TEAL),
			_hang("stalactite", Vector2(400, 20))],
		"dressing": [_dress("stalactite_cluster", Vector2(420, 20), 0.4), _dress("hanging_roots", Vector2(90, 20), 0.7),
			_dress("waterfall_ribbon", Vector2(540, 20), 0.25), _dress("mossy_ledge", Vector2(480, 300), 0.25),
			_dress("hanging_roots", Vector2(480, 345), 0.25), _dress("mossy_ledge", Vector2(150, 470), 0.3, true),
			_dress("hanging_roots", Vector2(150, 515), 0.3), _dress("mossy_ledge", Vector2(500, 640), 0.22, true),
			_dress("mossy_ledge", Vector2(170, 820), 0.28), _dress("stalactite_cluster", Vector2(170, 865), 0.28),
			_dress("mossy_ledge", Vector2(480, 930), 0.25), _dress("stone_arch", Vector2(320, 1050), 0.2),
			_dress("rock_pillar", Vector2(80, 1050), 0.3), _dress("mushroom_grove", Vector2(300, 1050), 0.45),
			_dress("crystal_cluster", Vector2(560, 1050), 0.5)],
		"spawns": [_s("bat", Vector2(450, 500)), _s("bat", Vector2(420, 800)), _s("lizard", Vector2(400, 1020)),
			_s("spider", Vector2(500, 32)), _s("water_pool", Vector2(560, 1036))]}
	Prefabs.stamp(f, "stalactites", Vector2(300, 20))
	return _room(f)

## C6 nook (1×1): a quiet crystal cavern with a tablet, and the switch that opens the floor
## down into C1 for good.
static func c6() -> RoomDef:
	var f := {"id": "C6", "area": "cave", "cell": Vector2i(1, 1), "size": Vector2i(1, 1),
		"exits": [_exit("right", 200, 320, "C3"), _exit("bottom", 200, 260, "C1", {"shortcut": "c6_drop"})],
		"solids": [Rect2(440, 266, 120, 12)],
		"features": [
			{"kind": "tablet", "id": "c6_tablet", "pos": Vector2(480, 320), "title": "Worn tablet",
				"text": "Eat what hunts by sound in the dark, and you will hear as it does.", "hint": "echolocation"},
			{"kind": "switch", "id": "c6_switch", "shortcut": "c6_drop", "pos": Vector2(290, 320)}],
		"decor": [_lit("crystal_rose", Vector2(100, 320), ROSE), _lit("crystal_gold", Vector2(160, 320), GOLD),
			_lit("crystal_prism", Vector2(380, 320), PRISM), _lit("crystal_teal", Vector2(500, 266), TEAL)],
		"dressing": [_dress("stone_arch", Vector2(330, 330), 0.18), _dress("rock_pillar", Vector2(580, 330), 0.3),
			_dress("mossy_ledge", Vector2(200, 150), 0.25), _dress("mushroom_grove", Vector2(320, 330), 0.42),
			_dress("crystal_cluster", Vector2(110, 330), 0.5), _dress("crystal_cluster", Vector2(540, 330), 0.55, true),
			_dress("stalactite_cluster", Vector2(120, 20), 0.4), _dress("stalactite_cluster", Vector2(500, 20), 0.35, true),
			_dress("hanging_roots", Vector2(320, 20), 0.7)]}
	Prefabs.stamp(f, "stalactites", Vector2(120, 20))
	return _room(f)
