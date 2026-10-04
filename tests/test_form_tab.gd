extends GutTest
## The Form tab, the HUD's evolution prompt, and the skill screen's stage-cap display.

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
	screen = SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills)

func after_each() -> void:
	get_tree().paused = false

func _to_cap() -> void:
	player.progression.add_xp(Progression.stage_total(player.progression.stage))

func _eat_everything() -> void:
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var rooms := World.load_rooms("res://data/rooms")
	for id in rooms:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			rules.handle_event("predated", {"source": c.id, "kind": "creature"})
			for e in c.essences:
				for i in int(c.essences[e]):
					rules.handle_event("absorbed", {"essence": e, "source": c.id})

# --- the tab strip ---

func test_a_new_slime_has_only_the_five_base_tabs() -> void:
	screen.open()
	assert_eq(screen.tabs(), SkillScreen.TABS.duplicate())
	assert_eq(screen.tabs().size(), 5)
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills", "the wrap is unchanged")

func test_the_form_tab_appears_once_the_body_can_evolve() -> void:
	screen.open()
	_to_cap()
	screen.open()
	assert_eq(screen.tabs().size(), 6)
	screen.switch_tab(5)
	assert_eq(screen.tab(), "form")
	screen.switch_tab(6)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "form")

func test_the_form_tab_stays_after_evolving_even_below_the_cap() -> void:
	_to_cap()
	player.advance_form("weaver")
	screen.open()
	assert_false(player.progression.can_evolve())
	assert_eq(screen.tabs().size(), 6)

func test_the_strip_layout_fits_five_or_six_tabs() -> void:
	assert_eq(SkillScreen.tab_layout(5), Vector2(102, 96), "five tabs keep today's layout")
	var six := SkillScreen.tab_layout(6)
	assert_lt(SkillScreen.TAB_X + 5.0 * six.x + six.y, 570.0, "the sixth tab ends inside the frame")
	assert_lt(six.y, 96.0)

func test_the_strip_is_rebuilt_when_the_tab_count_changes() -> void:
	screen.open()
	assert_eq(screen._tab_labels.size(), 5)
	_to_cap()
	screen.open()
	assert_eq(screen._tab_labels.size(), 6)

# --- the tab itself ---

func test_the_form_tab_lists_the_offers_the_offers_logic_gives() -> void:
	_eat_everything()
	_to_cap()
	screen.open()
	screen.switch_tab(5)
	var expected := FormOffers.offers(player.forms, player.form, rules)
	var seen: Array = []
	for i in screen._selectable:
		seen.append(screen._rows[i]["id"])
	assert_eq(seen, expected)
	assert_eq(screen.selected_id(), expected[0])

func test_five_open_lineages_are_five_selectable_rows_none_dropped() -> void:
	_eat_everything()
	_to_cap()
	screen.open()
	screen.switch_tab(5)
	assert_eq(screen._selectable.size(), 5, "every open lineage is a row")
	var seen: Array = []
	for i in screen._selectable:
		seen.append(screen._rows[i]["id"])
	assert_eq(seen, ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_choosing_an_offer_evolves_the_body() -> void:
	_eat_everything()
	_to_cap()
	screen.open()
	screen.switch_tab(5)
	var first := screen.selected_id()
	screen.accept()
	assert_eq(player.form.form_id, first)
	assert_eq(player.form.stage, 2)

func test_a_lone_offer_is_a_confirmation_that_says_so() -> void:
	_to_cap()
	player.advance_form("weaver")
	_to_cap()
	player.advance_form("snare")
	_to_cap()
	screen.open()
	screen.switch_tab(5)
	assert_eq(screen._selectable.size(), 1)
	assert_eq(screen.selected_id(), "silkbound")
	assert_true(screen.form_note().contains("only one path"))

func test_below_the_cap_the_tab_shows_the_current_body_and_no_offers() -> void:
	_to_cap()
	player.advance_form("weaver")
	screen.open()
	screen.switch_tab(5)
	assert_eq(screen._selectable.size(), 0)
	assert_true(screen.form_note().contains("Weaver"))

func test_the_last_stage_has_nothing_to_evolve_into() -> void:
	for id in ["greater_slime", "vast", "prime"]:
		_to_cap()
		player.advance_form(id)
	_to_cap()
	assert_false(player.progression.can_evolve())
	assert_eq(player.form_offers().size(), 0)

func test_the_player_reports_its_offers_only_when_it_can_evolve() -> void:
	assert_eq(player.form_offers().size(), 0)
	_eat_everything()
	_to_cap()
	assert_gt(player.form_offers().size(), 0)
	assert_true(player.form_offers()[0] is FormDef)

# --- the stage cap on the skills tab ---

func test_a_capped_skill_is_marked_in_the_rows_and_the_card() -> void:
	for i in 40 + 20 * 12:
		rules.handle_event("jumped", {"from": "ground"})
	assert_true(rules.is_capped("leap"))
	var row := {}
	for r in SkillScreenModel.skill_rows(rules, skills):
		if r.get("id", "") == "leap":
			row = r
	assert_true(row["capped"])
	var d: SkillDef
	for s in skills:
		if s.id == "leap":
			d = s
	assert_true(SkillScreenModel.detail(rules, d, player.skillset.slots)["capped"])
	assert_string_contains(SkillScreenModel.capped_text(), "evolve")

func test_an_uncapped_skill_is_not_marked() -> void:
	rules.handle_event("jumped", {"from": "ground"})
	for r in SkillScreenModel.skill_rows(rules, skills):
		if r["kind"] == "skill":
			assert_false(r["capped"], r["id"])

func test_skill_rows_show_a_number_and_a_bar_not_fifteen_pips() -> void:
	for i in 40 + 20 * 12:
		rules.handle_event("jumped", {"from": "ground"})
	screen.open()
	var pips := 0
	for c in screen._list.get_children():
		if c is ColorRect and (c as ColorRect).size == Vector2(5, 5):
			pips += 1
	assert_eq(pips, 0, "no per-level pips: a number and a compact bar")

# --- the HUD ---

func _hud() -> Hud:
	var h := Hud.new()
	add_child_autofree(h)
	h.bind(player, rules, compendium, AnnouncerQueue.new())
	return h

func test_the_hud_shows_the_cap_and_the_evolution_prompt() -> void:
	var h := _hud()
	assert_eq(h.level_text(), "Lv 1/10  XP 0/10")
	assert_eq(h.evolve_text(), "")
	_to_cap()
	assert_true(h.level_text().contains("MAX"), h.level_text())
	assert_string_contains(h.evolve_text(), "Your body can evolve")

func test_the_prompt_goes_away_after_evolving_and_never_shows_at_the_last_stage() -> void:
	var h := _hud()
	_to_cap()
	player.advance_form("weaver")
	assert_eq(h.evolve_text(), "")
	assert_true(h.level_text().begins_with("Lv 1/10"))
	for id in ["snare", "silkbound"]:
		_to_cap()
		player.advance_form(id)
	_to_cap()
	assert_eq(h.evolve_text(), "", "stage 4 has nowhere to go")

func test_the_ticker_shows_a_note_line() -> void:
	assert_eq(StatusText.ticker_text({"kind": "note", "text": "Your skills grew."}, rules), "Your skills grew.")

func test_choosing_an_offer_closes_the_menu_so_the_evolution_plays_in_the_world() -> void:
	_eat_everything()
	_to_cap()
	screen.open()
	assert_true(get_tree().paused)
	screen.switch_tab(5)
	screen.accept()
	assert_eq(player.form.stage, 2)
	assert_false(screen.is_open(), "the menu closes so the glow and the swell are seen")
	assert_false(get_tree().paused, "and the game runs, so the moment actually plays")
	assert_true(player.evolving())

# --- the form card lists only grants the player can still receive ---

func _select_form(id: String) -> void:
	var guard := 0
	while screen.selected_id() != id and guard < 30:
		screen.move(1)
		guard += 1
	assert_eq(screen.selected_id(), id)

func test_the_form_card_lists_a_receivable_grant() -> void:
	_eat_everything()
	_to_cap()
	screen.open()
	screen.switch_tab(5)
	_select_form("tide")
	assert_string_contains("\n".join(screen.detail_texts()), "Grants: Hydraulic Propulsion")

func test_the_form_card_omits_grants_the_player_has_retired() -> void:
	_eat_everything()
	for i in 12:
		rules.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_true(rules.evolve("water_blade"))
	_to_cap()
	screen.open()
	screen.switch_tab(5)
	_select_form("tide")
	assert_false("\n".join(screen.detail_texts()).contains("Grants:"), "the only grant is a retired parent")
