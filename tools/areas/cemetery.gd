class_name CemeteryArea
extends AreaModule
## The cemetery above the Deep (docs/research/area-level-design.md section 11): three rooms. D7, the antechamber of the Taratect's arena, opens
## upward onto the Gate Tunnel (the way up wants the wall cling, the label D7's own way in carries); the Churchyard is the truce, a pool and a
## tablet and nothing hostile; the Lych Gate leads east to the crypt. The cathedral opens above the Churchyard and the crypt beyond the Lych Gate
## (the later modules make those exits). Art is the cave's. Holy and safe zones are art and text until a later piece gives them rules.

func area() -> String:
	return "cemetery"

func prefix() -> String:
	return "CM"

func build(world: Dictionary) -> void:
	var tunnel := _tunnel()
	var churchyard := _churchyard()
	var lych := _lych()
	for r in [tunnel, churchyard, lych]:
		world[r.id] = r
	link(world["D7"], tunnel, "top", 11820.0, 11980.0, {"gate": "wall_cling"})  # x: 300 to 460 in both (cell 18 starts at 11520)
	link(tunnel, churchyard, "right", 1640.0, 1760.0)  # y: row 4 starts at 1440
	link(churchyard, lych, "right", 1640.0, 1760.0)

# --- CM1 the Gate Tunnel: a short tunnel over D7; the climb out of D7 lands beside its hole ---
func _tunnel() -> RoomDef:
	var r := AreaKit.room("CM1", "cemetery", Vector2i(18, 4))
	AreaKit.flank(r, 300.0, 460.0)
	AreaKit.spawn(r, "skeleton", 540.0, 320.0)
	AreaKit.spawn(r, "carrion_crow", 120.0, 320.0)
	AreaKit.decor(r, "root_hang", 160.0, 20.0)
	AreaKit.decor(r, "root_hang", 520.0, 20.0)
	AreaKit.decor(r, "rubble", 90.0, 320.0)
	return r

# --- CM2 the Churchyard: the hub, a truce; no creature stands here ---
func _churchyard() -> RoomDef:
	var r := AreaKit.room("CM2", "cemetery", Vector2i(19, 4), Vector2i(2, 1))
	AreaKit.feature(r, "glow_pool", "CM2_pool", 700.0, 320.0, {"area": "cemetery"})
	AreaKit.feature(r, "tablet", "CM2_tablet", 860.0, 320.0, {"title": "Weathered tablet", "text": "The living and the dead keep this ground in truce. Beyond the lych gate the dead keep their own counsel."})
	AreaKit.ledge(r, 1000.0, 268.0, 120.0)
	AreaKit.decor(r, "flowers", 560.0, 320.0)
	AreaKit.decor(r, "flowers", 960.0, 320.0)
	AreaKit.decor(r, "stalagmite", 120.0, 320.0)
	AreaKit.decor(r, "stalagmite", 1200.0, 320.0)
	AreaKit.decor(r, "root_hang", 640.0, 20.0)
	AreaKit.decor(r, "vine", 1100.0, 20.0)
	return r

# --- CM3 the Lych Gate: the churchyard's east gate; a drifter over the road to the crypt ---
func _lych() -> RoomDef:
	var r := AreaKit.room("CM3", "cemetery", Vector2i(21, 4))
	AreaKit.ledge(r, 240.0, 268.0, 140.0)
	AreaKit.spawn(r, "ghost", 420.0, 190.0)
	AreaKit.spawn(r, "skeleton", 520.0, 320.0)
	AreaKit.decor(r, "stalagmite", 120.0, 320.0)
	AreaKit.decor(r, "rubble", 560.0, 320.0)
	AreaKit.decor(r, "vine", 320.0, 20.0)
	return r
