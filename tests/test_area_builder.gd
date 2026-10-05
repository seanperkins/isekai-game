extends GutTest
## The builder: it loads the hand-authored rooms, lets each area module build and attach, checks the whole world, and serializes rooms so
## that a re-run changes nothing.

class TestArea extends AreaModule:
	func area() -> String:
		return "forest"
	func prefix() -> String:
		return "ZZ"
	func build(world: Dictionary) -> void:
		var r := AreaKit.room("ZZ1", "forest", Vector2i(2, -1))
		AreaKit.spawn(r, "bat", 500.0, AreaKit.floor_y(r))  # not over the hole the link below leaves in the floor
		world["ZZ1"] = r
		AreaKit.link(world["C3"], r, "top", 1480.0, 1600.0)

## A module that changes a shipped room in place (a spawn): the copy it gets must not be the cached resource.
class AddsASpawn extends AreaModule:
	func prefix() -> String:
		return "QQ"
	func build(world: Dictionary) -> void:
		AreaKit.spawn(world["C6"], "bat", 100.0, 320.0)

var dir: String

func before_each() -> void:
	dir = "user://area_builder_%d" % Time.get_ticks_usec()

func after_each() -> void:
	AreaBuilder.tmp_path = AreaBuilder.DEFAULT_TMP_PATH
	var abs := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)

func _write(world: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for id in world:
		var f := FileAccess.open("%s/%s.tres" % [dir, id], FileAccess.WRITE)
		f.store_string(AreaBuilder.serialize(world[id]))
		f.close()

# --- serializing ---

func test_every_shipped_room_survives_a_serialize_and_a_load() -> void:
	var world := World.load_rooms(AreaBuilder.ROOMS_DIR)
	_write(world)
	for id in ShippedRooms.IDS:
		var back: RoomDef = ResourceLoader.load("%s/%s.tres" % [dir, id], "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_true(AreaBuilder.same(back, world[id]), id)

func test_same_sees_a_difference_in_any_property() -> void:
	var a := AreaKit.room("ZZ1", "forest", Vector2i(0, -1))
	var b := AreaKit.room("ZZ1", "forest", Vector2i(0, -1))
	assert_true(AreaBuilder.same(a, b))
	AreaKit.spawn(b, "bat", 100.0, 320.0)
	assert_false(AreaBuilder.same(a, b))
	b = AreaKit.room("ZZ1", "forest", Vector2i(0, -2))
	assert_false(AreaBuilder.same(a, b))

func test_serializing_pins_the_scripts_resource_id() -> void:
	var text := AreaBuilder.serialize(AreaKit.room("ZZ9", "forest", Vector2i(0, -5)))
	assert_string_contains(text, 'id="%s"' % AreaBuilder.SCRIPT_ID)
	assert_string_contains(text, 'ExtResource("%s")' % AreaBuilder.SCRIPT_ID)

func test_a_built_room_loads_back_as_the_same_room() -> void:
	var r := AreaKit.room("ZZ9", "forest", Vector2i(0, -5), Vector2i(2, 1))
	AreaKit.ledge(r, 60.0, 268.0, 100.0)
	AreaKit.spawn(r, "bat", 100.0, 320.0)
	AreaKit.decor(r, "glow_fungus", 200.0, 320.0, {"light": Color(0.5, 1, 0.6, 1)})
	AreaKit.feature(r, "glow_pool", "ZZ_POOL", 300.0, 320.0)
	r.exits.append({"edge": "left", "from": 100.0, "to": 180.0, "room": "ZZ8"})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/ZZ9.tres" % dir
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(AreaBuilder.serialize(r))
	f.close()
	var back: RoomDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(back.id, "ZZ9")
	assert_eq(back.area, "forest")
	assert_eq(back.cell, Vector2i(0, -5))
	assert_eq(back.size, Vector2i(2, 1))
	assert_eq(back.solids, r.solids)
	assert_eq(back.spawns, r.spawns)
	assert_eq(back.decor, r.decor)
	assert_eq(back.features, r.features)
	assert_eq(back.exits, r.exits)

# --- building ---

func test_the_shipped_world_has_no_problems_and_nothing_to_write() -> void:
	var world := AreaBuilder.build_with([])
	assert_eq(Array(AreaBuilder.problems(world)), [])
	assert_eq(AreaBuilder.stale(world), [])

func test_a_module_adds_its_room_and_attaches_it() -> void:
	var world := AreaBuilder.build_with([TestArea.new()])
	assert_true(world.has("ZZ1"))
	var top := (world["C3"] as RoomDef).exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "top")
	assert_eq(top.size(), 1)
	assert_eq(top[0]["room"], "ZZ1")
	assert_eq(Array(AreaBuilder.problems(world)), [])

func test_stale_lists_the_new_room_and_the_room_the_attach_touched_and_nothing_else() -> void:
	var world := AreaBuilder.build_with([TestArea.new()])
	var ids := AreaBuilder.stale(world)
	ids.sort()
	assert_eq(ids, ["C3", "ZZ1"])

func test_a_rebuild_from_what_was_written_is_the_same_world() -> void:
	var first := AreaBuilder.build_with([TestArea.new()])
	_write(first)
	var second := AreaBuilder.build_with([TestArea.new()], dir)
	assert_eq(second.keys().size(), first.keys().size())
	for id in first:
		assert_eq(AreaBuilder.serialize(second[id]), AreaBuilder.serialize(first[id]), id)
	assert_eq(AreaBuilder.stale(second, dir), [])

func test_a_generated_rooms_attach_is_not_added_twice() -> void:
	var first := AreaBuilder.build_with([TestArea.new()])
	_write(first)
	var second := AreaBuilder.build_with([TestArea.new()], dir)
	assert_eq((second["C3"] as RoomDef).exits.size(), (first["C3"] as RoomDef).exits.size())

func test_building_does_not_change_the_rooms_other_code_holds() -> void:
	var held: RoomDef = World.load_rooms(AreaBuilder.ROOMS_DIR)["C3"]
	var before := held.exits.size()
	AreaBuilder.build_with([TestArea.new()])
	assert_eq(held.exits.size(), before, "the C3 another holder has is as shipped")

func test_a_module_that_adds_to_a_shipped_room_adds_to_a_copy() -> void:
	var held: RoomDef = World.load_rooms(AreaBuilder.ROOMS_DIR)["C6"]  # held, so the loader's cache returns this very instance
	var before := held.spawns.size()
	var world := AreaBuilder.build_with([AddsASpawn.new()])
	assert_eq((world["C6"] as RoomDef).spawns.size(), before + 1)
	assert_eq(held.spawns.size(), before, "the room another holder has is untouched")

func test_a_generated_room_no_module_builds_any_more_is_gone_and_a_hand_made_one_stays() -> void:
	var first := AreaBuilder.build_with([TestArea.new()])
	_write(first)
	var stale := AreaKit.room("ZZ2", "forest", Vector2i(4, -3))
	var hand := AreaKit.room("ZZX", "forest", Vector2i(6, -3))
	var f := FileAccess.open("%s/ZZ2.tres" % dir, FileAccess.WRITE)
	f.store_string(AreaBuilder.serialize(stale))
	f.close()
	f = FileAccess.open("%s/ZZX.tres" % dir, FileAccess.WRITE)
	f.store_string(AreaBuilder.serialize(hand))
	f.close()
	var world := AreaBuilder.build_with([TestArea.new()], dir)
	assert_false(world.has("ZZ2"), "a ZZ<digits> room the module no longer builds is dropped")
	assert_true(world.has("ZZX"), "ZZX is not ZZ and digits, so it is someone's own")
	assert_true(world.has("ZZ1"))

# --- writing safely ---

func test_a_save_that_fails_serializes_to_nothing() -> void:
	AreaBuilder.tmp_path = "res://no_such_directory/x.tres"
	assert_eq(AreaBuilder.serialize(AreaKit.room("ZZ9", "forest", Vector2i(0, -5))), "")
	assert_engine_error("Cannot save file")

func test_write_writes_every_room_and_reports_no_error() -> void:
	var world := AreaBuilder.build_with([TestArea.new()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	assert_eq(AreaBuilder.write(world, ["ZZ1", "C3"], dir), PackedStringArray())
	assert_true(FileAccess.file_exists("%s/ZZ1.tres" % dir))
	assert_true(FileAccess.file_exists("%s/C3.tres" % dir))

func test_a_room_that_cannot_be_serialized_stops_the_whole_write_and_leaves_every_file_as_it_was() -> void:
	var world := AreaBuilder.build_with([TestArea.new()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var keep := FileAccess.open("%s/C3.tres" % dir, FileAccess.WRITE)
	keep.store_string("keep me")
	keep.close()
	AreaBuilder.tmp_path = "res://no_such_directory/x.tres"
	var errors := AreaBuilder.write(world, ["ZZ1", "C3"], dir)
	assert_engine_error("Cannot save file")  # one for each room it tried
	assert_engine_error("Cannot save file")
	assert_eq(errors.size(), 2, "each room that could not be serialized is named")
	assert_eq(FileAccess.get_file_as_string("%s/C3.tres" % dir), "keep me", "not truncated")
	assert_false(FileAccess.file_exists("%s/ZZ1.tres" % dir))

func test_a_room_id_that_is_not_a_plain_id_is_a_problem_and_is_never_written() -> void:
	var world := AreaBuilder.build_with([TestArea.new()])
	var bad := AreaKit.room("../ZZ1", "forest", Vector2i(8, -3))
	world["../ZZ1"] = bad
	assert_string_contains("\n".join(AreaBuilder.problems(world)), "../ZZ1: not a plain room id")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var errors := AreaBuilder.write(world, ["../ZZ1"], dir)
	assert_gt(errors.size(), 0)
	assert_false(FileAccess.file_exists("%s/../ZZ1.tres" % dir))

func test_a_generated_file_no_module_builds_any_more_is_an_orphan_and_removing_it_removes_the_file() -> void:
	var first := AreaBuilder.build_with([TestArea.new()])
	_write(first)
	for id in ["ZZ2", "ZZX"]:  # ZZ2 is generated by the module's prefix and no longer built; ZZX is someone's own
		var f := FileAccess.open("%s/%s.tres" % [dir, id], FileAccess.WRITE)
		f.store_string(AreaBuilder.serialize(AreaKit.room(id, "forest", Vector2i(4, -3))))
		f.close()
	var mods := [TestArea.new()]
	var world := AreaBuilder.build_with(mods, dir)
	assert_eq(AreaBuilder.orphans(world, mods, dir), ["ZZ2"])
	AreaBuilder.remove(["ZZ2"], dir)
	assert_false(FileAccess.file_exists("%s/ZZ2.tres" % dir))
	assert_true(FileAccess.file_exists("%s/ZZX.tres" % dir))
	assert_eq(AreaBuilder.orphans(world, mods, dir), [])

func test_only_a_generated_id_is_ever_listed_for_removal_whatever_the_world_lacks() -> void:
	var first := AreaBuilder.build_with([TestArea.new()])
	_write(first)
	var f := FileAccess.open("%s/ZZX.tres" % dir, FileAccess.WRITE)
	f.store_string(AreaBuilder.serialize(AreaKit.room("ZZX", "forest", Vector2i(6, -3))))
	f.close()
	var thin := {"ZZ1": first["ZZ1"]}  # a world that lacks C3 and ZZX, as one built from a file that failed to load would
	assert_eq(AreaBuilder.orphans(thin, [TestArea.new()], dir), [], "C3 and ZZX are not generated ids, so they are never offered for deletion")

func test_a_file_that_cannot_be_opened_is_an_error_not_a_crash() -> void:
	var world := AreaBuilder.build_with([TestArea.new()])
	var errors := AreaBuilder.write(world, ["ZZ1"], "res://no_such_directory")
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "could not be opened")

# --- problems ---

func test_problems_name_an_overlap_an_unmatched_exit_and_an_unreachable_ledge() -> void:
	var world := World.load_rooms(AreaBuilder.ROOMS_DIR)
	var over := AreaKit.room("ZZ1", "forest", (world["C3"] as RoomDef).cell)  # on top of C3
	world["ZZ1"] = over
	var lonely := AreaKit.room("ZZ2", "forest", Vector2i(2, -3))
	lonely.exits.append({"edge": "right", "from": 100.0, "to": 180.0, "room": "ZZ3"})
	world["ZZ2"] = lonely
	var high := AreaKit.room("ZZ4", "forest", Vector2i(4, -3))
	AreaKit.ledge(high, 60.0, 100.0, 100.0)
	world["ZZ4"] = high
	var text := "\n".join(AreaBuilder.problems(world))
	assert_string_contains(text, "overlaps")
	assert_string_contains(text, "ZZ2")
	assert_string_contains(text, "ledge_reach")
