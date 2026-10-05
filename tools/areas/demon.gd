class_name DemonArea
extends AreaModule
## The demon area past the crypt (docs/research/area-level-design.md section 13, "Three Seals"): seven rooms, thirteen screens. The Vault's east door
## leads to the Threshold, then the Gate Hall, whose pool is the rest; three spokes leave it: the West (down), the Middle (up, and on to the
## Throne at the floor of a tall room) and the East (on to the Reliquary). Art is the Deep's. The sealed gates (`spawn_gate`), the taint strips and
## their wards, the pact altar and the boss door are not built: the rooms hold the creatures that will guard them. The Throne is a plain room
## with its caller, not a boss arena (a boss room has exactly one exit and a quiet antechamber with a pool, and the sketch wants a shortcut back).

func area() -> String:
	return "demon"

func prefix() -> String:
	return "DM"

func build(world: Dictionary) -> void:
	var threshold := _threshold()
	var hall := _hall()
	var west := _west()
	var middle := _middle()
	var east := _east()
	var throne := _throne()
	var reliquary := _reliquary()
	for r in [threshold, hall, west, middle, east, throne, reliquary]:
		world[r.id] = r
	link(world["CR4"], threshold, "right", 2000.0, 2120.0)  # y: row 5 starts at 1800
	link(threshold, hall, "right", 2000.0, 2120.0)
	link(hall, west, "bottom", 19600.0, 19760.0)  # x: 400 to 560 in both (cell 30 starts at 19200)
	link(hall, middle, "top", 20240.0, 20400.0)  # 1040 to 1200 in the Hall, 400 to 560 in the Middle (cell 31 starts at 19840)
	link(hall, east, "right", 2000.0, 2120.0)
	link(east, reliquary, "right", 2000.0, 2120.0)
	link(middle, throne, "right", 1640.0, 1760.0)  # y: row 4 starts at 1440; the Throne's row 4 is its lower screen, so the door is at its floor

# --- DM1 the Threshold: a tablet and the first red-black stone; no creatures ---
func _threshold() -> RoomDef:
	var r := AreaKit.room("DM1", "demon", Vector2i(29, 5))
	AreaKit.feature(r, "tablet", "DM1_tablet", 320.0, 320.0, {"title": "Scorched tablet", "text": "The stone is warm, and red where the lamplight touches it. Whatever keeps the hall beyond has kept it a long time."})
	AreaKit.decor(r, "deep_bones", 150.0, 320.0)
	AreaKit.decor(r, "deep_glow_fungus", 480.0, 320.0)
	AreaKit.decor(r, "deep_root_hang", 300.0, 20.0)
	return r

# --- DM2 the Gate Hall: three screens, the pool, and a way out to each spoke (down to the West, up to the Middle, east) ---
func _hall() -> RoomDef:
	var r := AreaKit.room("DM2", "demon", Vector2i(30, 5), Vector2i(3, 1))
	AreaKit.flank(r, 400.0, 560.0)
	AreaKit.climb(r, 1040.0, 1200.0)
	AreaKit.feature(r, "glow_pool", "DM2_pool", 800.0, 320.0, {"area": "demon"})
	AreaKit.decor(r, "deep_wall_crystal", 700.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 150.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 1700.0, 320.0)
	AreaKit.decor(r, "deep_root_hang", 600.0, 20.0)
	AreaKit.decor(r, "deep_root_hang", 1400.0, 20.0)
	AreaKit.decor(r, "deep_lichen_hang", 1000.0, 20.0)
	return r

# --- DM3 the West: a dead end below the hall; the way back up is a climb ---
func _west() -> RoomDef:
	var r := AreaKit.room("DM3", "demon", Vector2i(30, 6), Vector2i(2, 1))
	AreaKit.climb(r, 400.0, 560.0)
	AreaKit.spawn(r, "imp", 760.0, 320.0)
	AreaKit.spawn(r, "imp", 960.0, 320.0)
	AreaKit.spawn(r, "blinker", 1160.0, 320.0)
	AreaKit.decor(r, "deep_bones", 150.0, 320.0)
	AreaKit.decor(r, "deep_rubble", 650.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 1220.0, 320.0)
	AreaKit.decor(r, "deep_root_hang", 800.0, 20.0)
	return r

# --- DM4 the Middle: above the hall; the way on to the Throne is level ---
func _middle() -> RoomDef:
	var r := AreaKit.room("DM4", "demon", Vector2i(31, 4), Vector2i(2, 1))
	AreaKit.flank(r, 400.0, 560.0)
	AreaKit.spawn(r, "demon_hound", 800.0, 320.0)
	AreaKit.spawn(r, "demon_hound", 960.0, 320.0)
	AreaKit.spawn(r, "imp", 1130.0, 320.0)
	AreaKit.decor(r, "deep_bones", 700.0, 320.0)
	AreaKit.decor(r, "deep_rubble", 150.0, 320.0)
	AreaKit.decor(r, "deep_lichen_hang", 900.0, 20.0)
	return r

# --- DM5 the East: on to the Reliquary ---
func _east() -> RoomDef:
	var r := AreaKit.room("DM5", "demon", Vector2i(33, 5), Vector2i(2, 1))
	AreaKit.ledge(r, 300.0, 268.0, 120.0)
	AreaKit.ledge(r, 900.0, 268.0, 120.0)
	AreaKit.spawn(r, "ward_bearer", 560.0, 320.0)
	AreaKit.spawn(r, "imp", 760.0, 320.0)
	AreaKit.spawn(r, "blinker", 1120.0, 320.0)
	AreaKit.decor(r, "deep_wall_crystal", 200.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 1000.0, 320.0)
	AreaKit.decor(r, "deep_root_hang", 500.0, 20.0)
	AreaKit.decor(r, "deep_lichen_hang", 1000.0, 20.0)
	return r

# --- DM6 the Throne: two screens tall, a stair of ledges up the west wall, the caller and what it calls ---
func _throne() -> RoomDef:
	var r := AreaKit.room("DM6", "demon", Vector2i(33, 3), Vector2i(1, 2))
	for i in 4:
		AreaKit.ledge(r, 60.0 + 140.0 * i, 628.0 - 52.0 * i, 100.0)
	AreaKit.spawn(r, "caller", 330.0, 680.0)
	AreaKit.spawn(r, "imp", 540.0, 680.0)
	AreaKit.spawn(r, "imp", 590.0, 680.0)
	AreaKit.decor(r, "deep_bones", 450.0, 680.0)
	AreaKit.decor(r, "deep_root_hang", 300.0, 20.0)
	AreaKit.decor(r, "deep_lichen_hang", 500.0, 20.0)
	return r

# --- DM7 the Reliquary: a dead end; the rider waits ---
func _reliquary() -> RoomDef:
	var r := AreaKit.room("DM7", "demon", Vector2i(35, 5))
	AreaKit.spawn(r, "rider", 360.0, 320.0)
	AreaKit.decor(r, "deep_bones", 200.0, 320.0)
	AreaKit.decor(r, "deep_glow_fungus", 520.0, 320.0)
	AreaKit.decor(r, "deep_wall_crystal", 440.0, 320.0)
	return r
