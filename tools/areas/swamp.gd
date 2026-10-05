class_name SwampArea
extends AreaModule
## The swamp east of the forest (docs/research/area-level-design.md section 12): five rooms, seven screens. The forest's Den opens east onto a
## root seam, a boardwalk crosses to the Bog Flat, and from there the Stilt Roost climbs above, the Hunting Blind lies beyond and the village
## drops below (the village module makes that exit). Art is the flooded tunnels'; the mud, the murk and the wisps' guiding are art and text
## until a later piece gives them rules.

func area() -> String:
	return "swamp"

func prefix() -> String:
	return "SW"

func build(world: Dictionary) -> void:
	var seam := _seam()
	var boardwalk := _boardwalk()
	var flat := _flat()
	var roost := _roost()
	var blind := _blind()
	for r in [seam, boardwalk, flat, roost, blind]:
		world[r.id] = r
	link(world["FO9"], seam, "right", 200.0, 320.0)
	link(seam, boardwalk, "right", 200.0, 320.0)
	link(boardwalk, flat, "right", 200.0, 320.0)
	link(flat, roost, "top", 9920.0, 10080.0)  # x: the hole is 960 to 1120 in the Flat (cell 14 starts at 8960) and 320 to 480 in the Roost
	link(flat, blind, "right", 200.0, 320.0)

# --- SW1 the Root Seam: the threshold, no creatures; the palette changes behind it ---
func _seam() -> RoomDef:
	var r := AreaKit.room("SW1", "swamp", Vector2i(11, 0))
	AreaKit.ledge(r, 240.0, 268.0, 140.0)
	AreaKit.decor(r, "flooded_root_hang", 160.0, 20.0)
	AreaKit.decor(r, "flooded_root_hang", 480.0, 20.0)
	AreaKit.decor(r, "flooded_puddle_glow", 120.0, 320.0)
	AreaKit.decor(r, "flooded_glow_fungus", 440.0, 320.0)
	return r

# --- SW2 the Boardwalk: two screens of planks over the floor, a puddle to teach the mud, wisps ahead ---
func _boardwalk() -> RoomDef:
	var r := AreaKit.room("SW2", "swamp", Vector2i(12, 0), Vector2i(2, 1))
	for i in 4:
		AreaKit.ledge(r, 200.0 + 230.0 * i, 268.0, 150.0)
	AreaKit.spawn(r, "bog_wisp", 700.0, 190.0)
	AreaKit.spawn(r, "blood_leech", 1000.0, 320.0)
	AreaKit.decor(r, "flooded_puddle_glow", 320.0, 320.0)
	AreaKit.decor(r, "flooded_glow_fungus", 820.0, 320.0)
	AreaKit.decor(r, "flooded_flowers", 1150.0, 320.0)
	AreaKit.decor(r, "flooded_lichen_hang", 600.0, 20.0)
	AreaKit.decor(r, "flooded_root_hang", 1100.0, 20.0)
	AreaKit.feature(r, "gap", "SW2_gap_a", 390.0, 268.0, {"width": 80.0})  # between planks
	AreaKit.feature(r, "gap", "SW2_gap_b", 620.0, 268.0, {"width": 80.0})
	return r

# --- SW3 the Bog Flat: the hub of the swamp; a climb to the Roost, the Blind to the east, and the village's hole in the floor ---
func _flat() -> RoomDef:
	var r := AreaKit.room("SW3", "swamp", Vector2i(14, 0), Vector2i(2, 1))
	AreaKit.ledge(r, 540.0, 268.0, 100.0)  # beside the hole in the floor (700 to 860): the footing for whoever climbs out of the village
	AreaKit.climb(r, 960.0, 1120.0)
	AreaKit.spawn(r, "blood_leech", 260.0, 320.0)
	AreaKit.spawn(r, "bog_wisp", 520.0, 190.0)
	AreaKit.spawn(r, "firefly_swarm", 1000.0, 120.0)
	AreaKit.decor(r, "flooded_puddle_glow", 400.0, 320.0)
	AreaKit.decor(r, "flooded_rubble", 180.0, 320.0)
	AreaKit.decor(r, "flooded_glow_fungus", 1200.0, 320.0)
	AreaKit.decor(r, "flooded_root_hang", 300.0, 20.0)
	AreaKit.decor(r, "flooded_root_hang", 800.0, 20.0)
	return r

# --- SW4 the Stilt Roost: above the Flat, a dead end ---
func _roost() -> RoomDef:
	var r := AreaKit.room("SW4", "swamp", Vector2i(15, -1))
	AreaKit.ledge(r, 100.0, 268.0, 110.0)
	AreaKit.spawn(r, "bog_wisp", 520.0, 190.0)
	AreaKit.decor(r, "flooded_stalagmite", 120.0, 268.0)
	AreaKit.decor(r, "flooded_stalagmite", 560.0, 320.0)
	AreaKit.decor(r, "flooded_root_hang", 360.0, 20.0)
	return r

# --- SW5 the Hunting Blind: east of the Flat, a dead end ---
func _blind() -> RoomDef:
	var r := AreaKit.room("SW5", "swamp", Vector2i(16, 0))
	AreaKit.ledge(r, 420.0, 268.0, 140.0)
	AreaKit.spawn(r, "firefly_swarm", 320.0, 190.0)
	AreaKit.decor(r, "flooded_rubble", 150.0, 320.0)
	AreaKit.decor(r, "flooded_glow_fungus", 520.0, 320.0)
	AreaKit.decor(r, "flooded_root_hang", 300.0, 20.0)
	AreaKit.feature(r, "barrier", "SW5_barrier", 44.0, 320.0, {"size": Vector2(24.0, 120.0)})  # across the door: a slab the dissolve verb opens
	return r
