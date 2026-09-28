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
	assert_eq(rules.level_progress("leap"), {"current": 10, "target": 40})
	assert_eq(rules.level_progress("nope"), {"current": 0, "target": 0})

func test_skill_rows_group_owned_skills_and_tease_locked_ones() -> void:
	_emit("jumped", {}, 40)
	_emit("absorbed", {"essence": "water"}, 4)
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
	assert_eq(SkillScreenModel.condition_text(by_id["echolocation"], by_id), "Absorb sound essence ×3")
	assert_eq(SkillScreenModel.condition_text(by_id["glutton"], by_id), "Eat creatures in a row without taking damage ×5")
	assert_eq(SkillScreenModel.condition_text(by_id["jet_dash"], by_id), "Hydraulic Propulsion Lv3 and Leap Lv2")

func test_detail_card_for_an_active() -> void:
	_emit("absorbed", {"essence": "poison"}, 4)
	_emit("skill_used", {"id": "poison_breath"}, 4)
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	var card := SkillScreenModel.detail(rules, by_id["poison_breath"], player.skillset.slots)
	assert_eq(card["name"], "Poison Breath")
	assert_eq([card["level"], card["max_level"]], [1, 5])
	assert_eq(card["mp_cost"], 4)
	assert_eq(card["lines"], ["Damage 2"])
	assert_almost_eq(card["progress"], 0.5, 0.001)
	assert_eq(card["slot"], "U")

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
	s.add("c")  # c replaces a (LRU)
	s.assign(0, "a")
	assert_eq(s.slots[0], "a")
	s.assign(1, "a")  # already in slot 0: swap
	assert_eq(s.slots, [s.slots[0], "a"])
	assert_ne(s.slots[0], "a")
	s.assign(0, "not_owned")
	assert_ne(s.slots[0], "not_owned")

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
	_emit("absorbed", {"essence": "water"}, 4)
	_emit("absorbed", {"essence": "poison"}, 4)
	_screen()
	screen.open()
	assert_true(screen.row_texts().any(func(t): return t.begins_with("Leap")))
	while screen.selected_id() != "poison_breath":
		screen.move(1)
	assert_string_contains("\n".join(screen.detail_texts()), "MP cost 4")
	screen.accept()  # assign to U
	assert_eq(player.skillset.slots.slots[0], "poison_breath")
	screen.accept()  # again: to O
	assert_eq(player.skillset.slots.slots[1], "poison_breath")

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
