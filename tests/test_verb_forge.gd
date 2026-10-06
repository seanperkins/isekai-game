extends GutTest
## The Smith's Forge: two carried parts become a lasting weapon (+2 ATK for the life), or nothing happens and nothing is paid.

var skills: Array
var rules: SkillRulesEngine
var player: Player
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")

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

func _named(event: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == event)

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [0], 1)
	return a

# --- the player's forge ---

func test_two_carried_parts_become_two_attack() -> void:
	_make()
	var atk := player.stats.get_stat("atk")
	player.collect_part("claw")
	player.collect_part("skull")
	assert_eq(player.parts_carried(), 2)
	assert_true(player.forge("atk", 2, 2))
	assert_eq(player.parts_carried(), 0, "exactly the two were spent")
	assert_eq(player.stats.get_stat("atk"), atk + 2)

func test_too_few_parts_forge_nothing_and_spend_nothing() -> void:
	_make()
	var atk := player.stats.get_stat("atk")
	player.collect_part("claw")
	assert_false(player.forge("atk", 2, 2))
	assert_eq(player.parts_carried(), 1)
	assert_eq(player.stats.get_stat("atk"), atk)

func test_a_cocoon_is_not_a_part_to_forge_with() -> void:
	_make()
	player.collect_part("cocoon:bat")
	player.collect_part("claw")
	assert_false(player.forge("atk", 2, 2), "one part and a cocoon")
	assert_eq(player.inventory.cocoons(), ["bat"])

func test_forges_stack() -> void:
	_make()
	var atk := player.stats.get_stat("atk")
	for i in 4:
		player.collect_part("claw")
	assert_true(player.forge("atk", 2, 2))
	assert_true(player.forge("atk", 2, 2))
	assert_eq(player.stats.get_stat("atk"), atk + 4)

func test_a_forge_can_raise_another_stat() -> void:
	_make()
	var def := player.stats.get_stat("def")
	player.collect_part("claw")
	player.collect_part("claw")
	assert_true(player.forge("def", 3, 2))
	assert_eq(player.stats.get_stat("def"), def + 3)

func test_a_worn_graft_is_never_spent() -> void:
	_make("undead")
	player.collect_part("ribs")
	player.collect_part("moonstone")
	player.collect_part("phylactery_shard")
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_true(player.forge("atk", 2, 2))
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_eq(player.parts_carried(), 0)

func test_the_forged_weapon_is_gone_with_the_life() -> void:
	_make()
	var atk := player.stats.get_stat("atk")
	player.collect_part("claw")
	player.collect_part("claw")
	player.forge("atk", 2, 2)
	rules.start_run()
	assert_eq(player.stats.get_stat("atk"), atk)
	player.collect_part("claw")
	player.collect_part("claw")
	player.forge("atk", 2, 2)
	assert_eq(player.stats.get_stat("atk"), atk + 2, "a new life forges from nothing")

# --- the verb ---

func test_can_run_is_false_for_a_forge_the_actor_cannot_pay_for() -> void:
	_make()
	var a := _verb({"kind": "forge"})
	assert_false(VerbKinds.can_run(a, {"kind": "forge"}))
	player.collect_part("claw")
	assert_false(VerbKinds.can_run(a, {"kind": "forge"}))
	player.collect_part("claw")
	assert_true(VerbKinds.can_run(a, {"kind": "forge"}))
	assert_false(VerbKinds.can_run(a, {"kind": "forge", "parts": 3}))

func test_can_run_is_true_for_every_other_kind_and_false_for_a_forge_by_a_stub() -> void:
	_make()
	var a := _verb({"kind": "bolt"})
	assert_true(VerbKinds.can_run(a, {"kind": "bolt"}))
	var stub := Node2D.new()
	add_child_autofree(stub)
	var b: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(b)
	b.setup(stub, [0], 1)
	assert_false(VerbKinds.can_run(b, {"kind": "forge"}), "an actor with no pack forges nothing")

func test_a_verb_forge_with_parts_raises_attack_and_says_the_deed_once() -> void:
	_make()
	var spec := {"kind": "forge", "stat": "atk", "amount": 2, "parts": 2, "deed": "weapon_forged"}
	var atk := player.stats.get_stat("atk")
	player.collect_part("claw")
	player.collect_part("claw")
	var a := _verb(spec)
	assert_true(a.ready())
	assert_true(a.activate())
	assert_eq(player.stats.get_stat("atk"), atk + 2)
	assert_eq(_named(Deeds.WEAPON_FORGED).size(), 1)

func test_a_verb_forge_without_parts_is_not_ready_and_says_nothing() -> void:
	_make()
	var spec := {"kind": "forge", "stat": "atk", "amount": 2, "parts": 2, "deed": "weapon_forged"}
	var atk := player.stats.get_stat("atk")
	var a := _verb(spec)
	assert_false(a.ready())
	a.activate()  # even forced, nothing is forged
	assert_eq(_named(Deeds.WEAPON_FORGED).size(), 0)
	assert_eq(player.stats.get_stat("atk"), atk)

func test_a_cooldown_still_makes_a_forge_not_ready() -> void:
	_make()
	player.collect_part("claw")
	player.collect_part("claw")
	var a := _verb({"kind": "forge", "cooldown": 10.0})
	assert_true(a.activate())
	player.collect_part("claw")
	player.collect_part("claw")
	assert_false(a.ready(), "on cooldown, though the parts are there")

func test_validate_accepts_a_forge_bare_or_with_keys_and_rejects_a_bad_one() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "forge"})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "forge", "stat": "atk", "amount": 2, "parts": 2, "deed": "weapon_forged", "cooldown": 10.0})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "forge", "stat": "luck"})), ["forge: stat must be a stat id"])
	assert_eq(Array(VerbKinds.validate({"kind": "forge", "parts": "two"})), ["forge: parts must be a number"])
	assert_eq(Array(VerbKinds.validate({"kind": "forge", "range": 3})), ["forge: unknown key 'range'"])

func test_a_forge_is_not_a_kind_an_enemy_casts() -> void:
	assert_false(VerbKinds.ENEMY_KINDS.has("forge"))

func test_the_smiths_verb_is_the_forge() -> void:
	var sd: SkillDef
	for d in skills:
		if d.id == "verb_goblin_smith":
			sd = d
	assert_eq(SkillEffects.active_spec(sd), {"kind": "forge", "stat": "atk", "amount": 2, "parts": 2, "needs_forge": true, "named": true, "still": 1.5, "deed": "weapon_forged", "cooldown": 10.0})
