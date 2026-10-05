class_name CathedralArea
extends AreaModule
## The cathedral north of the churchyard (docs/research/area-level-design.md section 11): five rooms. A climb from the Churchyard leads up into
## the Nave, a long hall of pews; the Transept is its crossing, with the Font Chapel beside it; above the Transept the Bell Shaft climbs three
## screens to a door onto the Loft, a gallery over the Nave. Art is the cave's. The priest's emitter, the holy beams and the cover from them
## are not built: the creatures stand where the beams will fall.

func area() -> String:
	return "sacred"

func prefix() -> String:
	return "CA"

func build(world: Dictionary) -> void:
	var yard: RoomDef = world["CM2"]
	var nave := _nave()
	var transept := _transept()
	var font := _font()
	var bell := _bell()
	var loft := _loft()
	for r in [nave, transept, font, bell, loft]:
		world[r.id] = r
	AreaKit.climb(yard, 240.0, 400.0)  # the Churchyard's way up to the hole this module opens in its ceiling
	link(yard, nave, "top", 12400.0, 12560.0)  # x: 240 to 400 in both (cell 19 starts at 12160)
	link(nave, transept, "right", 1280.0, 1400.0)  # y: row 3 starts at 1080
	link(transept, font, "right", 1280.0, 1400.0)
	link(transept, bell, "top", 14320.0, 14480.0)  # 240 to 400 in both (cell 22 starts at 14080)
	link(bell, loft, "left", 200.0, 320.0)  # row 0

# --- CA1 the Nave: three screens of pews; the Churchyard's climb comes up at its west end ---
func _nave() -> RoomDef:
	var r := AreaKit.room("CA1", "sacred", Vector2i(19, 3), Vector2i(3, 1))
	AreaKit.flank(r, 240.0, 400.0)
	for i in 4:  # pews: a hop above the floor, spaced as the boardwalk's planks
		AreaKit.ledge(r, 560.0 + 330.0 * i, 268.0, 190.0)
	AreaKit.spawn(r, "candle_wisp", 640.0, 190.0)
	AreaKit.spawn(r, "candle_wisp", 1300.0, 170.0)
	AreaKit.spawn(r, "stained_glass_moth", 960.0, 120.0)
	AreaKit.spawn(r, "shield_guard", 1500.0, 320.0)
	AreaKit.spawn(r, "gargoyle", 800.0, 320.0)
	AreaKit.decor(r, "crystal_rose", 700.0, 268.0)
	AreaKit.decor(r, "crystal_gold", 1360.0, 268.0)
	AreaKit.decor(r, "crystal_prism", 1030.0, 268.0)
	AreaKit.decor(r, "stalagmite", 120.0, 320.0)
	AreaKit.decor(r, "root_hang", 900.0, 20.0)
	AreaKit.decor(r, "root_hang", 1600.0, 20.0)
	AreaKit.feature(r, "lamp", "CA1_lamp", 1150.0, 320.0)
	AreaKit.tag(r, "hold")
	return r

# --- CA2 the Transept: the crossing; the climb to the Bell Shaft rises from its floor ---
func _transept() -> RoomDef:
	var r := AreaKit.room("CA2", "sacred", Vector2i(22, 3))
	AreaKit.climb(r, 240.0, 400.0)
	AreaKit.spawn(r, "chapel_priest", 520.0, 320.0)
	AreaKit.spawn(r, "gargoyle", 130.0, 320.0)
	AreaKit.decor(r, "crystal_prism", 580.0, 320.0)
	AreaKit.decor(r, "stalagmite", 80.0, 320.0)
	return r

# --- CA3 the Font Chapel: a dead end off the Transept; a pool, and a drifter over it ---
func _font() -> RoomDef:
	var r := AreaKit.room("CA3", "sacred", Vector2i(23, 3))
	AreaKit.feature(r, "glow_pool", "CA3_pool", 360.0, 320.0, {"area": "sacred"})
	AreaKit.ledge(r, 120.0, 268.0, 110.0)
	AreaKit.spawn(r, "ghost", 480.0, 190.0)
	AreaKit.decor(r, "crystal_rose", 250.0, 320.0)
	AreaKit.decor(r, "flowers", 520.0, 320.0)
	AreaKit.decor(r, "vine", 300.0, 20.0)
	AreaKit.feature(r, "hidden", "CA3_hidden", 44.0, 320.0, {"w": 24.0, "h": 120.0})  # a door that looks like wall until revealed
	AreaKit.feature(r, "vigil", "CA3_vigil", 440.0, 320.0)
	return r

# --- CA4 the Bell Shaft: three screens up from the Transept, a zigzag to a door in the west wall ---
func _bell() -> RoomDef:
	var r := AreaKit.room("CA4", "sacred", Vector2i(22, 0), Vector2i(1, 3))
	AreaKit.flank(r, 240.0, 400.0)
	for i in range(1, 12):  # a zigzag up, 52 a step, from the Transept's hole
		AreaKit.ledge(r, 240.0 if i % 2 == 1 else 100.0, 988.0 - 52.0 * i, 100.0)
	AreaKit.ledge(r, 30.0, 364.0, 220.0)  # the last, out to the door in the west wall (a hop up of 44)
	AreaKit.spawn(r, "stained_glass_moth", 320.0, 560.0)
	AreaKit.decor(r, "root_hang", 300.0, 20.0)
	AreaKit.decor(r, "crystal_gold", 540.0, 1040.0)
	return r

# --- CA5 the Loft: a gallery over the Nave, a dead end ---
func _loft() -> RoomDef:
	var r := AreaKit.room("CA5", "sacred", Vector2i(20, 0), Vector2i(2, 1))
	for i in 4:
		AreaKit.ledge(r, 200.0 + 260.0 * i, 268.0, 160.0)
	AreaKit.spawn(r, "ghost", 600.0, 190.0)
	AreaKit.spawn(r, "candle_wisp", 1000.0, 180.0)
	AreaKit.decor(r, "crystal_prism", 300.0, 268.0)
	AreaKit.decor(r, "crystal_rose", 820.0, 268.0)
	AreaKit.decor(r, "root_hang", 640.0, 20.0)
	AreaKit.decor(r, "vine", 1100.0, 20.0)
	return r
