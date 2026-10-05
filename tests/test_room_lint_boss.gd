extends GutTest
## Plan: boss arenas, Task 1. The room data for boss rooms (boss, tremor, glimpse) and the lint rules that go with it: a creature
## fits its room, a boss room is built the way the spec says, tremor is a fraction, a glimpse points at a real sheet.

const SCREEN := Vector2(640, 360)

func _room(id: String, extra := {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = "deep"
	for k in extra:
		r.set(k, extra[k])
	return r

func _findings(r: RoomDef, rule: String, rooms := {}) -> Array:
	var world := rooms if not rooms.is_empty() else {r.id: r}
	return RoomLint.check_room(r, world).filter(func(f): return f["rule"] == rule)

## The stone drake's sheet (after the size ladder): widest frame 108, tallest 99.
func _drake_room(platform_w: float, ceiling_bottom: float) -> RoomDef:
	var plat := Rect2(100, 280, platform_w, 40)
	var solids: Array = [plat, Rect2(60, ceiling_bottom - 30.0, 480, 30)]  # a thick slab: its underside is the nearest rock above
	return _room("T1", {"solids": solids, "spawns": [{"id": "stone_drake", "pos": Vector2(100.0 + platform_w / 2.0, 274)}]})

func test_a_big_standing_creature_needs_footing_of_twice_its_width() -> void:
	assert_eq(_findings(_drake_room(215.0, 100.0), "creature_fit").size(), 1, "215 is under 2 x 108")
	assert_eq(_findings(_drake_room(216.0, 100.0), "creature_fit").size(), 0)

func test_a_big_standing_creature_needs_clear_height_of_1_25_times_its_height() -> void:
	# the footing top is 280; the slab's underside is `ceiling_bottom`: clear height = 280 - ceiling_bottom, needed 1.25 * 99 = 123.75
	assert_eq(_findings(_drake_room(300.0, 157.0), "creature_fit").size(), 1, "123 is under 123.75")
	assert_eq(_findings(_drake_room(300.0, 156.0), "creature_fit").size(), 0, "124 is enough")

func _taratect_room(drop_rock_top: float, extra_solids := []) -> RoomDef:
	var solids: Array = [Rect2(250, drop_rock_top, 140, 30)] + extra_solids
	return _room("T1", {"solids": solids, "spawns": [{"id": "taratect", "pos": Vector2(320, 40)}]})

func test_a_ceiling_anchored_creature_is_checked_for_the_drop() -> void:
	# the taratect's widest frame is 100 and its tallest 89: the drop from the anchor (y 40) to the rock below must be 111.25
	assert_eq(_findings(_taratect_room(150.0), "creature_fit").size(), 1, "110 is short")
	assert_eq(_findings(_taratect_room(152.0), "creature_fit").size(), 0, "112 is enough, and no footing is asked of it")

func test_a_ceiling_anchored_creature_needs_twice_its_width_at_the_anchor() -> void:
	var pillars: Array = [Rect2(250, 30, 20, 40), Rect2(340, 30, 20, 40)]  # 70 px between them at the anchor's height
	assert_eq(_findings(_taratect_room(300.0, pillars), "creature_fit").size(), 1)

func test_creatures_without_a_sheet_and_fliers_and_swimmers_are_skipped() -> void:
	var cramped := Rect2(100, 300, 20, 40)
	for id in ["water_pool", "bat", "glass_eel", "pale_moth"]:
		var r := _room("T1", {"solids": [cramped], "spawns": [{"id": id, "pos": Vector2(110, 290)}]})
		assert_eq(_findings(r, "creature_fit").size(), 0, id)

## A valid arena (2 screens wide, one left door to an antechamber with a glow pool and no spawns) and the world of both rooms.
func _arena(extra := {}) -> RoomDef:
	var a := _room("ARENA", {
		"cell": Vector2i(19, 5), "size": Vector2i(2, 1),
		"exits": [{"edge": "left", "from": 240.0, "to": 320.0, "room": "ANTE"}],
		"spawns": [{"id": "taratect", "pos": Vector2(900, 40)}],
		"boss": {"creature": "taratect", "threshold": Rect2(360, 200, 40, 120)},
	})
	for k in extra:
		a.set(k, extra[k])
	return a

func _ante(extra := {}) -> RoomDef:
	var n := _room("ANTE", {
		"cell": Vector2i(18, 5),
		"exits": [{"edge": "right", "from": 240.0, "to": 320.0, "room": "ARENA"}],
		"features": [{"kind": "glow_pool", "id": "ANTE_pool", "area": "deep", "pos": Vector2(300, 320)}],
	})
	for k in extra:
		n.set(k, extra[k])
	return n

func _world(arena: RoomDef, ante: RoomDef) -> Dictionary:
	return {arena.id: arena, ante.id: ante}

func _boss_findings(arena: RoomDef, ante: RoomDef) -> Array:
	return _findings(arena, "boss_room", _world(arena, ante))

func test_the_valid_arena_is_clean() -> void:
	assert_eq(_boss_findings(_arena(), _ante()).size(), 0)
	assert_eq(_findings(_arena(), "creature_fit", _world(_arena(), _ante())).size(), 0)

func test_a_boss_room_is_two_screens_in_one_dimension() -> void:
	var small := _arena({"size": Vector2i(1, 1)})
	assert_eq(_boss_findings(small, _ante()).size(), 1)
	var tall := _arena({"size": Vector2i(1, 2), "spawns": [{"id": "taratect", "pos": Vector2(100, 40)}], "boss": {"creature": "taratect", "threshold": Rect2(360, 200, 40, 120)}})
	assert_eq(_boss_findings(tall, _ante()).size(), 0, "two screens tall counts")

func test_a_boss_room_has_exactly_one_exit() -> void:
	var two := _arena({"exits": [{"edge": "left", "from": 240.0, "to": 320.0, "room": "ANTE"}, {"edge": "right", "from": 240.0, "to": 320.0, "room": "ANTE"}]})
	assert_eq(_boss_findings(two, _ante()).size(), 1)

func test_that_exit_leads_to_a_glow_pool_room_with_no_spawns() -> void:
	var guarded := _ante({"spawns": [{"id": "toad", "pos": Vector2(200, 300)}]})
	assert_eq(_boss_findings(_arena(), guarded).size(), 1)
	var dry := _ante({"features": []})
	assert_eq(_boss_findings(_arena(), dry).size(), 1)

func test_the_boss_is_in_spawns_and_200_px_from_the_threshold() -> void:
	var missing := _arena({"spawns": []})
	assert_eq(_boss_findings(missing, _ante()).size(), 1)
	var close := _arena({"spawns": [{"id": "taratect", "pos": Vector2(500, 40)}]})  # 188 px from the threshold
	assert_eq(_boss_findings(close, _ante()).size(), 1)

func test_the_threshold_is_inside_and_320_px_from_every_exit_span() -> void:
	var near := _arena({"boss": {"creature": "taratect", "threshold": Rect2(200, 200, 40, 120)}})  # 180 px from the door
	assert_eq(_boss_findings(near, _ante()).size(), 1)
	var outside := _arena({"boss": {"creature": "taratect", "threshold": Rect2(1270, 200, 40, 120)}})
	assert_eq(_boss_findings(outside, _ante()).size(), 1)
	var edge := _arena({"boss": {"creature": "taratect", "threshold": Rect2(340, 200, 40, 120)}})  # exactly 320 from the wall's gap
	assert_eq(_boss_findings(edge, _ante()).size(), 0)

func test_the_floor_has_no_hole_and_no_water() -> void:
	var wet := _arena({"water": [Rect2(700, 300, 60, 40)]})
	assert_eq(_boss_findings(wet, _ante()).size(), 1)
	var holed := _arena({"exits": [{"edge": "bottom", "from": 240.0, "to": 320.0, "room": "ANTE"}]})
	assert_true(_boss_findings(holed, _ante()).any(func(f): return "hole in the floor" in f["text"]), "a bottom door is a hole in the floor")

func test_tremor_is_zero_to_one() -> void:
	for v in [0.0, 0.3, 1.0]:
		assert_eq(_findings(_room("T1", {"tremor": v}), "tremor_range").size(), 0, str(v))
	for v in [-0.1, 1.5]:
		assert_eq(_findings(_room("T1", {"tremor": v}), "tremor_range").size(), 1, str(v))

func test_a_glimpse_needs_a_creature_with_a_sheet_and_a_position_inside_the_room() -> void:
	var ok := _room("T1", {"glimpse": {"creature": "taratect", "pos": Vector2(300, 150), "scale": 2.0}})
	assert_eq(_findings(ok, "glimpse").size(), 0)
	var ghost := _room("T1", {"glimpse": {"creature": "ghost", "pos": Vector2(300, 150), "scale": 2.0}})
	assert_eq(_findings(ghost, "glimpse").size(), 1)
	var outside := _room("T1", {"glimpse": {"creature": "taratect", "pos": Vector2(900, 150), "scale": 2.0}})
	assert_eq(_findings(outside, "glimpse").size(), 1)
	var flat := _room("T1", {"glimpse": {"creature": "taratect", "pos": Vector2(300, 150), "scale": 0.0}})
	assert_eq(_findings(flat, "glimpse").size(), 1)

func test_boss_tremor_and_glimpse_survive_a_save_and_load() -> void:
	var r := _arena({"tremor": 0.6, "glimpse": {"creature": "taratect", "pos": Vector2(300, 150), "scale": 2.4}})
	var path := "user://test_room_boss_%d.tres" % Time.get_ticks_usec()
	assert_eq(ResourceSaver.save(r, path), OK)
	var back := load(path) as RoomDef
	assert_eq(back.boss, r.boss)
	assert_eq(back.tremor, 0.6)
	assert_eq(back.glimpse, r.glimpse)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_a_room_with_none_of_it_is_unchanged() -> void:
	var plain := _room("T1")
	assert_eq([plain.boss, plain.tremor, plain.glimpse], [{}, 0.0, {}])
	assert_eq(RoomLint.check_room(plain, {"T1": plain}).filter(func(f): return f["rule"] in ["creature_fit", "boss_room", "tremor_range", "glimpse"]).size(), 0)
