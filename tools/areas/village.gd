class_name VillageArea
extends AreaModule
## The goblin village below the swamp (docs/research/area-level-design.md section 12): four rooms and the Sump, ten screens. The Bog Flat's
## floor opens onto the Gate Shrine, a neutral gatehouse with a pool and nothing hostile in it; the Palisade Roofs lie west of it and the
## Yard below both; the Chieftain Hall is a dead end off the Yard, and the Yard's floor opens onto the Sump, a flooded shaft that is the
## swamp's second link to the Flooded Tunnels: a shortcut hole into F6 that a swimmer opens from F6's own highest ledge. Art is the cave's, the Sump's the flooded tunnels'. Standing, trust,
## the trial, the tame pen and the tinker's bench are not built: the village's creatures fight like any creature for now.

func area() -> String:
	return "village"

func prefix() -> String:
	return "VI"

func build(world: Dictionary) -> void:
	var shrine := _shrine()
	var roofs := _roofs()
	var yard := _yard()
	var hall := _hall()
	var sump := _sump()
	for r in [shrine, roofs, yard, hall, sump]:
		world[r.id] = r
	link(world["SW3"], shrine, "bottom", 9660.0, 9820.0)  # x: the hole is 700 to 860 in the Flat (cell 14 starts at 8960) and 60 to 220 in the Shrine
	link(shrine, roofs, "left", 560.0, 680.0)  # y: row 1 starts at 360
	link(roofs, yard, "bottom", 9180.0, 9340.0)  # x: 860 to 1020 in the Roofs (cell 13 starts at 8320), 220 to 380 in the Yard
	link(shrine, yard, "bottom", 10000.0, 10160.0)  # 400 to 560 in the Shrine, 1040 to 1200 in the Yard
	link(yard, hall, "left", 920.0, 1040.0)  # row 2 starts at 720
	link(yard, sump, "bottom", 9700.0, 9860.0)  # 740 to 900 in the Yard, 100 to 260 in the Sump
	# 440 to 600 in both. A drop: a walker sinks through a hole in water, so a label would not hold it. The hole is a shortcut, shut until a
	# swimmer opens it from F6's side (area-level-design.md section 11: a link from an early area would bypass the Swim door).
	link(sump, world["F6"], "bottom", 10040.0, 10200.0, {"shortcut": "sump_drop"})
	attach_feature(world["F6"], "switch", "f6_switch", 105.0, 158.0, {"shortcut": "sump_drop"})  # on F6's highest ledge

# --- VI1 the Gate Shrine: neutral ground, a pool and no creatures for any species ---
func _shrine() -> RoomDef:
	var r := AreaKit.room("VI1", "village", Vector2i(15, 1))
	AreaKit.climb(r, 60.0, 220.0)
	AreaKit.feature(r, "glow_pool", "VI1_pool", 310.0, 320.0, {"area": "village"})
	AreaKit.decor(r, "flowers", 260.0, 320.0)
	AreaKit.decor(r, "root_hang", 330.0, 20.0)
	AreaKit.decor(r, "rubble", 600.0, 320.0)
	return r

# --- VI2 the Palisade Roofs: two screens of walls and beams, the sentries' ground ---
func _roofs() -> RoomDef:
	var r := AreaKit.room("VI2", "village", Vector2i(13, 1), Vector2i(2, 1))
	AreaKit.stairs(r, 100.0, 268.0, 110.0, 52.0, 3, 100.0)
	AreaKit.ledge(r, 720.0, 268.0, 100.0)  # beside the hole in the floor (860 to 1020)
	AreaKit.ledge(r, 1040.0, 268.0, 100.0)
	AreaKit.ledge(r, 1180.0, 216.0, 100.0)
	AreaKit.spawn(r, "village_goblin", 400.0, 320.0)
	AreaKit.spawn(r, "village_goblin", 1090.0, 268.0)
	AreaKit.spawn(r, "cave_rat", 620.0, 320.0)
	AreaKit.decor(r, "stalagmite", 520.0, 320.0)
	AreaKit.decor(r, "root_hang", 300.0, 20.0)
	AreaKit.decor(r, "root_hang", 800.0, 20.0)
	AreaKit.decor(r, "vine", 1150.0, 20.0)
	return r

# --- VI3 the Village Yard: the heart of it, open ground with a way up to each of the two rooms above and a hole to the Sump ---
func _yard() -> RoomDef:
	var r := AreaKit.room("VI3", "village", Vector2i(14, 2), Vector2i(2, 1))
	AreaKit.climb(r, 220.0, 380.0)
	AreaKit.climb(r, 1040.0, 1200.0)
	AreaKit.flank(r, 740.0, 900.0)
	AreaKit.spawn(r, "village_goblin", 520.0, 320.0)
	AreaKit.spawn(r, "village_goblin", 970.0, 268.0)
	AreaKit.spawn(r, "cave_rat", 330.0, 320.0)
	AreaKit.spawn(r, "junk", 620.0, 320.0)
	AreaKit.decor(r, "flowers", 150.0, 320.0)
	AreaKit.decor(r, "rubble", 450.0, 320.0)
	AreaKit.decor(r, "root_hang", 600.0, 20.0)
	AreaKit.decor(r, "root_hang", 900.0, 20.0)
	AreaKit.decor(r, "stalagmite", 1230.0, 320.0)
	AreaKit.feature(r, "lamp", "VI3_lamp", 700.0, 320.0)
	return r

# --- VI4 the Chieftain Hall: a dead end west of the Yard ---
func _hall() -> RoomDef:
	var r := AreaKit.room("VI4", "village", Vector2i(13, 2))
	AreaKit.ledge(r, 160.0, 268.0, 120.0)
	AreaKit.spawn(r, "goblin_shaman", 380.0, 320.0)
	AreaKit.decor(r, "stalagmite", 120.0, 320.0)
	AreaKit.decor(r, "rubble", 540.0, 320.0)
	AreaKit.decor(r, "vine", 300.0, 20.0)
	return r

# --- VI5 the Sump: a flooded shaft from the Yard down to the Flooded Tunnels; the climb out stands in the water ---
func _sump() -> RoomDef:
	var r := AreaKit.room("VI5", "swamp", Vector2i(15, 3), Vector2i(1, 2))
	AreaKit.climb(r, 100.0, 260.0)
	r.water = [Rect2(0, 300, 640, 420)]  # to the bottom edge, so that the hole in the floor is open to a swimmer
	AreaKit.decor(r, "flooded_stalagmite", 380.0, 680.0)
	AreaKit.decor(r, "flooded_crystal_gold", 330.0, 680.0)
	AreaKit.decor(r, "flooded_lichen_hang", 420.0, 20.0)
	AreaKit.decor(r, "flooded_root_hang", 560.0, 20.0)
	return r
