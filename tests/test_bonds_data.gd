extends GutTest
## Which creatures accept which bond: pack (a wolf bonds with it), tame (a goblin tames it), large (and it counts as a large companion).

var creatures := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _with(kind: String) -> Array:
	var out: Array = []
	for id in creatures:
		if creatures[id].bonds.has(kind):
			out.append(id)
	out.sort()
	return out

func test_pack_is_gloom_wolf_bone_hound_and_every_wolf_twin() -> void:
	var want := ["gloom_wolf", "bone_hound"]
	for id in creatures:
		if creatures[id].origin == "twin" and creatures[id].species == "wolf":
			want.append(id)
	want.sort()
	assert_eq(_with("pack"), want)
	assert_eq(want.size(), 23, "two creatures and the 21 wolf twins")

func test_tame_is_the_rat_the_wolf_the_boar_and_the_drake() -> void:
	assert_eq(_with("tame"), ["cave_rat", "gloom_wolf", "stone_drake", "tusker_boar"])

func test_large_is_the_boar_and_the_drake() -> void:
	assert_eq(_with("large"), ["stone_drake", "tusker_boar"])

func test_a_creature_that_accepts_nothing_has_no_bonds() -> void:
	for id in ["bat", "spider", "twin_undead_zombie", "twin_goblin_beastcaller", "wild_slime"]:
		assert_eq(creatures[id].bonds, [], id)

func test_the_validator_rejects_an_unknown_bond_a_duplicate_and_large_alone() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	assert_false(_has_error(DefValidator.validate(skills, _creatures_with("bat", ["tame", "large"])), "bond"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", ["hug"])), "unknown bond 'hug'"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", ["pack", "pack"])), "twice"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", ["large"])), "large"))

func _creatures_with(id: String, bonds: Array) -> Array:
	var out: Array = []
	for c in TestDefs.all_creatures():
		out.append(TestDefs.creature(id, {"bonds": bonds}) if c.id == id else c)
	return out

func _has_error(errors: PackedStringArray, part: String) -> bool:
	return Array(errors).any(func(e: String) -> bool: return e.contains(part))
