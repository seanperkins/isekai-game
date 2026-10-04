extends GutTest
## Which species the goddess offers: the unlock rule of each kind, read from the Bestiary records.

func _def(unlock: Dictionary, id := "x") -> SpeciesDef:
	var d := SpeciesDef.new()
	d.id = id
	d.unlock = unlock
	return d

func _count(creature: String, n: int, id := "x") -> SpeciesDef:
	return _def({"kind": "count", "creature": creature, "n": n}, id)

func test_default_is_always_unlocked() -> void:
	assert_true(SpeciesUnlocks.is_unlocked(_def({"kind": "default"}), {}))

func test_count_reads_the_larger_of_eaten_and_defeated() -> void:
	var records := {"bat": {"eaten": 3, "defeated": 3}}
	assert_true(SpeciesUnlocks.is_unlocked(_count("bat", 3), records))
	assert_false(SpeciesUnlocks.is_unlocked(_count("bat", 5), records), "a sum of 6 would wrongly pass")
	assert_false(SpeciesUnlocks.is_unlocked(_count("bat", 3), {"bat": {"eaten": 2, "defeated": 2}}))

func test_count_edges() -> void:
	var def := _count("bat", 4)
	assert_true(SpeciesUnlocks.is_unlocked(def, {"bat": {"eaten": 4, "defeated": 0}}))
	assert_true(SpeciesUnlocks.is_unlocked(def, {"bat": {"eaten": 0, "defeated": 4}}))
	assert_false(SpeciesUnlocks.is_unlocked(def, {"bat": {"eaten": 3, "defeated": 0}}), "one short")
	assert_false(SpeciesUnlocks.is_unlocked(def, {}), "no record reads as zero")
	assert_false(SpeciesUnlocks.is_unlocked(def, {"bat": {}}), "a record with no counts reads as zero")

func test_defeat_needs_a_defeat_not_an_eat() -> void:
	var def := _def({"kind": "defeat", "creature": "gloom_wolf"})
	assert_true(SpeciesUnlocks.is_unlocked(def, {"gloom_wolf": {"eaten": 0, "defeated": 1}}))
	assert_false(SpeciesUnlocks.is_unlocked(def, {"gloom_wolf": {"eaten": 4, "defeated": 0}}))

func test_unknown_kind_is_locked() -> void:
	assert_false(SpeciesUnlocks.is_unlocked(_def({"kind": "eat_as_form"}), {}))
	assert_false(SpeciesUnlocks.is_unlocked(_def({}), {}))
	assert_false(SpeciesUnlocks.is_unlocked(_def({"kind": "count", "creature": "bat"}), {"bat": {"eaten": 9}}), "a count with no n never opens")

func test_unlocked_lists_default_first_then_by_id() -> void:
	var catalog := {
		"wolf": _def({"kind": "defeat", "creature": "gloom_wolf"}, "wolf"),
		"slime": _def({"kind": "default"}, "slime"),
		"ant": _count("armed_ant", 1, "ant"),
		"spider": _count("spider", 9, "spider"),
	}
	var records := {"gloom_wolf": {"eaten": 0, "defeated": 1}, "armed_ant": {"eaten": 1, "defeated": 0}}
	var ids := SpeciesCatalog.unlocked(catalog, records).map(func(d: SpeciesDef) -> String: return d.id)
	assert_eq(ids, ["slime", "ant", "wolf"])

func test_load_all_keys_species_by_id() -> void:
	var dir := "user://gut_species_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(_def({"kind": "default"}, "slime"), dir.path_join("slime.tres"))
	ResourceSaver.save(_def({"kind": "default"}, "wolf"), dir.path_join("wolf.tres"))
	var catalog := SpeciesCatalog.load_all(dir)
	assert_eq(catalog.keys(), ["slime", "wolf"])
	assert_eq(catalog["wolf"].id, "wolf")
	assert_eq(SpeciesCatalog.load_all("user://no_such_dir_%d" % randi()), {})
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
