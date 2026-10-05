class_name CryptArea
extends AreaModule
## The crypt east of the Lych Gate (docs/research/area-level-design.md section 11): five rooms. A stair descends from the gate to the Ossuary; the
## Niche Gallery runs three screens east to the Vault; a hole in the Ossuary's floor drops onto the Coffin Slide, a chute two screens wide whose
## own hole drops into D5, a Deep dead end: one way down, since D5 has no ledge to climb out by. Art is the Deep's. The curse, the dark, the
## revive link and the traps (sliding coffins, falling tomb floors, dart niches) are not built: art and text until a later piece.

func area() -> String:
	return "crypt"

func prefix() -> String:
	return "CR"

func build(world: Dictionary) -> void:
	var stair := _stair()
	var ossuary := _ossuary()
	var gallery := _gallery()
	var vault := _vault()
	var slide := _slide()
	for r in [stair, ossuary, gallery, vault, slide]:
		world[r.id] = r
	link(world["CM3"], stair, "right", 1640.0, 1760.0)  # y: row 4 starts at 1440
	link(stair, ossuary, "right", 2000.0, 2120.0)  # row 5 starts at 1800: 560 to 680 in the Stair, 200 to 320 in the Ossuary
	link(ossuary, gallery, "right", 2000.0, 2120.0)
	link(gallery, vault, "right", 2000.0, 2120.0)
	link(ossuary, slide, "bottom", 15620.0, 15780.0)  # x: 900 to 1060 in both (cell 23 starts at 14720)
	link(slide, world["D5"], "bottom", 15160.0, 15320.0)  # 440 to 600 in both

# --- CR1 the Crypt Stair: a staircase of ledges from the door in the north-west down to the floor and the Ossuary's door ---
func _stair() -> RoomDef:
	var r := AreaKit.room("CR1", "crypt", Vector2i(22, 4), Vector2i(1, 2))
	for i in 7:  # 45 a step down and 80 across, the first a hop below the door's sill
		AreaKit.ledge(r, 30.0 + 80.0 * i, 364.0 + 45.0 * i, 100.0)
	AreaKit.spawn(r, "skeleton", 340.0, 499.0)
	AreaKit.spawn(r, "vampire_bat", 400.0, 280.0)
	AreaKit.decor(r, "deep_bones", 120.0, 680.0)
	AreaKit.decor(r, "deep_rubble", 440.0, 680.0)
	AreaKit.decor(r, "deep_root_hang", 300.0, 20.0)
	return r

# --- CR2 the Ossuary: two screens of bones and burial shelves; the floor opens at the east end ---
func _ossuary() -> RoomDef:
	var r := AreaKit.room("CR2", "crypt", Vector2i(23, 5), Vector2i(2, 1))
	AreaKit.ledge(r, 160.0, 268.0, 140.0)
	AreaKit.ledge(r, 420.0, 268.0, 140.0)
	AreaKit.ledge(r, 1120.0, 268.0, 100.0)
	AreaKit.spawn(r, "skeleton", 360.0, 320.0)
	AreaKit.spawn(r, "skeleton", 660.0, 320.0)
	AreaKit.spawn(r, "vampire_bat", 800.0, 150.0)
	AreaKit.decor(r, "deep_bones", 600.0, 320.0)
	AreaKit.decor(r, "deep_rubble", 100.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 1200.0, 320.0)
	AreaKit.decor(r, "deep_root_hang", 500.0, 20.0)
	AreaKit.decor(r, "deep_lichen_hang", 1000.0, 20.0)
	return r

# --- CR3 the Niche Gallery: three screens; shelves cut in the walls at either end, open floor between for the hounds' run ---
func _gallery() -> RoomDef:
	var r := AreaKit.room("CR3", "crypt", Vector2i(25, 5), Vector2i(3, 1))
	for i in 6:  # two flights of three, each a step (52) up or down from the last and 50 from it
		var x := 250.0 + 200.0 * i if i < 3 else 650.0 + 200.0 * i
		AreaKit.ledge(r, x, 268.0 if i % 2 == 0 else 216.0, 150.0)
	AreaKit.spawn(r, "bone_hound", 950.0, 320.0)
	AreaKit.spawn(r, "bone_hound", 1100.0, 320.0)
	AreaKit.spawn(r, "skeleton", 130.0, 320.0)
	AreaKit.spawn(r, "skeleton", 1200.0, 320.0)
	AreaKit.spawn(r, "vampire_bat", 1000.0, 130.0)
	AreaKit.decor(r, "deep_bones", 880.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 1500.0, 320.0)
	AreaKit.decor(r, "deep_wall_crystal", 1800.0, 320.0)
	AreaKit.decor(r, "deep_lichen_hang", 700.0, 20.0)
	AreaKit.decor(r, "deep_root_hang", 1500.0, 20.0)
	return r

# --- CR4 the Vault: a dead end ---
func _vault() -> RoomDef:
	var r := AreaKit.room("CR4", "crypt", Vector2i(28, 5))
	AreaKit.ledge(r, 200.0, 268.0, 120.0)
	AreaKit.spawn(r, "junk", 420.0, 320.0)
	AreaKit.decor(r, "deep_bones", 120.0, 320.0)
	AreaKit.decor(r, "deep_glow_fungus", 540.0, 320.0)
	AreaKit.decor(r, "deep_wall_crystal", 320.0, 320.0)
	return r

# --- CR5 the Coffin Slide: a chute; whoever drops from the Ossuary walks west to the hole that drops into D5 ---
func _slide() -> RoomDef:
	var r := AreaKit.room("CR5", "crypt", Vector2i(23, 6), Vector2i(2, 1))
	AreaKit.ledge(r, 700.0, 268.0, 120.0)
	AreaKit.ledge(r, 1100.0, 268.0, 120.0)
	AreaKit.decor(r, "deep_bones", 760.0, 320.0)
	AreaKit.decor(r, "deep_stalagmite", 160.0, 320.0)
	AreaKit.decor(r, "deep_rubble", 300.0, 320.0)
	AreaKit.decor(r, "deep_root_hang", 800.0, 20.0)
	return r
