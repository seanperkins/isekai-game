extends GutTest
## Skill screen sounds, the Sound tab and its layout, and the HUD's denied and ticker events.

var seen: Array = []
var rules: SkillRulesEngine
var compendium: CompendiumModel
var skills: Array
var player: Player
var screen: SkillScreen

func _record(n: String, t: Dictionary) -> void:
	seen.append([n, t])

func _names() -> Array:
	return seen.map(func(e): return e[0])

func before_each() -> void:
	seen = []
	EventBus.world_event.connect(_record)
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
	EventBus.world_event.disconnect(_record)
	get_tree().paused = false
	Audio.settings = AudioSettings.new()
	Audio.settings.apply()

func test_opening_and_closing_the_screen_emit_menu_events() -> void:
	screen.open()
	screen.close()
	assert_eq(_names(), ["menu_opened", "menu_closed"])

func test_moving_and_switching_tabs_emit_menu_move() -> void:
	screen.open()
	seen = []
	screen.switch_tab(1)
	assert_eq(_names(), ["menu_move"])

func test_moving_the_selection_emits_only_when_it_moves() -> void:
	screen.open()
	seen = []
	screen.move(-1)  # already at the top
	assert_eq(seen, [])

func test_there_are_five_tabs_and_the_wrap_includes_sound() -> void:
	assert_eq(SkillScreen.TABS.size(), 5)
	screen.open()
	screen.switch_tab(4)
	assert_eq(screen.tab(), "sound")
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "sound")

func test_the_five_tabs_fit_the_screen_and_their_labels_fit_the_tabs() -> void:
	screen.open()
	var panels: Array = screen._tab_labels
	assert_eq(panels.size(), 5)
	for p in panels:
		assert_eq(p.size.x, SkillScreen.TAB_W)
		var label: Label = p.get_child(0)
		var text_width := label.get_theme_default_font().get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SkillScreen.FONT_MAIN).x
		assert_lte(text_width, SkillScreen.TAB_W, label.text)
	var last: Panel = panels[4]
	assert_lt(last.position.x + last.size.x, 612.0)
	for i in range(1, 5):
		assert_gt(panels[i].position.x, panels[i - 1].position.x + panels[i - 1].size.x - 0.5, "no overlap")

func test_the_sound_tab_lists_four_sliders_and_adjusts_the_selected_one() -> void:
	screen.open()
	screen.switch_tab(4)
	var rows: Array = SkillScreenModel.sound_rows(Audio.settings)
	assert_eq(rows.map(func(r): return r["id"]), ["master", "music", "ambience", "sfx"])
	assert_almost_eq(Audio.settings.values["master"], 0.8, 0.0001)
	seen = []
	screen.adjust(1)
	assert_almost_eq(Audio.settings.values["master"], 0.9, 0.0001)
	assert_has(_names(), "menu_move")
	screen.move(1)
	screen.adjust(-1)
	assert_almost_eq(Audio.settings.values["music"], 0.7, 0.0001)

func test_adjust_does_nothing_off_the_sound_tab() -> void:
	screen.open()
	screen.adjust(1)
	assert_almost_eq(Audio.settings.values["master"], 0.8, 0.0001)

func test_a_changed_slider_is_saved_when_the_screen_closes() -> void:
	screen.open()
	screen.switch_tab(4)
	screen.adjust(-1)
	assert_true(Audio.settings.dirty)
	screen.close()
	assert_false(Audio.settings.dirty)

func test_every_control_on_the_sound_tab_stays_on_the_screen() -> void:
	screen.open()
	screen.switch_tab(4)
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))
