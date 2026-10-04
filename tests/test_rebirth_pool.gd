extends GutTest
## The rebirth pool feature: built from room data, attuned by the player, validated, and shown on the map.

func _feature(id := "G1", kit = {}) -> Dictionary:
	return {"kind": "rebirth_pool", "id": id, "area": "grotto", "kit": kit, "pos": Vector2(60, 320)}

func _ctx(progress: WorldProgress, announced: Array) -> Dictionary:
	return {"progress": progress, "announce": func(id: String, text: String) -> void: announced.append([id, text])}

func _player() -> Node:
	var n := Node.new()
	add_child_autofree(n)
	return n

func test_the_feature_builds_from_data_and_is_interactable() -> void:
	var pool = RoomFeatures.make(_feature(), _ctx(WorldProgress.new(), []))
	add_child_autofree(pool)
	assert_true(pool is RebirthPool)
	assert_true(pool.is_in_group("interactable"))
	assert_eq(pool.position, Vector2(60, 320))
	assert_eq(pool.id, "G1")
	assert_eq(pool.prompt(), "attune")

func test_attuning_saves_the_pool_and_says_so_once() -> void:
	var progress := WorldProgress.new()
	var said: Array = []
	var pool = RoomFeatures.make(_feature(), _ctx(progress, said))
	add_child_autofree(pool)
	assert_false(progress.is_attuned("G1"))
	pool.interact(_player())
	assert_true(progress.is_attuned("G1"))
	assert_eq(said.size(), 1)
	assert_eq(pool.prompt(), "attuned")
	pool.interact(_player())
	assert_eq(said.size(), 1, "a second visit announces nothing new")
	assert_eq(progress.rebirths, ["G1"])

func test_interacting_with_the_default_pool_is_harmless() -> void:
	var progress := WorldProgress.new()
	var pool = RoomFeatures.make(_feature("C1"), _ctx(progress, []))
	add_child_autofree(pool)
	assert_eq(pool.prompt(), "attuned", "the Cave mouth is already unlocked")
	pool.interact(_player())
	assert_true(progress.is_attuned("C1"))

func test_the_pool_glows_pale_violet_not_the_glow_pools_teal() -> void:
	var pool := RebirthPool.new()
	pool.setup(_feature(), _ctx(WorldProgress.new(), []))
	add_child_autofree(pool)
	assert_gt(pool.glow_color().b, pool.glow_color().g, "violet-white, not teal")
	assert_gt(pool.glow_color().r, 0.6)

# --- the validator ---

func _room(id: String, features: Array) -> RoomDef:
	var d := RoomDef.new()
	d.id = id
	d.area = "cave"
	d.cell = Vector2i(0, 0)
	d.size = Vector2i(1, 1)
	d.start = Vector2(50, 50)
	d.features = features
	return d

func _errors(features: Array) -> String:
	return str(WorldValidator.validate({"T1": _room("T1", features)}))

func test_the_validator_accepts_a_good_pool() -> void:
	var errs := WorldValidator.validate({"T1": _room("T1", [_feature("C1"), _feature("T1", {"skills": ["leap"], "level": 3})])})
	assert_eq(errs.size(), 0, str(errs))

func test_the_validator_names_each_mistake() -> void:
	assert_string_contains(_errors([_feature("X", {}), _feature("X", {})]), "duplicate rebirth pool")
	assert_string_contains(_errors([{"kind": "rebirth_pool", "pos": Vector2(1, 1)}]), "rebirth pool")
	assert_string_contains(_errors([_feature("X", {"skills": ["no_such_skill"]})]), "unknown skill")
	assert_string_contains(_errors([_feature("X", {"skills": ["flight"]})]), "enemy-only")
	assert_string_contains(_errors([_feature("X", {"level": 0})]), "level")
	assert_string_contains(_errors([_feature("X", {"level": 11})]), "level")

func test_the_validator_names_malformed_pool_data_instead_of_crashing() -> void:
	assert_string_contains(_errors([_feature("C1"), _feature("X", [])]), "kit")
	assert_string_contains(_errors([_feature("C1"), {"kind": "rebirth_pool", "id": "X", "area": "cave", "kit": {}, "pos": "here"}]), "pos")
	assert_string_contains(_errors([_feature("C1"), {"kind": "rebirth_pool", "id": 7, "area": "cave", "kit": {}, "pos": Vector2(1, 1)}]), "id")
	assert_string_contains(_errors([_feature("C1"), _feature("X", {"skills": "leap"})]), "skills")
	assert_string_contains(_errors([_feature("C1"), _feature("X", {"skills": [3]})]), "skill")

func test_the_default_pool_must_be_in_the_start_room() -> void:
	var start := _room("T1", [])
	var other := _room("T2", [_feature("C1")])
	other.cell = Vector2i(5, 5)
	other.start = RoomDef.NO_START
	assert_string_contains(str(WorldValidator.validate({"T1": start, "T2": other})), "start room")

func test_the_shipped_world_validates_and_c1_holds_the_default_pool() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	assert_eq(WorldValidator.validate(rooms).size(), 0, str(WorldValidator.validate(rooms)))
	var found := false
	for f in (rooms["C1"] as RoomDef).features:
		if f.get("kind", "") == "rebirth_pool":
			found = true
			assert_eq(f["id"], WorldProgress.DEFAULT_POOL)
			assert_eq(f["kit"], {}, "the Cave mouth's kit is nothing")
	assert_true(found)

func test_a_world_with_pools_must_hold_the_default_one() -> void:
	var errs := WorldValidator.validate({"T1": _room("T1", [_feature("G1")])})
	assert_string_contains(str(errs), "default")

# --- the map ---

func test_the_map_flags_rooms_with_a_pool_and_whether_it_is_attuned() -> void:
	var progress := WorldProgress.new()
	progress.visit("T1")
	var rooms := {"T1": _room("T1", [_feature("G1")])}
	var m := SkillScreenModel.map_view(rooms, progress, "T1")
	assert_true(m["rooms"][0]["rebirth"])
	assert_false(m["rooms"][0]["attuned"])
	progress.attune("G1")
	assert_true(SkillScreenModel.map_view(rooms, progress, "T1")["rooms"][0]["attuned"])
	var plain := SkillScreenModel.map_view({"T1": _room("T1", [])}, progress, "T1")
	assert_false(plain["rooms"][0]["rebirth"])
