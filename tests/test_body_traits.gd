extends GutTest
## Drawbacks that are the body's: weak when alone, no stand-and-fight tools, loud steps; and the stat table that makes a slow, frail or weak form so.

var arena: VerbArena
var player: Player

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	player._invuln = 1000.0

func after_each() -> void:
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_a_body_weak_alone_loses_attack_with_no_packmate_and_gets_it_back_with_one() -> void:
	player.skillset.capabilities["trait_weak_alone"] = 1
	var atk := player.stats.get_stat("atk")
	await wait_seconds(0.7)
	assert_lt(player.stats.get_stat("atk"), atk, "alone it is weak")
	player.add_companion(VerbAlly._creature("gloom_wolf"), player.global_position, {})
	await wait_seconds(0.7)
	assert_eq(player.stats.get_stat("atk"), atk, "with company it is not")

func test_a_body_with_no_stand_and_fight_tools_cannot_cast_a_guard() -> void:
	player.skillset.capabilities["trait_no_stand"] = 1
	player.skillset.slots.add("verb_wolf_black_dog")
	var hold := arena.verb("goblin_hob")
	player.skillset.slots.slots[0] = ""
	assert_eq(hold.spec["kind"], "stone")
	player.skillset.capabilities["trait_no_stand"] = 1
	assert_true(player.refuses_to_stand("stone"))
	assert_true(player.refuses_to_stand("ward"))
	assert_false(player.refuses_to_stand("bolt"))

func test_loud_steps_halve_a_veil() -> void:
	player.veil_for(4.0)
	var plain := player._veil_t
	player.break_veil()
	player.skillset.capabilities["trait_loud"] = 1
	player.veil_for(4.0)
	assert_almost_eq(player._veil_t, plain / 2.0, 0.01)

func test_the_slow_the_frail_and_the_weak_have_the_stats_for_it() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/form_body.json"))
	for id in ["undead_draugr", "undead_zombie", "wolf_dire_wolf", "wolf_warg", "undead_pharaoh", "goblin_paladin"]:
		assert_lt(int(table[id]["stats"].get("spd", 0)), 0, "%s is slow" % id)
	for id in ["undead_skeletal_archer", "undead_adept", "undead_lich", "spider_norn"]:
		assert_lt(int(table[id]["stats"].get("max_hp", 0)), 0, "%s is frail" % id)
	assert_eq(int(table["undead_draugr"]["stats"]["jump_height"]), -100, "no jump")
	for id in ["wolf_lycaon", "goblin_beastcaller", "undead_sower_of_teeth", "spider_broodmother", "spider_brood_queen"]:
		assert_true(table[id]["traits"].has("weak_alone"), id)
	assert_true(table["wolf_skoll"]["traits"].has("no_stand"))
	assert_true(table["goblin_ironboot"]["traits"].has("loud"))
