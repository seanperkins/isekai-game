extends GutTest
## Bought perks reach the body at the start of a life, not before: the live player is never changed by a purchase.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creatures := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creatures)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creatures, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _stats_perk() -> PerkDef:
	var p := PerkDef.new()
	p.id = "stats"
	p.price_base = 5
	p.price_step = 3
	p.effects = [{"stat": "max_hp", "amount": 2}, {"stat": "max_mp", "amount": 1}]
	return p

func _soul_with(purchases: int) -> SoulProgress:
	var soul := SoulProgress.new(null, ["stats"])
	soul.add(100)
	for i in purchases:
		soul.buy_perk(_stats_perk())
	return soul

func test_two_purchases_add_twice_the_effect_and_fill_vitals() -> void:
	var max_hp := player.health.max_hp
	var max_mp := player.mana.max_mp
	var soul := _soul_with(2)
	player.health.take_hit(1, "physical")
	player.mana.spend(1)
	assert_lt(player.health.hp, max_hp, "wounded before the perks apply")
	SoulPerks.apply(player, soul, [_stats_perk()])
	assert_eq(player.health.max_hp, max_hp + 4)
	assert_eq(player.mana.max_mp, max_mp + 2)
	assert_eq(player.health.hp, player.health.max_hp, "a new life is not wounded")
	assert_eq(player.mana.mp, player.mana.max_mp)

func test_no_perk_bought_leaves_stats_and_vitals_alone() -> void:
	var max_hp := player.health.max_hp
	player.health.take_hit(1, "physical")
	var wounded := player.health.hp
	assert_lt(wounded, max_hp, "wounded before apply")
	SoulPerks.apply(player, _soul_with(0), [_stats_perk()])
	assert_eq(player.health.max_hp, max_hp)
	assert_eq(player.health.hp, wounded, "nothing was applied, so nothing was healed")

func test_buying_after_apply_does_not_touch_the_live_player() -> void:
	var soul := _soul_with(1)
	SoulPerks.apply(player, soul, [_stats_perk()])
	var max_hp := player.health.max_hp
	assert_true(soul.buy_perk(_stats_perk()))
	assert_eq(player.health.max_hp, max_hp, "the second purchase waits for the next life")
