extends GutTest
## Choosing an evolution on the Skills tab: a confirming second press, the card's lines, and what the lists hide.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var announcer: AnnouncerQueue
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
	compendium = CompendiumModel.new(skills, creature_list)
	announcer = AnnouncerQueue.new()
	CoreWiring.connect_core(rules, compendium, announcer)
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _emit(ev: String, tags: Dictionary, n: int) -> void:
	for i in n:
		rules.handle_event(ev, tags)

func _ready_both() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 12)  # Lv3: Water Blade and Jet Dash together

func _screen() -> SkillScreen:
	var s := SkillScreen.new()
	add_child_autofree(s)
	s.bind(player, rules, compendium, skills_by_id.values())
	s.open()
	return s

func _select(s: SkillScreen, id: String) -> void:
	var guard := 0
	while s.selected_id() != id and guard < 60:
		s.move(1)
		guard += 1
	assert_eq(s.selected_id(), id)

func _detail(s: SkillScreen) -> String:
	return "\n".join(s.detail_texts())

func test_the_first_press_arms_and_the_second_evolves() -> void:
	_ready_both()
	player.award_xp(10)
	var s := _screen()
	_select(s, "water_blade")
	s.accept()
	assert_eq(rules.level_of("water_blade"), 0, "the first press only arms")
	assert_string_contains(_detail(s), "Press again to choose")
	s.accept()
	assert_eq(rules.level_of("water_blade"), 1)
	assert_true(rules.is_closed("jet_dash"))
	s.close()

func test_the_card_names_what_it_replaces_and_closes() -> void:
	_ready_both()
	var s := _screen()
	_select(s, "water_blade")
	var text := _detail(s)
	assert_string_contains(text, "Replaces Hydraulic Propulsion")
	assert_string_contains(text, "Closes: Jet Dash")
	s.close()

func test_moving_the_selection_disarms() -> void:
	_ready_both()
	player.award_xp(10)
	var s := _screen()
	_select(s, "water_blade")
	s.accept()
	s.move(1)
	s.move(-1)
	assert_false(_detail(s).contains("Press again to choose"))
	s.accept()
	assert_eq(rules.level_of("water_blade"), 0, "armed again, not evolved")
	s.close()

func test_closing_disarms() -> void:
	_ready_both()
	player.award_xp(10)
	var s := _screen()
	_select(s, "water_blade")
	s.accept()
	s.close()
	s.open()
	_select(s, "water_blade")
	s.accept()
	assert_eq(rules.level_of("water_blade"), 0, "the reopened screen needs a fresh first press")
	s.close()

func test_a_short_press_never_evolves_and_the_card_says_what_is_short() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	_emit("skill_used", {"id": "poison_breath"}, 24)  # Lv4: Miasma and Venom Bolt together
	var s := _screen()
	_select(s, "miasma")
	s.accept()
	s.accept()
	assert_eq(rules.level_of("miasma"), 0)
	var text := _detail(s)
	assert_string_contains(text, "needs 2 more water, 6 more dark")
	assert_false(text.contains("Press again to choose"))
	s.close()

func test_a_retired_parent_is_not_a_row() -> void:
	_ready_both()
	rules.evolve("water_blade")
	var rows := SkillScreenModel.skill_rows(rules, skills_by_id.values())
	assert_false(rows.any(func(r): return r.get("id", "") == "hydraulic_propulsion"))
	assert_true(rows.any(func(r): return r.get("id", "") == "water_blade"))

func test_only_a_skill_never_reached_counts_toward_the_locked_row() -> void:
	_ready_both()
	assert_true(SkillScreenModel.counts_as_locked(rules, skills_by_id["toughness"]), "an ordinary locked skill")
	assert_false(SkillScreenModel.counts_as_locked(rules, skills_by_id["water_blade"]), "a ready evolution")
	rules.evolve("water_blade")
	assert_false(SkillScreenModel.counts_as_locked(rules, skills_by_id["hydraulic_propulsion"]), "a retired parent")
	assert_false(SkillScreenModel.counts_as_locked(rules, skills_by_id["jet_dash"]), "a closed evolution")

func test_appraisal_lv4_does_not_advertise_a_closed_evolution() -> void:
	_ready_both()
	rules.evolve("water_blade")
	var report := compendium.self_report(4, rules)
	assert_false(report["evolutions"].any(func(e): return e["id"] == "jet_dash"))

func test_an_evolved_skills_card_says_where_it_came_from() -> void:
	_ready_both()
	player.award_xp(10)
	var s := _screen()
	_select(s, "water_blade")
	s.accept()
	s.accept()
	_select(s, "water_blade")
	assert_string_contains(_detail(s), "Evolved from Hydraulic Propulsion")
	s.close()

func test_a_successful_evolve_clears_the_armed_state() -> void:
	_ready_both()
	player.award_xp(10)
	var s := _screen()
	_select(s, "water_blade")
	s.accept()
	s.accept()
	assert_eq(s._armed, "")
	s.close()

func test_switching_tabs_disarms() -> void:
	_ready_both()
	player.award_xp(10)
	var s := _screen()
	_select(s, "water_blade")
	s.accept()
	s.switch_tab(4)
	s.switch_tab(0)
	_select(s, "water_blade")
	s.accept()
	assert_eq(rules.level_of("water_blade"), 0, "the tab round trip disarmed it: this press only arms")
	s.close()

func test_a_retired_parent_is_not_capped() -> void:
	rules.set_stage_cap(3)
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 30)
	assert_true(rules.is_capped("hydraulic_propulsion"))
	rules.evolve("water_blade")
	assert_false(rules.is_capped("hydraulic_propulsion"))

func test_advancing_the_body_after_an_evolution_changes_no_branch() -> void:
	_ready_both()
	rules.evolve("water_blade")
	player.progression.add_xp(Progression.stage_total(1))
	assert_true(player.advance_form("tempest") or player.advance_form("tide"))
	assert_true(rules.is_retired("hydraulic_propulsion"))
	assert_true(rules.is_closed("jet_dash"))
	assert_true(rules.owned().has("water_blade"))
	assert_false(rules.owned().has("hydraulic_propulsion"))
