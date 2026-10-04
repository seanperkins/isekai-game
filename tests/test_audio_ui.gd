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
	PadInput.reset()
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

func test_there_are_five_tabs_and_sound_is_not_one_of_them() -> void:
	assert_eq(SkillScreen.TABS, ["skills", "tree", "compendium", "bestiary", "map"])
	screen.open()
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "map")

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

# --- the Settings menu (the sliders that were the Sound tab) ---

func test_the_settings_key_opens_the_menu_over_the_tabs_and_back_returns_to_the_same_tab() -> void:
	screen.open()
	screen.switch_tab(2)
	var before := screen.tab()
	PadInput.key(KEY_TAB)
	assert_true(screen.settings_menu.is_open())
	assert_true(screen.is_open(), "the menu sits on top of the tabs")
	PadInput.key(KEY_BACKSPACE)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open())
	assert_eq(screen.tab(), before)

func test_r3_opens_the_menu_and_b_closes_only_the_menu() -> void:
	screen.open()
	PadInput.button(JOY_BUTTON_RIGHT_STICK)
	assert_true(screen.settings_menu.is_open())
	PadInput.button(JOY_BUTTON_B)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open())
	assert_true(get_tree().paused)

func test_esc_and_start_close_only_the_menu_and_send_no_menu_closed() -> void:
	screen.open()
	screen.open_settings()
	seen = []
	PadInput.key(KEY_ESCAPE)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open(), "Esc backs out of the menu, not out of the pause screen")
	assert_true(get_tree().paused)
	assert_false(_names().has("menu_closed"), "Audio saves on menu_closed: the sub-menu must not send it")
	screen.open_settings()
	PadInput.button(JOY_BUTTON_START)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open())

func test_the_settings_menu_lists_four_sliders_and_adjusts_the_selected_one() -> void:
	screen.open()
	screen.open_settings()
	assert_eq(screen.settings_menu.rows().map(func(r): return r["id"]), ["master", "music", "ambience", "sfx"])
	assert_almost_eq(Audio.settings.values["master"], 0.8, 0.0001)
	seen = []
	screen.settings_menu.adjust(1)
	assert_almost_eq(Audio.settings.values["master"], 0.9, 0.0001)
	assert_has(_names(), "menu_move")
	screen.settings_menu.move(1)
	screen.settings_menu.adjust(-1)
	assert_almost_eq(Audio.settings.values["music"], 0.7, 0.0001)

func test_keys_move_and_adjust_inside_the_menu_and_the_tabs_do_not_switch() -> void:
	screen.open()
	var before := screen.tab()
	screen.open_settings()
	PadInput.key(KEY_S)
	assert_eq(screen.settings_menu.selected_id(), "music")
	PadInput.key(KEY_D)
	assert_almost_eq(Audio.settings.values["music"], 0.9, 0.0001)
	PadInput.key(KEY_E)  # tab_next: swallowed while the menu is open
	assert_eq(screen.tab(), before)
	assert_true(screen.settings_menu.is_open())

func test_a_changed_slider_is_saved_when_the_screen_closes() -> void:
	screen.open()
	screen.open_settings()
	screen.settings_menu.adjust(-1)
	assert_true(Audio.settings.dirty)
	screen.close()
	assert_false(screen.settings_menu.is_open(), "closing the screen closes the menu too")
	assert_false(Audio.settings.dirty)

func test_every_control_in_the_settings_menu_stays_on_the_screen() -> void:
	screen.open()
	screen.open_settings()
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))

func test_the_hints_name_the_settings_button_for_the_scheme() -> void:
	screen.open()
	assert_string_contains(screen.hint_text(), "Tab Settings")
	screen.open_settings()
	assert_string_contains(screen.settings_menu.hint_text(), "Esc Back")
	screen.settings_menu.close()
	Controls.using_joypad = true
	screen.open()  # refreshes with the pad's words
	assert_string_contains(screen.hint_text(), "R3 Settings")
