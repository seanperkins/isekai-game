extends GutTest
## The Skills / Compendium screen: data model, slot assignment and the paused UI.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var skills: Array
var player: Player
var screen: SkillScreen

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	PadInput.reset()
	get_tree().paused = false

func _emit(ev: String, tags: Dictionary, times: int) -> void:
	for i in times:
		rules.handle_event(ev, tags)

func _screen() -> SkillScreen:
	screen = SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills)
	return screen

func test_level_progress_counts_toward_the_next_level() -> void:
	_emit("jumped", {}, 40 + 10)
	assert_eq(rules.level_progress("leap"), {"current": 10, "target": 20})
	assert_eq(rules.level_progress("nope"), {"current": 0, "target": 0})

func test_skill_rows_group_owned_skills_and_tease_locked_ones() -> void:
	_emit("jumped", {}, 40)
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	var rows := SkillScreenModel.skill_rows(rules, skills)
	var texts := rows.map(func(r): return r.get("text", r.get("name", "???")))
	assert_eq(texts[0], "PROFICIENCY")
	assert_true(texts.has("Leap"))
	assert_true(texts.has("Hydraulic Propulsion"))
	assert_true(rows.any(func(r): return r["kind"] == "locked"))
	assert_false(texts.has("Glutton"))  # secret and unowned: never teased by name

func test_compendium_rows_reveal_by_state() -> void:
	compendium.raise("leap", CompendiumModel.State.HINTED)
	compendium.raise("wall_cling", CompendiumModel.State.OWNED_ONCE)
	var rows := SkillScreenModel.compendium_rows(compendium, skills)
	var leap: Dictionary = rows.filter(func(r): return r.get("id") == "leap")[0]
	assert_eq(leap["name"], "Leap")
	assert_eq(leap["hint"], "Your body remembers every leap.")
	assert_false(leap.has("condition"))
	var cling: Dictionary = rows.filter(func(r): return r.get("id") == "wall_cling")[0]
	assert_eq(cling["condition"], "Touch a wall mid-air ×15")
	var toughness: Dictionary = rows.filter(func(r): return r.get("id") == "toughness")[0]
	assert_eq(toughness["name"], "???")

func test_condition_text_is_readable() -> void:
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	assert_eq(SkillScreenModel.condition_text(by_id["leap"], by_id), "Jump ×40")
	assert_eq(SkillScreenModel.condition_text(by_id["echolocation"], by_id), "Absorb air essence ×6")
	assert_eq(SkillScreenModel.condition_text(by_id["glutton"], by_id), "Eat creatures in a row without taking damage ×5")
	assert_eq(SkillScreenModel.condition_text(by_id["jet_dash"], by_id), "Hydraulic Propulsion Lv3")

func test_detail_card_for_an_active() -> void:
	TestDefs.satisfy(rules, "poison_breath")
	_emit("skill_used", {"id": "poison_breath"}, 4)
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	var card := SkillScreenModel.detail(rules, by_id["poison_breath"], player.skillset.slots)
	assert_eq(card["name"], "Poison Breath")
	assert_eq([card["level"], card["max_level"]], [1, 15])
	assert_eq(card["mp_cost"], 4)
	assert_eq(card["lines"], ["Damage 2"])
	assert_almost_eq(card["progress"], 0.5, 0.001)
	assert_eq(card["slot"], 0)

func test_the_damage_line_follows_atk_and_no_other_line_does() -> void:
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	assert_eq(SkillScreenModel.effect_lines(by_id["poison_breath"], 1), ["Damage 2"], "two arguments: ATK 1")
	assert_eq(SkillScreenModel.effect_lines(by_id["poison_breath"], 1, 5), ["Damage 4"], "2 x 200 / 100")
	assert_eq(SkillScreenModel.effect_lines(by_id["spore_cloud"], 3, 5), SkillScreenModel.effect_lines(by_id["spore_cloud"], 3))
	assert_eq(SkillScreenModel.effect_lines(by_id["hydraulic_propulsion"], 2, 5), SkillScreenModel.effect_lines(by_id["hydraulic_propulsion"], 2))
	assert_eq(SkillScreenModel.effect_lines(by_id["poison_resistance"], 1, 5), ["Poison damage −20%"])
	var card := SkillScreenModel.detail(rules, by_id["poison_breath"], player.skillset.slots, 5)
	assert_eq(card["lines"], ["Damage 4"])

func test_the_open_screen_shows_the_players_atk_in_the_damage_line() -> void:
	TestDefs.satisfy(rules, "poison_breath")
	player.stats.set_modifiers("t", [{"stat": "atk", "op": "add", "value": 4}])
	_screen()
	screen.open()
	var guard := 0
	while screen.selected_id() != "poison_breath" and guard < 20:
		screen.move(1)
		guard += 1
	assert_string_contains("\n".join(screen.detail_texts()), "Damage 4")

func test_detail_lines_for_passives() -> void:
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	assert_eq(SkillScreenModel.effect_lines(by_id["leap"], 2), ["Jump height +15%"])
	assert_eq(SkillScreenModel.effect_lines(by_id["poison_resistance"], 1), ["Poison damage −20%"])
	assert_eq(SkillScreenModel.effect_lines(by_id["regeneration"], 1), ["Regen 1 HP every 8 s"])
	assert_eq(SkillScreenModel.effect_lines(by_id["toughness"], 1), ["Max HP +3"])

func test_assign_puts_an_active_in_a_slot_and_swaps_duplicates() -> void:
	var s := ActiveSlots.new()
	s.add("a")
	s.add("b")
	s.assign(1, "a")  # a was in slot 0: the two swap
	assert_eq(s.slots, ["b", "a", "", ""])
	s.assign(0, "not_owned")
	assert_eq(s.slots[0], "b")

func test_screen_opens_paused_and_closes() -> void:
	_screen()
	assert_false(screen.is_open())
	screen.toggle()
	assert_true(screen.is_open())
	assert_true(get_tree().paused)
	screen.close()
	assert_false(get_tree().paused)

func test_screen_lists_navigates_and_assigns() -> void:
	_emit("jumped", {}, 40)
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	TestDefs.satisfy(rules, "poison_breath")
	_screen()
	screen.open()
	assert_true(screen.row_texts().any(func(t): return t.begins_with("Leap")))
	while screen.selected_id() != "poison_breath":
		screen.move(1)
	assert_string_contains("\n".join(screen.detail_texts()), "MP cost 4")
	assert_eq(player.skillset.slots.slots[1], "poison_breath")  # auto-slotted second
	screen.accept()  # moves to the next slot: H
	assert_eq(player.skillset.slots.slots[2], "poison_breath")
	screen.accept()  # then L
	assert_eq(player.skillset.slots.slots[3], "poison_breath")
	assert_eq(player.skillset.slots.slots[1], "")

func test_compendium_tab_shows_unknown_slots() -> void:
	_screen()
	screen.open()
	screen.switch_tab(1)
	assert_eq(screen.tab(), "compendium")
	assert_true(screen.row_texts().has("???"))

func test_screen_fits_the_640x360_view() -> void:
	_screen()
	screen.open()
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))

func test_bestiary_tab_lists_creatures_and_shows_a_card() -> void:
	compendium.on_creature_seen("bat")
	compendium.on_game_event(Events.PREDATED, {"source": "bat", "kind": "creature"})
	_screen()
	screen.open()
	screen.switch_tab(2)
	assert_eq(screen.tab(), "bestiary")
	assert_true(screen.row_texts().has("Cave Bat"))
	assert_true(screen.row_texts().has("???"))
	var bat := screen.row_texts().find("Cave Bat") - 1  # minus the header row
	screen.move(bat)
	assert_eq(screen.selected_id(), "bat")
	var card := "\n".join(screen.detail_texts())
	assert_string_contains(card, "Cave Bat")
	assert_string_contains(card, "Eaten 1")
	screen.accept()  # nothing to assign here; must not crash
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))

func test_tabs_cycle_through_all_five() -> void:
	_screen()
	screen.open()
	screen.switch_tab(3)
	assert_eq(screen.tab(), "map")
	screen.switch_tab(4)
	assert_eq(screen.tab(), "sound")
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "sound")

func test_sheet_only_creatures_have_a_bestiary_portrait() -> void:
	for id in ["bat", "toad", "lizard", "spider", "serpent", "spore_moth", "mushroom_crab", "vine_snake",
			"gloom_wolf", "armed_ant", "stone_drake", "taratect"]:
		var t := SkillScreen.portrait_texture(id)
		assert_not_null(t, id)
		assert_gt(t.get_size().x, 8.0, id)
		if id != "nobody":
			assert_ne(t, Art.texture("icon_locked"), "%s has a real portrait, not the locked icon" % id)
	assert_not_null(SkillScreen.portrait_texture("nobody"), "an unknown id shows the locked icon")

func test_the_channel_skills_say_how_much_holding_costs() -> void:
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	for id in ["sticky_thread", "hydraulic_propulsion"]:
		var card := SkillScreenModel.detail(rules, by_id[id], player.skillset.slots)
		assert_true(card["lines"].has("Hold: +1 MP every 0.5 s"), id)
		assert_string_contains(by_id[id].description.to_lower(), "hold")
	for id in ["swing_thread", "poison_breath", "water_blade"]:
		var card := SkillScreenModel.detail(rules, by_id[id], player.skillset.slots)
		assert_false(card["lines"].any(func(l): return String(l).begins_with("Hold: +")), id)

func _select_hydraulic() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # auto-slots into slot 1
	_screen()
	screen.open()
	var guard := 0
	while screen.selected_id() != "hydraulic_propulsion" and guard < 20:
		screen.move(1)
		guard += 1

func test_the_open_screen_refreshes_its_slot_badge_when_the_scheme_changes() -> void:
	_select_hydraulic()
	assert_string_contains("\n".join(screen.detail_texts()), "[U]")
	PadInput.mouse_move(Vector2(10, 0))
	assert_string_contains("\n".join(screen.detail_texts()), "[LMB]")

func test_s_pressed_on_the_paused_screen_does_not_hand_the_mouse_aim_back() -> void:
	_select_hydraulic()
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.key(KEY_S)  # navigates the screen; aims nothing
	assert_true(Controls.mouse_aim)

func test_swim_and_jolt_read_in_the_skill_screens_own_words() -> void:
	var by_id := {}
	for d in DefLoader.load_dir("res://data/skills"):
		by_id[d.id] = d
	assert_true(SkillScreenModel.effect_lines(by_id["swim"], 2).has("Swim speed 150 px/s"), str(SkillScreenModel.effect_lines(by_id["swim"], 2)))
	assert_true(SkillScreenModel.effect_lines(by_id["swim"], 1).has("Swim speed 120 px/s"))
	assert_eq(SkillScreenModel.effect_lines(by_id["jolt"], 1), ["Damage 3"], "ATK 1, power 3")
	assert_eq(SkillScreenModel.condition_text(by_id["swim"], by_id), "Spend time underwater ×20")
	assert_eq(SkillScreenModel.condition_text(by_id["jolt"], by_id), "Absorb light essence ×4 and Absorb air essence ×4")

func test_tremor_reads_as_damage_scaled_by_attack() -> void:
	var tremor: SkillDef = DefLoader.load_dir("res://data/skills").filter(func(d): return d.id == "tremor")[0]
	assert_eq(SkillScreenModel.effect_lines(tremor, 1), ["Damage 3"], "ATK 1: the table value")
	assert_eq(SkillScreenModel.effect_lines(tremor, 1, 5), ["Damage 6"], "3 x 200 / 100")
	assert_eq(SkillScreenModel.condition_text(tremor, {"tremor": tremor}), "Absorb earth essence ×59")
