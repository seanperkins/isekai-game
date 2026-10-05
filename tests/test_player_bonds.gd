extends GutTest
## Wolves bond and goblins tame: the species action on the inspect button, for a stunned creature that accepts the bond.

class Shrine extends Node2D:
	var used := 0
	func interact(_p) -> void:
		used += 1

var skills: Array
var skills_by_id := {}
var rules: SkillRulesEngine
var player: Player
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d

func _make(species: String) -> Player:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	events = []
	var p := Player.new()
	p.species = species
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	player = p
	return p

func _def(id := "t_pal", bonds: Array = ["pack"]) -> CreatureDef:
	var d := TestDefs.creature(id, {"bonds": bonds, "essences": {"earth": 1}})
	d.stats = {"max_hp": 4, "atk": 2, "def": 0, "spd": 100}
	return d

func _stunned(def: CreatureDef, offset := Vector2(10, 0)) -> Enemy:
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	e.position = player.position + offset
	add_child_autofree(e)
	e.status.stun(30.0)
	return e

func _named(event: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == event).map(func(e: Array) -> Dictionary: return e[1])

# --- the wolf ---

func test_a_wolf_bonds_a_stunned_creature_that_joins_a_pack() -> void:
	_make("wolf")
	var e := _stunned(_def())
	assert_true(player.try_bond())
	assert_true(e.is_queued_for_deletion(), "it leaves the room")
	assert_eq(player.companions.size(), 1)
	assert_eq(player.companions[0].get_parent(), player.get_parent(), "not in the room: it follows through rooms")
	assert_eq(player.companions[0].def.id, "t_pal")
	assert_eq(_named(Deeds.BOND_FORMED), [{"kind": "pack", "creature": "t_pal"}])

func test_a_bond_is_not_a_kill() -> void:
	_make("wolf")
	_stunned(_def())
	player.try_bond()
	assert_eq(_named(Deeds.DEFEATED).size(), 0)
	assert_eq(_named(Events.PREDATED).size(), 0)

func test_a_wolf_cannot_bond_a_creature_that_only_accepts_taming() -> void:
	_make("wolf")
	var e := _stunned(_def("t_pal", ["tame"]))
	assert_false(player.try_bond())
	assert_false(e.is_queued_for_deletion())
	assert_eq(player.companions.size(), 0)

# --- the goblin ---

func test_a_goblin_with_nothing_to_offer_tames_nothing() -> void:
	_make("goblin")
	var e := _stunned(_def("t_pal", ["tame"]))
	assert_false(player.try_bond())
	assert_false(e.is_queued_for_deletion())
	assert_eq(_named(Deeds.BOND_FORMED).size(), 0)

func test_a_goblin_offers_one_part_and_tames_the_creature() -> void:
	_make("goblin")
	player.collect_part("claw")
	player.collect_part("skull")
	var e := _stunned(_def("t_pal", ["tame"]))
	assert_true(player.try_bond())
	assert_true(e.is_queued_for_deletion())
	assert_eq(player.inventory.carried().size(), 1, "exactly one part is spent")
	assert_eq(_named(Deeds.BOND_FORMED), [{"kind": "tame", "creature": "t_pal"}])

func test_taming_teaches_the_goblin_the_creature() -> void:
	_make("goblin")
	player.collect_part("claw")
	_stunned(_def("t_pal", ["tame"]))
	player.try_bond()
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 1)
	assert_true(player.lessons.known("t_pal"))
	assert_eq(_named(Events.ABSORBED).size(), 1)

func test_a_goblin_cannot_tame_a_creature_that_only_joins_a_pack() -> void:
	_make("goblin")
	player.collect_part("claw")
	var e := _stunned(_def("t_pal", ["pack"]))
	assert_false(player.try_bond())
	assert_false(e.is_queued_for_deletion())
	assert_eq(player.inventory.carried().size(), 1, "nothing is spent on a refused offer")

func test_a_large_creature_says_so_too() -> void:
	_make("goblin")
	player.collect_part("claw")
	_stunned(_def("t_big", ["tame", "large"]))
	player.try_bond()
	var got := _named(Deeds.BOND_FORMED)
	assert_eq(got.size(), 2)
	assert_true(got.has({"kind": "tame", "creature": "t_big"}))
	assert_true(got.has({"kind": "large", "creature": "t_big"}))

# --- who can, and when ---

func test_the_other_species_bond_nothing() -> void:
	for species in ["slime", "undead", "spider"]:
		_make(species)
		player.collect_part("claw")
		var e := _stunned(_def("t_pal", ["pack", "tame"]))
		assert_false(player.try_bond(), species)
		assert_false(e.is_queued_for_deletion(), species)

func test_an_active_creature_is_not_bonded() -> void:
	_make("wolf")
	var e := _stunned(_def())
	e.status.state = EnemyStatus.ACTIVE
	assert_false(player.try_bond())

func test_a_creature_out_of_reach_is_not_bonded() -> void:
	_make("wolf")
	_stunned(_def(), Vector2(Player.PREDATE_RANGE + 40.0, 0))
	assert_false(player.try_bond())

func test_a_dead_player_bonds_nothing() -> void:
	_make("wolf")
	var e := _stunned(_def())
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_false(player.try_bond())
	assert_false(e.is_queued_for_deletion())

# --- the cap ---

func test_one_companion_at_a_time_and_a_refused_bond_costs_nothing() -> void:
	_make("goblin")
	player.collect_part("claw")
	player.collect_part("skull")
	_stunned(_def("t_a", ["tame"]))
	assert_true(player.try_bond())
	var second := _stunned(_def("t_b", ["tame"]))
	assert_false(player.try_bond())
	assert_false(second.is_queued_for_deletion())
	assert_eq(player.inventory.carried().size(), 1, "the second offer was not spent")
	assert_eq(player.companions.size(), 1)

func test_the_lord_of_beasts_keeps_two() -> void:
	_make("goblin")
	assert_true(player.become_form("goblin_lord_of_beasts"))
	assert_eq(player.companion_cap(), 2)
	for id in ["t_a", "t_b", "t_c"]:
		player.collect_part("claw")
		_stunned(_def(id, ["tame"]))
	assert_true(player.try_bond())
	assert_true(player.try_bond())
	assert_false(player.try_bond())
	assert_eq(player.companions.size(), 2)

func test_everyone_else_keeps_one() -> void:
	for species in ["wolf", "goblin"]:
		_make(species)
		assert_eq(player.companion_cap(), 1, species)

func test_a_companion_that_dies_frees_the_slot() -> void:
	_make("wolf")
	_stunned(_def())
	player.try_bond()
	var pal: Companion = player.companions[0]
	pal.hp = 1
	var foe := Enemy.new()
	var d := _def("t_foe", [])
	d.stats = {"max_hp": 9, "atk": 5, "def": 0, "spd": 100}
	foe.setup(d, skills_by_id)
	foe.position = pal.global_position
	add_child_autofree(foe)
	pal._physics_process(0.016)
	assert_eq(player.companions.size(), 0)
	_stunned(_def("t_next"))
	assert_true(player.try_bond(), "a new bond is possible again")

# --- losing them ---

func test_the_players_death_frees_the_companions() -> void:
	_make("wolf")
	_stunned(_def())
	player.try_bond()
	var pal: Companion = player.companions[0]
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_true(player.health.is_dead())
	assert_true(pal.is_queued_for_deletion())
	assert_eq(player.companions.size(), 0)

func test_a_new_run_frees_the_companions() -> void:
	_make("wolf")
	_stunned(_def())
	player.try_bond()
	var pal: Companion = player.companions[0]
	rules.start_run()
	assert_true(pal.is_queued_for_deletion())
	assert_eq(player.companions.size(), 0)

# --- the button ---

func test_inspect_bonds_before_it_inspects() -> void:
	_make("wolf")
	_stunned(_def())
	watch_signals(player)
	player.do_inspect()
	assert_eq(player.companions.size(), 1)
	assert_signal_not_emitted(player, "inspect_report")

func test_inspect_inspects_when_there_is_nothing_to_bond() -> void:
	_make("wolf")
	watch_signals(player)
	player.do_inspect()
	assert_signal_emitted(player, "inspect_report")

func test_an_interactable_in_reach_wins_over_a_bond() -> void:
	_make("wolf")
	var shrine := Shrine.new()
	shrine.position = player.position
	add_child_autofree(shrine)
	shrine.add_to_group("interactable")
	var e := _stunned(_def())
	player.do_inspect()
	assert_eq(shrine.used, 1)
	assert_false(e.is_queued_for_deletion())
	assert_eq(player.companions.size(), 0)
