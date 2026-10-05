extends GutTest
## A goblin picks the pocket of a living creature on the inspect button: once per creature, one part at most, no fight.

var skills: Array
var skills_by_id := {}
var rules: SkillRulesEngine
var player: Player
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d

func _make(species := "goblin") -> Player:
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

func _def(id := "t_mark", drops: Array = [{"part": "claw", "chance": 1.0}], bonds: Array = []) -> CreatureDef:
	var d := TestDefs.creature(id, {"drops": drops, "bonds": bonds})
	d.stats = {"max_hp": 4, "atk": 2, "def": 0, "spd": 100}
	return d

func _creature(def: CreatureDef, offset := Vector2(10, 0)) -> Enemy:
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	e.position = player.position + offset
	add_child_autofree(e)
	return e

func _named(event: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == event).map(func(e: Array) -> Dictionary: return e[1])

# --- the theft ---

func test_a_goblin_takes_a_part_without_a_fight() -> void:
	_make()
	var e := _creature(_def())
	assert_true(player.try_pickpocket())
	assert_eq(player.inventory.carried(), ["claw"])
	assert_eq(_named(Deeds.ITEM_STOLEN), [{"creature": "t_mark", "part": "claw"}])
	assert_eq(_named(Deeds.PART_HARVESTED), [{"part": "claw"}])
	assert_eq(_named(Deeds.ITEM_CARRIED).size(), 1)
	assert_true(e.robbed)
	assert_false(e.is_queued_for_deletion(), "it stays")
	assert_eq(e.health.hp, 4, "and it is not hurt")
	assert_eq(_named(Deeds.DEFEATED).size(), 0)

func test_a_creature_is_robbed_once() -> void:
	_make()
	_creature(_def())
	assert_true(player.try_pickpocket())
	assert_false(player.try_pickpocket())
	assert_eq(player.inventory.carried(), ["claw"])
	assert_eq(_named(Deeds.ITEM_STOLEN).size(), 1)

func test_an_empty_pocket_takes_nothing_says_nothing_and_is_not_tried_again() -> void:
	_make()
	var e := _creature(_def("t_mark", [{"part": "claw", "chance": 0.0}]))
	assert_true(player.try_pickpocket(), "it was tried")
	assert_eq(player.inventory.carried(), [])
	assert_eq(_named(Deeds.ITEM_STOLEN).size(), 0)
	assert_eq(_named(Deeds.PART_HARVESTED).size(), 0)
	assert_true(e.robbed)
	assert_false(player.try_pickpocket())

func test_one_part_at_most_however_much_it_carries() -> void:
	_make()
	_creature(_def("t_mark", [{"part": "claw", "chance": 1.0}, {"part": "skull", "chance": 1.0}]))
	player.try_pickpocket()
	assert_eq(player.inventory.carried().size(), 1)
	assert_eq(_named(Deeds.ITEM_STOLEN).size(), 1)

func test_a_creature_with_nothing_to_take_is_not_a_target() -> void:
	_make()
	var e := _creature(_def("t_mark", []))
	assert_false(player.try_pickpocket())
	assert_false(e.robbed)

func test_the_nearest_robbable_creature_is_the_one_robbed() -> void:
	_make()
	var near := _creature(_def("t_near"), Vector2(8, 0))
	var far := _creature(_def("t_far"), Vector2(24, 0))
	player.try_pickpocket()
	assert_true(near.robbed)
	assert_false(far.robbed)

func test_a_stunned_creature_can_be_robbed() -> void:
	_make()
	var e := _creature(_def())
	e.status.stun(10.0)
	assert_true(player.try_pickpocket())
	assert_true(e.robbed)

# --- who, and what ---

func test_only_a_goblin_picks_pockets() -> void:
	for species in ["slime", "wolf", "undead", "spider"]:
		_make(species)
		var e := _creature(_def())
		assert_false(player.try_pickpocket(), species)
		assert_false(e.robbed, species)

func test_a_dormant_a_downed_or_a_far_creature_is_not_robbed() -> void:
	_make()
	var dormant := _creature(_def("t_a"))
	dormant.dormant = true
	var downed := _creature(_def("t_b"))
	downed.receive_hit(999, "physical", Vector2.INF)
	downed.finish_dying()
	var far := _creature(_def("t_c"), Vector2(Player.PREDATE_RANGE + 40.0, 0))
	assert_false(player.try_pickpocket())
	assert_eq(player.inventory.carried(), [])
	assert_false(far.robbed)

func test_a_dead_goblin_picks_no_pockets() -> void:
	_make()
	var e := _creature(_def())
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_false(player.try_pickpocket())
	assert_false(e.robbed)

func test_a_big_creature_has_a_pocket_even_with_no_drops_of_its_own() -> void:
	_make()
	var big := _def("t_big", [])
	big.stats = {"max_hp": DeedTags.HEAVY_HP, "atk": 2, "def": 0, "spd": 100}
	var e := _creature(big)
	assert_true(e.can_be_robbed())

func test_a_creature_that_cannot_be_eaten_is_not_robbed() -> void:
	_make()
	var boss := _def("t_boss")
	boss.predatable = false
	boss.appraisal_target = false
	var e := _creature(boss)
	assert_false(e.can_be_robbed())

# --- the button ---

func test_inspect_picks_the_pocket_before_it_inspects() -> void:
	_make()
	_creature(_def())
	watch_signals(player)
	player.do_inspect()
	assert_eq(player.inventory.carried(), ["claw"])
	assert_signal_not_emitted(player, "inspect_report")

func test_inspect_inspects_when_nothing_can_be_robbed() -> void:
	_make()
	watch_signals(player)
	player.do_inspect()
	assert_signal_emitted(player, "inspect_report")

func test_a_stunned_creature_that_can_be_tamed_is_tamed_before_it_is_robbed() -> void:
	_make()
	player.collect_part("skull")
	var e := _creature(_def("t_pal", [{"part": "claw", "chance": 1.0}], ["tame"]))
	e.status.stun(30.0)
	player.do_inspect()
	assert_eq(player.companions.size(), 1)
	assert_eq(_named(Deeds.ITEM_STOLEN).size(), 0)

func test_a_goblin_with_nothing_to_offer_robs_the_creature_it_could_not_tame() -> void:
	_make()
	var e := _creature(_def("t_pal", [{"part": "claw", "chance": 1.0}], ["tame"]))
	e.status.stun(30.0)
	player.do_inspect()
	assert_eq(player.companions.size(), 0)
	assert_eq(player.inventory.carried(), ["claw"])

func test_the_stolen_deed_names_the_creature_and_the_part() -> void:
	assert_eq(Deeds.TAGS[Deeds.ITEM_STOLEN], ["creature", "part"])
