extends GutTest
## The altar feature in the world data: validated (with the perks the data holds), built into an Altar, flagged on the map, and
## compatible with saves made when altars were rebirth pools.

var dir: String

func before_each() -> void:
	dir = "user://test_altar_world_%d" % Time.get_ticks_usec()

func after_each() -> void:
	var path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(path):
		for f in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(f))
		DirAccess.remove_absolute(path)

## An altar feature in a "cave" room (the fixture room's area), so its area matches unless a test says otherwise.
func _feature(id := "G1", perk := "", area := "cave") -> Dictionary:
	return {"kind": "altar", "id": id, "area": area, "perk": perk, "pos": Vector2(60, 320)}

func _room(id: String, features: Array) -> RoomDef:
	var d := RoomDef.new()
	d.id = id
	d.area = "cave"
	d.cell = Vector2i(0, 0)
	d.size = Vector2i(1, 1)
	d.start = Vector2(50, 50)
	d.features = features
	return d

func _perks() -> Array:
	var stats := PerkDef.new()
	stats.id = "stats"
	stats.altar = "C1"
	return [stats]

func _errors(features: Array, perks = null) -> String:
	return "\n".join(WorldValidator.validate({"T1": _room("T1", features)}, [], perks))

func test_the_feature_builds_into_an_altar() -> void:
	var altar = RoomFeatures.make(_feature("G1", "stats", "grotto"), {"progress": WorldProgress.new()})
	add_child_autofree(altar)
	assert_true(altar is Altar)
	assert_eq([altar.id, altar.perk], ["G1", "stats"])

# --- the validator ---

func test_the_validator_accepts_a_good_altar() -> void:
	var errs := WorldValidator.validate({"T1": _room("T1", [_feature("C1", "stats")])}, [], _perks())
	assert_eq(errs.size(), 0, str(errs))

func test_the_validator_names_each_mistake() -> void:
	assert_string_contains(_errors([_feature("X"), _feature("X")]), "duplicate altar")
	assert_string_contains(_errors([_feature("C1"), _feature("X")]), "has two altars")
	assert_string_contains(_errors([_feature("C1", "", "deep")]), "says area 'deep' in a 'cave' room")
	assert_string_contains(_errors([_feature("C1", "nope")], _perks()), "names perk 'nope'")
	assert_string_contains(_errors([_feature("X", "stats")], _perks()), "belongs to altar 'C1'")
	assert_string_contains(_errors([{"kind": "altar", "id": "C1", "area": "cave", "perk": 3, "pos": Vector2(1, 1)}]), "perk")
	assert_string_contains(_errors([{"kind": "altar", "id": "C1", "area": "cave", "perk": ""}]), "pos")

func test_with_no_perk_list_the_perk_names_are_not_checked() -> void:
	assert_eq(WorldValidator.validate({"T1": _room("T1", [_feature("C1", "nope")])}).size(), 0)

func test_the_validator_names_malformed_altar_data_instead_of_crashing() -> void:
	assert_string_contains(_errors([{"kind": "altar", "id": "X", "area": "cave", "perk": "", "pos": "here"}]), "pos")
	assert_string_contains(_errors([{"kind": "altar", "id": 7, "area": "cave", "perk": "", "pos": Vector2(1, 1)}]), "id")
	assert_string_contains(_errors([{"kind": "altar", "id": "X", "area": "cave", "perk": []}]), "perk")

func test_the_default_altar_must_be_in_the_start_room() -> void:
	var start := _room("T1", [])
	var other := _room("T2", [_feature("C1")])
	other.cell = Vector2i(5, 5)
	other.start = RoomDef.NO_START
	assert_string_contains(str(WorldValidator.validate({"T1": start, "T2": other})), "start room")

func test_a_world_with_altars_must_hold_the_default_one() -> void:
	assert_string_contains(_errors([_feature("G1")]), "default")

func test_a_world_with_no_altar_validates() -> void:
	assert_eq(WorldValidator.validate({"T1": _room("T1", [])}).size(), 0, "small worlds have none; the shipped-world test pins C1")

func test_the_shipped_world_validates_with_the_shipped_perks() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var perks := DefLoader.load_dir("res://data/perks", "PerkDef")
	assert_eq(WorldValidator.validate(rooms, [], perks).size(), 0, str(WorldValidator.validate(rooms, [], perks)))
	var by_id := {}
	for room_id in rooms:
		for f in (rooms[room_id] as RoomDef).features:
			assert_ne(f.get("kind", ""), "rebirth_pool", "no pool is left")
			if f.get("kind", "") == "altar":
				by_id[f["id"]] = f
	assert_eq(by_id.keys().size(), 4)
	assert_eq(by_id["C1"]["perk"], "stats")
	for id in ["G1", "F1", "D1"]:
		assert_eq(by_id[id]["perk"], "", "%s has no local perk yet" % id)
	assert_false(by_id["C1"].has("kit"), "the pool kits are gone")

func test_the_game_validates_the_world_with_the_shipped_perks() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var creature_ids := DefLoader.load_dir("res://data/creatures").map(func(c: CreatureDef) -> String: return c.id)
	assert_eq(Game.world_errors(rooms, creature_ids).size(), 0, str(Game.world_errors(rooms, creature_ids)))
	assert_string_contains("\n".join(Game.world_errors({"T1": _room("T1", [_feature("C1", "nope")])}, [])), "names perk 'nope'")
	assert_eq(Game.world_errors({"T1": _room("T1", [])}, []).size(), 0, "a world with no altar validates")

# --- the map ---

func test_the_map_flags_rooms_with_an_altar_and_whether_it_is_attuned() -> void:
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

# --- saves made when altars were pools ---

func test_an_old_save_still_starts_the_right_life() -> void:
	var path := dir.path_join("profile.json")
	var old := Profile.new(path)
	old.set_section("rebirths", ["G1"])
	old.set_section("rebirth_choice", {"pool": "G1", "species": "slime"})
	assert_true(old.save())
	var reloaded := Profile.new(path)
	reloaded.reload()
	var progress := WorldProgress.new(reloaded)
	assert_true(progress.is_attuned("G1"))
	assert_eq(progress.last_choice()["pool"], "G1")
	var altars := [{"id": "G1", "area": "grotto", "room": "C3", "pos": Vector2(100, 300), "perk": "", "name": "Grotto altar"}]
	var start := Game.resolve_start(altars, {"altar": "G1", "species": "slime", "kit": {}}, progress.is_attuned)
	assert_false(start["default"])
	assert_eq(start["room"], "C3")
