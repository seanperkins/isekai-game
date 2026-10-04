extends GutTest
## Goddess bundles the soul inputs and builds the scene's model and her line for a death.

const P := GoddessModel.Pane

var skills: Array
var creatures: Array
var compendium: CompendiumModel

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	creatures = DefLoader.load_dir("res://data/creatures")
	compendium = CompendiumModel.new(skills, creatures)

func _pools() -> Array:
	return [{"id": "C1", "area": "cave", "room": "C1", "pos": Vector2(140, 320), "kit": {}, "name": "Cave mouth"},
		{"id": "G1", "area": "grotto", "room": "C3", "pos": Vector2(100, 300), "kit": {}, "name": "Grotto rebirth pool"}]

func _species(id: String, display_name: String, unlock: Dictionary) -> SpeciesDef:
	var d := SpeciesDef.new()
	d.id = id
	d.display_name = display_name
	d.unlock = unlock
	return d

func _lines() -> GoddessLines:
	var l := GoddessLines.new()
	l.by_cause = {"bat": ["b0", "b1"]}
	l.many_deaths = ["m0"]
	l.fallback = "f"
	return l

func _goddess(points := 0) -> Goddess:
	var soul := SoulProgress.new()
	soul.points = points
	var catalog := {"slime": _species("slime", "Slime", {"kind": "default"}),
		"wolf": _species("wolf", "Wolf", {"kind": "defeat", "creature": "gloom_wolf"})}
	return Goddess.new(soul, SoulRules.new(), _lines(), catalog, [], compendium, skills)

func test_places_are_the_attuned_pools_default_first() -> void:
	var progress := WorldProgress.new()
	var g := _goddess()
	var only_default := g.model(progress, _pools()).rows(P.WHERE)
	assert_eq(only_default.map(func(r: Dictionary) -> String: return r["id"]), ["C1"])
	progress.attune("G1")
	var both := g.model(progress, _pools()).rows(P.WHERE)
	assert_eq(both.map(func(r: Dictionary) -> String: return r["id"]), ["C1", "G1"])
	assert_eq(both.map(func(r: Dictionary) -> String: return r["name"]), ["Cave mouth", "Grotto rebirth pool"])
	assert_eq(g.model(progress, []).rows(P.WHERE), [{"id": "C1", "name": "Cave mouth"}], "a world with no pools starts at the default")

func test_species_follow_the_bestiary() -> void:
	var g := _goddess()
	var progress := WorldProgress.new()
	assert_eq(g.model(progress, _pools()).rows(P.WHO), [{"id": "slime", "name": "Slime"}])
	compendium.on_creature_defeated("gloom_wolf")
	assert_eq(g.model(progress, _pools()).rows(P.WHO), [{"id": "slime", "name": "Slime"}, {"id": "wolf", "name": "Wolf"}])

func test_powers_are_the_owned_once_ones_with_their_names() -> void:
	compendium.raise("leap", CompendiumModel.State.OWNED_ONCE)
	var rows := _goddess().model(WorldProgress.new(), _pools()).rows(P.HEAD_START)
	assert_eq(rows.size(), 2, "the level row and one power")
	assert_eq(rows[1]["id"], "leap")
	assert_eq(rows[1]["name"], compendium.skill_name("leap"))

func test_the_last_choice_is_preselected() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	progress.set_last_choice("G1")
	assert_eq(_goddess().model(progress, _pools()).selected_place(), "G1")

func test_line_for_death_counts_the_death_first() -> void:
	var g := _goddess()
	assert_eq(g.line_for_death("bat"), "b1", "the first death is death 1")
	assert_eq(g.soul.deaths, 1)
	assert_eq(g.line_for_death("bat"), "b0")
	assert_eq(g.line_for_death("bat"), "b1")
	assert_eq(g.line_for_death("bat"), "b0")
	assert_eq(g.line_for_death("bat"), "m0", "the fifth death takes a many-deaths line")
	assert_eq(_goddess().line_for_death("blade"), "f", "an unknown cause takes the fallback")

func test_load_default_reads_the_shipped_data() -> void:
	var g := Goddess.load_default(SoulProgress.new(), compendium, skills)
	assert_true(g.perks.any(func(p: PerkDef) -> bool: return p.id == "stats"))
	assert_ne(g.line_for_death("bat"), "")
