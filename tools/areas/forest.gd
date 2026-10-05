class_name ForestArea
extends AreaModule
## The surface above the cave (docs/research/area-level-design.md section 6): nine rooms, 16 screens. The cave's C3 opens east onto the Cave
## Mouth (a hop up from its highest reachable ledge); the Treeline leads to the Clearing, the hub; the Great Trunk climbs from the Clearing
## to the Canopy Walk and the Nest; the Floor Trail runs east to the Den; the Root Hollow drops from the Treeline into C4. Art is the grotto's.

func area() -> String:
	return "forest"

func prefix() -> String:
	return "FO"

func build(world: Dictionary) -> void:
	var mouth := _mouth()
	var treeline := _treeline()
	var clearing := _clearing()
	var hollow := _hollow()
	var trunk := _trunk()
	var canopy := _canopy()
	var nest := _nest()
	var trail := _trail()
	var den := _den()
	for r in [mouth, treeline, clearing, hollow, trunk, canopy, nest, trail, den]:
		world[r.id] = r
	link(world["C3"], mouth, "right", 200.0, 320.0)
	link(mouth, treeline, "right", 200.0, 320.0)
	link(treeline, clearing, "right", 200.0, 320.0)
	link(treeline, hollow, "bottom", 2860.0, 2980.0)
	link(hollow, world["C4"], "bottom", 3000.0, 3120.0, {"gate": "wall_cling"})  # a drop down; the way back up is a climb that wants the wall cling
	link(clearing, trunk, "top", 4080.0, 4240.0)  # x: the hole is 240 to 400 in both rooms (cell 6 starts at 3840)
	link(trunk, canopy, "right", -880.0, -760.0)
	link(canopy, nest, "right", -880.0, -760.0)
	link(clearing, trail, "right", 200.0, 320.0)
	link(trail, den, "right", 200.0, 320.0)

# --- FO1 the Cave Mouth: the threshold, no creatures ---
func _mouth() -> RoomDef:
	var r := AreaKit.room("FO1", "forest", Vector2i(3, 0))
	AreaKit.ledge(r, 230.0, 268.0, 110.0)
	AreaKit.decor(r, "grotto_flowers", 280.0, 268.0)
	AreaKit.decor(r, "grotto_glow_fungus", 120.0, 320.0)
	AreaKit.decor(r, "grotto_flowers", 470.0, 320.0)
	AreaKit.decor(r, "grotto_root_hang", 360.0, 20.0)
	return r

# --- FO2 the Treeline: two screens of open floor and low branches ---
func _treeline() -> RoomDef:
	var r := AreaKit.room("FO2", "forest", Vector2i(4, 0), Vector2i(2, 1))
	AreaKit.stairs(r, 100.0, 268.0, 110.0, 52.0, 3, 100.0)
	AreaKit.ledge(r, 780.0, 268.0, 110.0)
	AreaKit.ledge(r, 940.0, 216.0, 110.0)
	AreaKit.ledge(r, 1100.0, 268.0, 100.0)
	AreaKit.spawn(r, "village_goblin", 840.0, 268.0)
	AreaKit.spawn(r, "tusker_boar", 640.0, 320.0)
	AreaKit.spawn(r, "firefly_swarm", 1000.0, 190.0)
	AreaKit.decor(r, "grotto_root_hang", 200.0, 20.0)
	AreaKit.decor(r, "grotto_root_hang", 900.0, 20.0)
	AreaKit.decor(r, "grotto_flowers", 560.0, 320.0)
	AreaKit.decor(r, "grotto_glow_fungus", 1180.0, 320.0)
	AreaKit.tag(r, "moonlit")
	return r

# --- FO3 the Clearing: the hub, a pool, the way up to the trunk ---
func _clearing() -> RoomDef:
	var r := AreaKit.room("FO3", "forest", Vector2i(6, 0))
	for i in 6:  # the climb to the ceiling opening (x 240 to 400), as G1's: the last ledge stands in it
		AreaKit.ledge(r, 240.0 if i % 2 == 0 else 310.0, 274.0 - 52.0 * i, 90.0)
	AreaKit.feature(r, "glow_pool", "FO3_pool", 470.0, 320.0, {"area": "forest"})
	AreaKit.decor(r, "grotto_flowers", 330.0, 320.0)
	AreaKit.decor(r, "grotto_glow_fungus", 560.0, 320.0)
	AreaKit.tag(r, "moonlit")
	return r

# --- FO4 the Root Hollow: a pocket under the Treeline that drops into the cave ---
func _hollow() -> RoomDef:
	var r := AreaKit.room("FO4", "forest", Vector2i(4, 1))
	AreaKit.ledge(r, 100.0, 268.0, 110.0)
	AreaKit.decor(r, "grotto_root_hang", 160.0, 20.0)
	AreaKit.decor(r, "grotto_rubble", 300.0, 320.0)
	return r

# --- FO5 the Great Trunk: a shaft three screens high, a zigzag up to the canopy ---
func _trunk() -> RoomDef:
	var r := AreaKit.room("FO5", "forest", Vector2i(6, -3), Vector2i(1, 3))
	AreaKit.ledge(r, 100.0, 988.0, 100.0)  # the two ledges either side of the opening in the floor, as C5's
	AreaKit.ledge(r, 420.0, 988.0, 100.0)
	for i in range(1, 12):  # then a zigzag up, 52 a step
		AreaKit.ledge(r, 240.0 if i % 2 == 1 else 100.0, 988.0 - 52.0 * i, 100.0)
	AreaKit.ledge(r, 390.0, 364.0, 220.0)  # the last, out to the door onto the Canopy Walk (a hop up of 44)
	AreaKit.decor(r, "grotto_root_hang", 300.0, 20.0)
	AreaKit.decor(r, "grotto_flowers", 470.0, 988.0)
	AreaKit.tag(r, "moonlit")
	return r

# --- FO6 the Canopy Walk: three screens along the tops of the trees ---
func _canopy() -> RoomDef:
	var r := AreaKit.room("FO6", "forest", Vector2i(7, -3), Vector2i(3, 1))
	for i in 8:  # a run of branches, each a step (52) up or down from the last and 50 from it
		AreaKit.ledge(r, 300.0 + 170.0 * i, 268.0 if i % 2 == 0 else 216.0, 120.0)
	AreaKit.spawn(r, "firefly_swarm", 640.0, 190.0)
	AreaKit.spawn(r, "firefly_swarm", 1360.0, 190.0)
	AreaKit.spawn(r, "village_goblin", 1100.0, 320.0)
	AreaKit.decor(r, "grotto_root_hang", 600.0, 20.0)
	AreaKit.decor(r, "grotto_root_hang", 1500.0, 20.0)
	AreaKit.tag(r, "moonlit")
	return r

# --- FO7 the Nest: a dead end for the spider, rare ---
func _nest() -> RoomDef:
	var r := AreaKit.room("FO7", "forest", Vector2i(10, -3))
	AreaKit.ledge(r, 200.0, 268.0, 120.0)
	AreaKit.spawn(r, "moon_hare", 420.0, 320.0)
	AreaKit.decor(r, "grotto_root_hang", 320.0, 20.0)
	AreaKit.tag(r, "moonlit")
	return r

# --- FO8 the Floor Trail: three screens of forest floor, the wolf's ---
func _trail() -> RoomDef:
	var r := AreaKit.room("FO8", "forest", Vector2i(7, 0), Vector2i(3, 1))
	AreaKit.ledge(r, 380.0, 296.0, 90.0)
	AreaKit.ledge(r, 900.0, 296.0, 90.0)
	AreaKit.ledge(r, 1400.0, 296.0, 90.0)
	AreaKit.spawn(r, "tusker_boar", 700.0, 320.0)
	AreaKit.spawn(r, "tusker_boar", 1200.0, 320.0)
	AreaKit.spawn(r, "village_goblin", 1600.0, 320.0)
	AreaKit.decor(r, "grotto_root_hang", 500.0, 20.0)
	AreaKit.decor(r, "grotto_root_hang", 1300.0, 20.0)
	AreaKit.decor(r, "grotto_flowers", 820.0, 320.0)
	AreaKit.tag(r, "moonlit")
	return r

# --- FO9 the Den: a dead end, rare ---
func _den() -> RoomDef:
	var r := AreaKit.room("FO9", "forest", Vector2i(10, 0))
	AreaKit.spawn(r, "moon_hare", 380.0, 320.0)
	AreaKit.decor(r, "grotto_rubble", 150.0, 320.0)
	AreaKit.decor(r, "grotto_glow_fungus", 540.0, 320.0)
	return r
