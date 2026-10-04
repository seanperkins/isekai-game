extends GutTest
## The HUD's second line: a power evolution that is ready and affordable, named once per parent.

var rules: SkillRulesEngine
var player: Player
var hud: Hud

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	hud = Hud.new()
	add_child_autofree(hud)
	hud.bind(player, rules, compendium, AnnouncerQueue.new())

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _ready_hydraulic() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	for i in 12:
		rules.handle_event("skill_used", {"id": "hydraulic_propulsion"})  # Lv3: Water Blade and Jet Dash are ready

func test_there_is_no_line_before_anything_is_ready() -> void:
	assert_eq(hud.evolve_text(), "")

func test_a_ready_and_affordable_evolution_gets_a_line_naming_its_power() -> void:
	_ready_hydraulic()
	assert_string_contains(hud.evolve_text(), "Evolve: Hydraulic Propulsion")

func test_one_line_per_ready_parent_not_one_per_branch() -> void:
	_ready_hydraulic()
	assert_true(rules.is_evolution_ready("water_blade") and rules.is_evolution_ready("jet_dash"))
	assert_eq(hud.evolve_text().count("Evolve:"), 1)

func test_a_ready_but_unaffordable_evolution_has_no_line_until_it_can_be_paid() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	for i in 24:
		rules.handle_event("skill_used", {"id": "poison_breath"})
	assert_true(rules.is_evolution_ready("miasma"))
	assert_eq(hud.evolve_text(), "")
	for i in 2:
		rules.handle_event("absorbed", {"essence": "water", "source": "test"})
	for i in 6:
		rules.handle_event("absorbed", {"essence": "dark", "source": "test"})
	assert_string_contains(hud.evolve_text(), "Evolve: Poison Breath")

func test_the_line_goes_once_the_evolution_is_taken() -> void:
	_ready_hydraulic()
	assert_true(rules.evolve("water_blade"))
	assert_eq(hud.evolve_text(), "")

func test_both_lines_show_together_at_the_level_cap() -> void:
	_ready_hydraulic()
	player.progression.add_xp(Progression.stage_total(1))
	var text := hud.evolve_text()
	assert_string_contains(text, "Your body can evolve")
	assert_string_contains(text, "Evolve: Hydraulic Propulsion")
	assert_eq(text.split("\n").size(), 2)
