extends GutTest
## SoulValidator: bad soul data is named, good data passes.

const CREATURES := ["bat", "toad", "water_pool"]

var movement_dir: String

func before_each() -> void:
	movement_dir = "user://gut_movement_%d" % randi()
	DirAccess.make_dir_recursive_absolute(movement_dir)
	var f := FileAccess.open(movement_dir.path_join("slime.tres"), FileAccess.WRITE)
	f.store_string("")
	f.close()

func after_each() -> void:
	for name in DirAccess.get_files_at(movement_dir):
		DirAccess.remove_absolute(movement_dir.path_join(name))
	DirAccess.remove_absolute(movement_dir)

func _species(id := "slime", unlock := {"kind": "default"}, profile := "slime") -> SpeciesDef:
	var d := SpeciesDef.new()
	d.id = id
	d.unlock = unlock
	d.movement_profile = profile
	return d

func _perk(id := "stats") -> PerkDef:
	var p := PerkDef.new()
	p.id = id
	p.price_base = 5
	p.price_step = 3
	p.effects = [{"stat": "max_hp", "amount": 2}]
	return p

func _lines() -> GoddessLines:
	var l := GoddessLines.new()
	l.by_cause = {"bat": ["a"], "poison": ["b"], "spear": ["c"]}
	l.many_deaths = ["m"]
	l.fallback = "f"
	return l

## Validates the good fixtures with one part swapped for a bad one (pass null to keep the good part).
func _check(species = null, perks = null, rules = null, lines = null) -> PackedStringArray:
	return SoulValidator.validate(species if species != null else [_species()], perks if perks != null else [_perk()],
		rules if rules != null else SoulRules.new(), lines if lines != null else _lines(), CREATURES, movement_dir)

func _has(errors: PackedStringArray, fragment: String) -> bool:
	for e in errors:
		if e.contains(fragment):
			return true
	return false

func test_the_good_fixtures_validate_clean() -> void:
	assert_eq(_check(), PackedStringArray())

func test_species_errors() -> void:
	assert_true(_has(_check([_species(), _species("odd", {"kind": "eat_as_form"}, "")]), "unknown unlock kind"))
	assert_true(_has(_check([_species(), _species("a", {"kind": "count", "creature": "dragon", "n": 3}, "")]), "unknown creature"))
	assert_true(_has(_check([_species(), _species("a", {"kind": "defeat", "creature": "dragon"}, "")]), "unknown creature"))
	assert_true(_has(_check([_species(), _species("a", {"kind": "count", "creature": "bat"}, "")]), "positive n"))
	assert_true(_has(_check([_species(), _species("a", {"kind": "count", "creature": "bat", "n": 0}, "")]), "positive n"))
	assert_true(_has(_check([_species(), _species()]), "duplicate species"))
	assert_true(_has(_check([_species("wolf", {"kind": "defeat", "creature": "bat"}, "")]), "default unlock"))
	assert_true(_has(_check([_species("slime", {"kind": "default"}, "ghost")]), "movement profile"))

func test_perk_errors() -> void:
	assert_true(_has(_check(null, [_perk(), _perk()]), "duplicate perk"))
	var free := _perk()
	free.price_base = 0
	assert_true(_has(_check(null, [free]), "price_base"))
	var falling := _perk()
	falling.price_step = -1
	assert_true(_has(_check(null, [falling]), "price_step"))
	var odd_stat := _perk()
	odd_stat.effects = [{"stat": "luck", "amount": 1}]
	assert_true(_has(_check(null, [odd_stat]), "unknown stat"))
	var nothing := _perk()
	nothing.effects = [{"stat": "max_hp", "amount": 0}]
	assert_true(_has(_check(null, [nothing]), "amount"))

func test_rules_errors() -> void:
	var r := SoulRules.new()
	r.bank_rate = 0
	assert_true(_has(_check(null, null, r), "bank_rate"))
	r = SoulRules.new()
	r.level_prices = []
	assert_true(_has(_check(null, null, r), "level_prices must not be empty"))
	r = SoulRules.new()
	r.level_prices = [2, 0, 4]
	assert_true(_has(_check(null, null, r), "every level price"))
	r = SoulRules.new()
	r.power_price = 0
	assert_true(_has(_check(null, null, r), "power_price"))
	r = SoulRules.new()
	r.many_deaths = 1
	assert_true(_has(_check(null, null, r), "many_deaths must"))

func test_lines_errors() -> void:
	var l := _lines()
	l.by_cause["dragon"] = ["x"]
	assert_true(_has(_check(null, null, null, l), "is not a cause"))
	l = _lines()
	l.by_cause["water_pool"] = ["x"]
	assert_true(_has(_check(null, null, null, l), "is not a cause"))
	l = _lines()
	l.by_cause["bat"] = []
	assert_true(_has(_check(null, null, null, l), "has no lines"))
	l = _lines()
	l.by_cause["bat"] = ["  "]
	assert_true(_has(_check(null, null, null, l), "blank line"))
	l = _lines()
	l.many_deaths = []
	assert_true(_has(_check(null, null, null, l), "many_deaths has no lines"))
	l = _lines()
	l.fallback = " "
	assert_true(_has(_check(null, null, null, l), "fallback"))
