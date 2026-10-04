extends GutTest
## The shipped soul data: valid, complete, and wired to what exists.

func _creature_ids() -> Array:
	return DefLoader.load_dir("res://data/creatures").map(func(c: CreatureDef) -> String: return c.id)

func test_the_shipped_data_validates_clean() -> void:
	var species := DefLoader.load_dir("res://data/species", "SpeciesDef")
	var perks := DefLoader.load_dir("res://data/perks", "PerkDef")
	var rules: SoulRules = load("res://data/soul/soul_rules.tres")
	var lines: GoddessLines = load("res://data/goddess/lines.tres")
	assert_eq(SoulValidator.validate(species, perks, rules, lines, _creature_ids()), PackedStringArray())

func test_slime_is_the_default_species_with_a_movement_profile() -> void:
	var slime: SpeciesDef = load("res://data/species/slime.tres")
	assert_eq(slime.id, "slime")
	assert_eq(slime.unlock, {"kind": "default"})
	assert_true(FileAccess.file_exists("res://data/movement/%s.tres" % slime.movement_profile))

func test_every_cause_has_a_line() -> void:
	var lines: GoddessLines = load("res://data/goddess/lines.tres")
	var causes := _creature_ids().filter(func(id: String) -> bool: return id != Sources.WATER_POOL)
	causes.append_array(["poison", "spear"])
	assert_eq(causes.size(), 20)
	for cause in causes:
		assert_true(lines.by_cause.has(cause) and not lines.by_cause[cause].is_empty(), "a line for %s" % cause)

func test_the_stats_perk_is_the_caves_and_can_be_bought() -> void:
	var perk: PerkDef = load("res://data/perks/stats.tres")
	assert_eq(perk.id, "stats")
	assert_eq(perk.altar, "C1")
	var saved := SoulProgress.new(null, [perk.id])
	saved.add(20)
	assert_true(saved.buy_perk(perk))
