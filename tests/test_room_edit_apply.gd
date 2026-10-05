extends GutTest
## RoomEditModel.apply_content: replace one room's solids, water, spawns, features and decor in a single undo step, all or nothing.
## Numbers are kept exactly (the shipped rooms are mostly off the 4 px grid, which the editor's mouse snaps to but the data does not
## require), so what is checked is the rule behind each add, not the snapping.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _content(solids := [], water := [], spawns := [], features := [], decor := []) -> Dictionary:
	return {"solids": solids, "water": water, "spawns": spawns, "features": features, "decor": decor}

func _solid(rect: Rect2, hard := false) -> Dictionary:
	return {"rect": rect, "hard": hard}

func test_every_shipped_room_applies_to_itself() -> void:
	for id in ShippedRooms.IDS:
		var before := RoomEditModel.copy_room(model.rooms[id])
		var errors := model.apply_content(id, RoomSpec.content_of(model.rooms[id]))
		assert_eq(errors, [], id)
		assert_true(RoomEditModel.same_room(model.rooms[id], before), "%s is unchanged" % id)
	assert_eq(model.undo_depth(), 0, "an unchanged room pushes no undo step")
	assert_eq(model.dirty.size(), 0)

func test_replace_is_one_undo_step() -> void:
	var before := RoomEditModel.copy_room(model.rooms["C1"])
	assert_eq(model.apply_content("C1", _content([_solid(Rect2(100, 100, 40, 12))])), [])
	var r: RoomDef = model.rooms["C1"]
	assert_eq(r.solids, [Rect2(100, 100, 40, 12)])
	assert_eq([r.water, r.spawns, r.features, r.decor], [[], [], [], []])
	assert_eq([r.exits, r.dressing, r.start, r.cell, r.size, r.area], [before.exits, before.dressing, before.start, before.cell, before.size, before.area])
	assert_eq(model.undo_depth(), 1)
	assert_true(model.dirty.has("C1"))
	assert_true(model.undo())
	assert_true(RoomEditModel.same_room(model.rooms["C1"], before))

func test_atomic_and_complete() -> void:
	var before := RoomEditModel.copy_room(model.rooms["C1"])
	var bad_water := _content([_solid(Rect2(100, 100, 40, 12))], [Rect2(100, 200, 8, 8)])
	assert_eq(model.apply_content("C1", bad_water), [{"kind": "water", "index": 0, "error": "too small: water is at least 32 px each way"}])
	assert_true(RoomEditModel.same_room(model.rooms["C1"], before), "nothing was applied")
	assert_eq(model.undo_depth(), 0)
	var two := _content([], [Rect2(100, 200, 8, 8)], [{"id": "nope", "pos": Vector2(300, 100)}])
	var errors := model.apply_content("C1", two)
	assert_eq(errors.map(func(e: Dictionary) -> String: return e["kind"]), ["water", "spawn"])
	assert_eq(errors[1]["error"], "unknown creature 'nope'")

func test_numbers_are_exact_and_the_room_is_the_limit() -> void:
	assert_eq(model.apply_content("C1", _content([_solid(Rect2(1, 1, 31, 30))])), [])
	assert_eq(model.rooms["C1"].solids, [Rect2(1, 1, 31, 30)], "not snapped")
	assert_eq(model.apply_content("C1", _content([_solid(Rect2(-50, -50, 100, 100))]))[0]["error"], "outside the room")
	assert_eq(model.apply_content("C1", _content([_solid(Rect2(100, 100, 2, 12))]))[0]["error"], "too small: a solid is at least 4 px each way")
	var twice := model.apply_content("C1", _content([_solid(Rect2(100, 100, 40, 12)), _solid(Rect2(100, 100, 40, 12))]))
	assert_eq(twice, [{"kind": "solid", "index": 1, "error": "an identical solid is already there"}])

func test_hard_ledges() -> void:
	assert_eq(model.apply_content("C1", _content([_solid(Rect2(100, 100, 80, 12), true)])), [])
	assert_eq(model.rooms["C1"].hard_ledges, [Rect2(100, 100, 80, 12)])
	var thick := model.apply_content("C1", _content([_solid(Rect2(100, 100, 80, 40), true)]))
	assert_eq(thick, [{"kind": "solid", "index": 0, "error": "only a thin solid can be rock from below"}])

func test_spawns_must_be_in_open_space_inside_the_room() -> void:
	var ok_spawn := {"id": model.creature_ids[0], "pos": Vector2(300, 150)}
	assert_eq(model.apply_content("C1", _content([], [], [ok_spawn])), [])
	assert_eq(model.apply_content("C1", _content([], [], [{"id": ok_spawn["id"], "pos": Vector2(5, 5)}]))[0]["error"], "inside rock: click open space")
	assert_eq(model.apply_content("C1", _content([], [], [{"id": ok_spawn["id"], "pos": Vector2(-5, 150)}]))[0]["error"], "outside the room")

func test_features_stand_on_a_surface_and_keep_or_get_an_id() -> void:
	var f := {"kind": "glow_pool", "pos": Vector2(300, 320)}
	assert_eq(model.apply_content("C1", _content([], [], [], [f])), [])
	assert_eq(model.rooms["C1"].features[0]["id"], "c1_glow_pool_1" if not _taken("c1_glow_pool_1") else model.rooms["C1"].features[0]["id"])
	var named := {"kind": "glow_pool", "id": "c1_glow_pool_9", "pos": Vector2(300, 320)}
	assert_eq(model.apply_content("C1", _content([], [], [], [named])), [])
	assert_eq(model.rooms["C1"].features[0]["id"], "c1_glow_pool_9")
	var floating := model.apply_content("C1", _content([], [], [], [{"kind": "glow_pool", "pos": Vector2(300, 200)}]))
	assert_eq(floating[0]["kind"], "feature")
	assert_true(floating[0]["error"].contains("surface"), floating[0]["error"])
	assert_eq(model.apply_content("C1", _content([], [], [], [{"kind": "banner", "pos": Vector2(300, 320)}]))[0]["error"], "unknown feature 'banner'")

func _taken(id: String) -> bool:
	for rid in model.rooms:
		for f in (model.rooms[rid] as RoomDef).features:
			if f.get("id", "") == id and rid != "C1":
				return true
	return false

func test_decor_is_known_and_stands_on_a_surface() -> void:
	assert_eq(model.apply_content("C1", _content([], [], [], [], [{"id": "rubble", "pos": Vector2(250, 320)}])), [])
	assert_eq(model.apply_content("C1", _content([], [], [], [], [{"id": "zzz", "pos": Vector2(250, 320)}]))[0]["error"], "unknown decor 'zzz'")
	assert_true(model.apply_content("C1", _content([], [], [], [], [{"id": "rubble", "pos": Vector2(250, 200)}]))[0]["error"].contains("surface"))

func test_an_unknown_room_is_reported() -> void:
	assert_eq(model.apply_content("Z9", _content()), [{"kind": "room", "index": -1, "error": "no room 'Z9'"}])

# --- found by the final review: malformed optional fields must not reach a saved room ---

func test_feature_fields_must_be_the_right_type_and_value() -> void:
	var pos := Vector2(300, 320)
	var cases := [
		[{"kind": "tablet", "pos": pos, "title": []}, "title"],
		[{"kind": "tablet", "pos": pos, "title": "T", "hint": [1]}, "hint"],
		[{"kind": "tablet", "pos": pos, "title": "T", "hint": "no_such_skill"}, "not a skill"],
		[{"kind": "tablet", "pos": pos, "title": ""}, "needs a title"],
		[{"kind": "switch", "pos": pos, "shortcut": []}, "shortcut"],
		[{"kind": "switch", "pos": pos, "shortcut": "a b"}, "shortcut"],
		[{"kind": "altar", "pos": pos, "perk": "no_such_perk"}, "not a perk"],
		[{"kind": "altar", "pos": pos, "perk": 3}, "perk"],
		[{"kind": "glow_pool", "pos": pos, "title": "x"}, "has no title"],
		[{"kind": "glow_pool", "pos": pos, "id": []}, "id"],
	]
	for c: Array in cases:
		var errors := model.apply_content("C1", _content([], [], [], [c[0]]))
		assert_eq(errors.size(), 1, str(c[0]))
		assert_eq(errors[0]["kind"], "feature", str(c[0]))
		assert_true(errors[0]["error"].contains(c[1]), "%s -> %s" % [c[0], errors[0]["error"]])
	assert_eq(model.undo_depth(), 0, "nothing was applied")

func test_good_feature_fields_are_accepted_and_a_tablet_gets_a_default_title() -> void:
	var pos := Vector2(300, 320)
	assert_eq(model.apply_content("C1", _content([], [], [], [{"kind": "tablet", "pos": pos}])), [])
	assert_eq(model.rooms["C1"].features[0]["title"], "Tablet")
	assert_eq(model.apply_content("C1", _content([], [], [], [{"kind": "switch", "pos": pos, "shortcut": "gate_1"}])), [])
	assert_eq(model.apply_content("C1", _content([], [], [], [{"kind": "altar", "pos": pos, "perk": ""}])), [])

func test_decor_anchor_must_be_top_or_bottom() -> void:
	var bad := model.apply_content("C1", _content([], [], [], [], [{"id": "rubble", "pos": Vector2(250, 320), "anchor": "sideways"}]))
	assert_eq(bad.size(), 1)
	assert_true(bad[0]["error"].contains("anchor"), bad[0]["error"])
	var bad_type := model.apply_content("C1", _content([], [], [], [], [{"id": "rubble", "pos": Vector2(250, 320), "anchor": []}]))
	assert_true(bad_type[0]["error"].contains("anchor"), bad_type[0]["error"])

# --- found by the final review: queued deletions ---

func test_save_dirty_with_an_empty_only_writes_nothing_but_still_removes() -> void:
	var tmp := "res://.tmp/room_edit_apply_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(tmp))
	assert_eq(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	assert_eq(model.save_dirty(tmp)["saved"].size(), 2)
	model.undo()
	var result := model.save_dirty(tmp, [], ["Fresh"])
	assert_eq(result["removed"], [], "a spared removal stays queued")
	assert_true(FileAccess.file_exists("%s/Fresh.tres" % tmp))
	result = model.save_dirty(tmp, [])
	assert_eq(result["saved"], [], "an empty `only` writes no room")
	assert_eq(result["removed"], ["Fresh"])
	assert_true(model.dirty.has("C6"), "C6 was not named, so it is still unsaved")
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [tmp, f]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
