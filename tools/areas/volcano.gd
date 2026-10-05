class_name VolcanoArea
extends AreaModule
## The volcano under the Deep (docs/research/area-level-design.md section 7): seven rooms, ten screens. A hole in the floor of D4 (the Deep's
## corridor to its dead end) drops onto Ashfall, a landing with a tablet; Ember Hall has the rest pool; a stair down the Chimney leads to the
## Forge Row, the hub, with the Magma Chamber to the east, the Cooled Vault below, and the Ash Cut above, a shaft up to Ember Hall that is
## shut until its own switch is pulled. Art is the cave's. Heat, lava, eruptions, the quench lane and the `heat_resist` gate are not built: the
## fire creatures stand where the heat will be, and the Cooled Vault is a plain side room until the gate is a label.

func area() -> String:
	return "volcano"

func prefix() -> String:
	return "VO"

func build(world: Dictionary) -> void:
	var ashfall := _ashfall()
	var ember := _ember()
	var chimney := _chimney()
	var forge := _forge()
	var magma := _magma()
	var vault := _vault()
	var cut := _cut()
	for r in [ashfall, ember, chimney, forge, magma, vault, cut]:
		world[r.id] = r
	link(world["D4"], ashfall, "bottom", 14540.0, 14700.0)  # x: 1100 to 1260 in D4 (cell 21 starts at 13440), 460 to 620 in Ashfall (cell 22 starts at 14080)
	link(ashfall, ember, "right", 3080.0, 3200.0)  # y: row 8 starts at 2880
	link(ember, chimney, "right", 3080.0, 3200.0)
	link(chimney, forge, "bottom", 16060.0, 16220.0)  # 60 to 220 in the Chimney (cell 25 starts at 16000), 700 to 860 in the Forge Row (cell 24 starts at 15360)
	link(forge, magma, "right", 3800.0, 3920.0)  # row 10 starts at 3600
	link(forge, vault, "bottom", 15800.0, 15960.0)  # 440 to 600 in both
	link(cut, forge, "bottom", 15600.0, 15760.0)  # 240 to 400 in the Cut, 240 to 400 in the Forge Row
	link(ember, cut, "bottom", 15600.0, 15760.0, {"shortcut": "ash_cut"})  # 880 to 1040 in Ember Hall, 240 to 400 in the Cut: shut until the Cut's switch

# --- VO1 Ashfall: a landing under the hole in D4; ash and a warm tablet, no creatures ---
func _ashfall() -> RoomDef:
	var r := AreaKit.room("VO1", "volcano", Vector2i(22, 8))
	AreaKit.climb(r, 460.0, 620.0)
	AreaKit.feature(r, "tablet", "VO1_tablet", 200.0, 320.0, {"title": "Warm tablet", "text": "Heat rises from below. Ash falls from the vents above, and the stone is warm underfoot."})
	AreaKit.decor(r, "rubble", 120.0, 320.0)
	AreaKit.decor(r, "crystal_rose", 330.0, 320.0)
	AreaKit.decor(r, "stalactite", 250.0, 20.0)
	return r

# --- VO2 Ember Hall: two screens, the rest pool at the west end, the first fire creatures; the Ash Cut's shaft opens in the floor ---
func _ember() -> RoomDef:
	var r := AreaKit.room("VO2", "volcano", Vector2i(23, 8), Vector2i(2, 1))
	AreaKit.feature(r, "glow_pool", "VO2_pool", 160.0, 320.0, {"area": "volcano"})
	AreaKit.ledge(r, 300.0, 268.0, 120.0)
	AreaKit.ledge(r, 1100.0, 268.0, 120.0)
	AreaKit.spawn(r, "ember_beetle", 560.0, 320.0)
	AreaKit.spawn(r, "ember_beetle", 680.0, 320.0)
	AreaKit.spawn(r, "lava_salamander", 780.0, 320.0)
	AreaKit.spawn(r, "ash_moth", 1150.0, 170.0)
	AreaKit.decor(r, "crystal_gold", 360.0, 268.0)
	AreaKit.decor(r, "crystal_rose", 1160.0, 268.0)
	AreaKit.decor(r, "stalactite", 520.0, 20.0)
	AreaKit.decor(r, "stalactite", 1000.0, 20.0)
	return r

# --- VO3 the Chimney: a shaft down from Ember Hall, a stair of ledges to the floor and the hole at its west end ---
func _chimney() -> RoomDef:
	var r := AreaKit.room("VO3", "volcano", Vector2i(25, 8), Vector2i(1, 2))
	for i in 7:  # 45 a step, from a hop above the floor in the east to a hop below the door in the west
		AreaKit.ledge(r, 450.0 - 65.0 * i, 634.0 - 45.0 * i, 90.0)
	AreaKit.spawn(r, "ash_moth", 300.0, 400.0)
	AreaKit.decor(r, "stalactite", 400.0, 20.0)
	AreaKit.decor(r, "rubble", 560.0, 680.0)
	return r

# --- VO4 the Forge Row: the hub; two climbs up (to the Ash Cut and the Chimney), a hole down to the Cooled Vault, the Magma Chamber east ---
func _forge() -> RoomDef:
	var r := AreaKit.room("VO4", "volcano", Vector2i(24, 10), Vector2i(2, 1))
	AreaKit.climb(r, 240.0, 400.0)
	AreaKit.climb(r, 700.0, 860.0)
	AreaKit.spawn(r, "lava_salamander", 980.0, 320.0)
	AreaKit.spawn(r, "ember_beetle", 1100.0, 320.0)
	AreaKit.spawn(r, "ember_beetle", 1220.0, 320.0)
	AreaKit.decor(r, "crystal_gold", 650.0, 320.0)
	AreaKit.decor(r, "rubble", 120.0, 320.0)
	AreaKit.decor(r, "stalactite", 600.0, 20.0)
	AreaKit.decor(r, "stalactite", 1050.0, 20.0)
	return r

# --- VO5 the Magma Chamber: the end of the main route, a pool ---
func _magma() -> RoomDef:
	var r := AreaKit.room("VO5", "volcano", Vector2i(26, 10))
	AreaKit.feature(r, "glow_pool", "VO5_pool", 320.0, 320.0, {"area": "volcano"})
	AreaKit.spawn(r, "lava_salamander", 460.0, 320.0)
	AreaKit.spawn(r, "ash_moth", 200.0, 170.0)
	AreaKit.decor(r, "crystal_rose", 220.0, 320.0)
	AreaKit.decor(r, "stalactite", 380.0, 20.0)
	return r

# --- VO6 the Cooled Vault: below the Forge Row, a rare side room; the climb back up ---
func _vault() -> RoomDef:
	var r := AreaKit.room("VO6", "volcano", Vector2i(24, 11))
	AreaKit.climb(r, 440.0, 600.0)
	AreaKit.feature(r, "tablet", "VO6_tablet", 200.0, 320.0, {"title": "Cool tablet", "text": "Cool stone, and a draught from somewhere hot."})
	AreaKit.decor(r, "crystal_blue", 120.0, 320.0)
	AreaKit.decor(r, "crystal_teal", 300.0, 320.0)
	return r

# --- VO7 the Ash Cut: a shaft above the Forge Row; its ceiling hole to Ember Hall is shut until the switch here is pulled ---
func _cut() -> RoomDef:
	var r := AreaKit.room("VO7", "volcano", Vector2i(24, 9))
	AreaKit.flank(r, 240.0, 400.0)
	AreaKit.climb(r, 240.0, 400.0)
	AreaKit.feature(r, "switch", "VO7_switch", 560.0, 320.0, {"shortcut": "ash_cut"})
	AreaKit.decor(r, "rubble", 90.0, 320.0)
	return r
