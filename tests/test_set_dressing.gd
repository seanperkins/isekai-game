extends GutTest
## Per-room set dressing: props placed at their authored spot when the camera is on them, drifting
## at their depth elsewhere, always behind the terrain and creatures, and never a crash on bad data.

const VIEW := Vector2(640, 360)

func before_each() -> void:
	# a tiny test library so the builder and validator do not depend on the real art
	DressingLib._manifests["test"] = {"pieces": {
		"pole": {"size": [10, 40], "anchor": "top"},
		"rock": {"size": [20, 12], "anchor": "bottom"},
		"orb": {"size": [16, 16], "anchor": "center"}}}
	for p in DressingLib._manifests["test"]["pieces"]:
		var sz: Array = DressingLib._manifests["test"]["pieces"][p]["size"]
		DressingLib._textures["test/" + p] = ImageTexture.create_from_image(Image.create(int(sz[0]), int(sz[1]), false, Image.FORMAT_RGBA8))

func after_each() -> void:
	DressingLib._manifests.erase("test")
	for p in ["pole", "rock", "orb"]:
		DressingLib._textures.erase("test/" + p)

# --- follow math ---

func test_factor_one_moves_with_the_world_and_factor_zero_stays_on_the_screen() -> void:
	var pos := Vector2(500, 300)
	assert_eq(SetDressing.prop_position(pos, Vector2(120, 80), 1.0), pos, "the world does not move with the camera")
	assert_eq(SetDressing.prop_position(pos, Vector2(120, 80), 0.0), Vector2(120, 80), "glued to the camera")
	assert_eq(SetDressing.prop_position(pos, Vector2(100, 100), 0.5), Vector2(300, 200), "halfway")

func test_a_prop_is_exactly_at_its_position_when_the_camera_is_on_it() -> void:
	for f in [0.1, 0.4, 0.9]:
		assert_eq(SetDressing.prop_position(Vector2(700, 900), Vector2(700, 900), f), Vector2(700, 900))

func test_a_farther_prop_lags_behind_the_world_on_both_axes() -> void:
	var pos := Vector2(500, 500)
	var near := SetDressing.prop_position(pos, Vector2(0, 0), 0.8)
	var far := SetDressing.prop_position(pos, Vector2(0, 0), 0.2)
	assert_lt(far.x, near.x)
	assert_lt(far.y, near.y)
	# the camera goes down 100, so the world moves up 100 on the screen; a factor-0.25 prop moves up only 25
	var a := SetDressing.prop_position(pos, Vector2(0, 0), 0.25)
	var b := SetDressing.prop_position(pos, Vector2(0, 100), 0.25)
	assert_almost_eq((b.y - 100.0) - a.y, -25.0, 0.001, "on screen it moved 25 px while the world moved 100")

# --- depth ---

func test_props_always_draw_behind_terrain_and_actors_and_nearer_ones_draw_later() -> void:
	var last := -1000
	for f in [0.1, 0.25, 0.5, 0.75, 0.9]:
		var z := SetDressing.z_for(f)
		assert_lt(z, 0, "factor %.2f draws behind the play plane (z 0)" % f)
		assert_gte(z, last)
		last = z
	assert_lt(SetDressing.z_for(0.1), SetDressing.z_for(0.9))
	assert_lt(SetDressing.z_for(5.0), 0, "a bad factor still cannot reach the play plane")
	assert_lt(SetDressing.z_for(-3.0), 0)

func test_far_props_are_hazier_and_brighter_near_props_darker_so_the_play_plane_reads() -> void:
	var haze := Color(0.8, 0.75, 1.0)
	var far := SetDressing.tint(0.1, haze)
	var near := SetDressing.tint(0.9, haze)
	assert_lt(far.a, near.a, "distance thins a prop into the fog")
	assert_gt(far.v, near.v, "and near props are dimmed")

# --- the builder ---

func _room(pos := Vector2(1000, 500)) -> Node2D:
	var room := Node2D.new()
	room.position = pos
	add_child_autofree(room)
	return room

func test_the_builder_makes_one_sprite_per_valid_entry_under_a_dressing_node() -> void:
	var room := _room()
	var node := SetDressing.build(room, "test", [
		{"piece": "pole", "pos": Vector2(100, 40), "factor": 0.3},
		{"piece": "rock", "pos": Vector2(300, 200), "factor": 0.6, "flip": true}])
	assert_not_null(node)
	assert_eq(node.name, "Dressing")
	assert_eq(node.get_parent(), room)
	assert_eq(node.get_child_count(), 2)

func test_anchors_place_the_sprite_relative_to_its_position() -> void:
	var room := _room()
	var node := SetDressing.build(room, "test", [
		{"piece": "pole", "pos": Vector2(100, 100), "factor": 0.5},
		{"piece": "rock", "pos": Vector2(200, 100), "factor": 0.5},
		{"piece": "orb", "pos": Vector2(300, 100), "factor": 0.5}])
	var pole: Sprite2D = node.get_child(0)
	var rock: Sprite2D = node.get_child(1)
	var orb: Sprite2D = node.get_child(2)
	assert_eq(pole.offset.y, 20.0, "a top-anchored piece hangs from its position")
	assert_eq(rock.offset.y, -6.0, "a bottom-anchored piece stands on it")
	assert_eq(orb.offset, Vector2.ZERO, "a centre-anchored piece is centred on it")

func test_a_flipped_entry_is_mirrored() -> void:
	var room := _room()
	var node := SetDressing.build(room, "test", [
		{"piece": "rock", "pos": Vector2(0, 0), "factor": 0.5, "flip": true},
		{"piece": "rock", "pos": Vector2(0, 0), "factor": 0.5}])
	assert_true((node.get_child(0) as Sprite2D).flip_h)
	assert_false((node.get_child(1) as Sprite2D).flip_h)

func test_props_sit_at_their_position_when_the_camera_is_on_them() -> void:
	var room := _room(Vector2(1000, 500))
	var node := SetDressing.build(room, "test", [{"piece": "orb", "pos": Vector2(100, 100), "factor": 0.4}])
	node.follow(Vector2(1100, 600))  # the prop's world position
	assert_eq((node.get_child(0) as Sprite2D).global_position, Vector2(1100, 600))
	node.follow(Vector2(1100, 800))  # the camera went 200 down; the prop lags: it moved 0.4 of the way
	assert_almost_eq((node.get_child(0) as Sprite2D).global_position.y, 800.0 + 0.4 * (600.0 - 800.0), 0.001)

func test_props_are_unlit_top_level_and_behind_everything() -> void:
	var room := _room()
	var node := SetDressing.build(room, "test", [{"piece": "orb", "pos": Vector2(0, 0), "factor": 0.3}])
	var s: Sprite2D = node.get_child(0)
	assert_true(s.top_level)
	assert_lt(s.z_index, 0)
	assert_eq(s.light_mask, SetDressing.UNLIT_MASK)

func test_bad_entries_are_skipped_without_a_crash() -> void:
	var room := _room()
	var node := SetDressing.build(room, "test", [
		{"piece": "no_such_piece", "pos": Vector2(0, 0), "factor": 0.5},
		{"piece": "pole", "pos": Vector2(0, 0)},                       # no factor
		{"pole": 1},
		{"piece": "orb", "pos": Vector2(5, 5), "factor": 0.5}])
	assert_eq(node.get_child_count(), 1, "only the good one")

func test_a_biome_with_no_library_builds_nothing() -> void:
	var room := _room()
	assert_null(SetDressing.build(room, "no_such_biome", [{"piece": "pole", "pos": Vector2.ZERO, "factor": 0.5}]))
	assert_eq(room.get_child_count(), 0)

func test_no_more_than_the_cap_are_built() -> void:
	var room := _room()
	var many: Array = []
	for i in SetDressing.MAX_PROPS + 15:
		many.append({"piece": "orb", "pos": Vector2(i * 10, 0), "factor": 0.5})
	var node := SetDressing.build(room, "test", many)
	assert_eq(node.get_child_count(), SetDressing.MAX_PROPS)

func test_a_prop_far_outside_the_view_is_hidden_and_a_visible_one_is_shown() -> void:
	var room := _room(Vector2(0, 0))
	var node := SetDressing.build(room, "test", [
		{"piece": "orb", "pos": Vector2(100, 100), "factor": 0.5},
		{"piece": "orb", "pos": Vector2(5000, 100), "factor": 0.5}])
	node.follow(Vector2(100, 100))
	assert_true((node.get_child(0) as Sprite2D).visible)
	assert_false((node.get_child(1) as Sprite2D).visible)

func test_rebuilding_a_room_leaves_no_old_dressing_behind() -> void:
	var first := _room(Vector2(0, 0))
	SetDressing.build(first, "test", [{"piece": "orb", "pos": Vector2.ZERO, "factor": 0.5}])
	first.free()
	var second := _room(Vector2(0, 0))
	SetDressing.build(second, "test", [{"piece": "orb", "pos": Vector2.ZERO, "factor": 0.5}])
	var count := 0
	for n in get_children():
		for c in n.get_children():
			if c is SetDressing:
				count += 1
	assert_eq(count, 1)

# --- the library and the validator ---

func test_the_library_reports_pieces_sizes_and_anchors() -> void:
	assert_true(DressingLib.has_biome("test"))
	assert_false(DressingLib.has_biome("nowhere"))
	assert_eq(DressingLib.piece_names("test").size(), 3)
	assert_eq(DressingLib.size("test", "pole"), Vector2(10, 40))
	assert_eq(DressingLib.anchor("test", "rock"), "bottom")
	assert_null(DressingLib.texture("test", "no_such_piece"))

func _def(dressing: Array) -> RoomDef:
	var d := RoomDef.new()
	d.id = "T1"
	d.area = "test"
	d.cell = Vector2i(0, 0)
	d.size = Vector2i(1, 1)
	d.start = Vector2(50, 50)
	d.dressing = dressing
	return d

func test_the_validator_accepts_good_dressing() -> void:
	var errs := WorldValidator.validate({"T1": _def([{"piece": "pole", "pos": Vector2(100, 40), "factor": 0.3}])})
	assert_eq(errs.size(), 0, str(errs))

func test_the_validator_names_each_kind_of_mistake() -> void:
	var cases := {
		"unknown piece": {"piece": "nope", "pos": Vector2(10, 10), "factor": 0.3},
		"factor": {"piece": "pole", "pos": Vector2(10, 10), "factor": 1.4},
		"factor low": {"piece": "pole", "pos": Vector2(10, 10), "factor": 0.0},
		"outside": {"piece": "pole", "pos": Vector2(5000, 10), "factor": 0.3},
		"missing": {"piece": "pole"}}
	for k in cases:
		var errs := WorldValidator.validate({"T1": _def([cases[k]])})
		assert_gt(errs.size(), 0, k)
		assert_true(str(errs).contains("T1"), "%s: names the room" % k)
		assert_true(str(errs).contains("dressing"), "%s: says it is dressing" % k)

func test_the_validator_rejects_too_many_props_and_dressing_with_no_library() -> void:
	var many: Array = []
	for i in SetDressing.MAX_PROPS + 1:
		many.append({"piece": "orb", "pos": Vector2(i, 10), "factor": 0.5})
	assert_gt(WorldValidator.validate({"T1": _def(many)}).size(), 0)
	var d := _def([{"piece": "orb", "pos": Vector2(10, 10), "factor": 0.5}])
	d.area = "nowhere"
	assert_gt(WorldValidator.validate({"T1": d}).size(), 0, "no piece library for that biome")
	assert_eq(WorldValidator.validate({"T1": _def([])}).size(), 0, "no dressing is fine")
