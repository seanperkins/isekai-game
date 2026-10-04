extends GutTest
## Every tree, end to end: each branch evolves in a fresh run, the sibling closes, the slot holds the child.

const TREES := [["sticky_thread", ["swing_thread", "binding_web"]], ["hydraulic_propulsion", ["water_blade", "jet_dash"]],
	["poison_breath", ["miasma", "venom_bolt"]], ["spore_cloud", ["healing_spores", "puffball"]]]

var rules: SkillRulesEngine
var skills_by_id := {}
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	for d in skills:
		skills_by_id[d.id] = d
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

## Pays the parent's price: the essence is eaten first, as it would be in play.
func _fund(parent: String) -> void:
	var price: Dictionary = (skills_by_id[parent] as SkillDef).evolution_price
	for e in price:
		for i in int(price[e]):
			rules.handle_event("absorbed", {"essence": e, "source": "test"})

func test_each_tree_evolves_each_branch_in_a_fresh_run() -> void:
	for tree in TREES:
		var parent: String = tree[0]
		for chosen in tree[1]:
			rules.start_run()
			player.skillset.reset()
			assert_true(rules.grant(parent, true), parent)
			var d: SkillDef = skills_by_id[parent]
			var n: int = int((skills_by_id[chosen] as SkillDef).unlock[0]["n"])
			for i in (n - 1) * d.level_curve:
				rules.handle_event("skill_used", {"id": parent})
			for c in tree[1]:
				assert_true(rules.is_evolution_ready(c), "%s ready after %s reaches level %d" % [c, parent, n])
			_fund(parent)
			assert_true(rules.can_afford(chosen), chosen)
			assert_true(rules.evolve(chosen), chosen)
			assert_true(player.skillset.slots.slots.has(chosen), "%s is slotted" % chosen)
			assert_false(player.skillset.slots.slots.has(parent), "%s left its slot" % parent)
			for c in tree[1]:
				if c != chosen:
					assert_true(rules.is_closed(c), "%s closed" % c)
