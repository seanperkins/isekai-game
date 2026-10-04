extends GutTest
## The Tree tab on the skill screen: moving the selection with keys, the D-pad, the stick and the mouse, the zoom, the camera
## across rebuilds, the card, and the forms band.

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
	PadInput.reset()
	get_tree().paused = false

func _discover_all() -> void:
	for id in compendium.states():
		compendium.raise(id, CompendiumModel.State.OWNED_ONCE)

func _open_tree() -> void:
	screen.open()
	screen.switch_tab(1)

func test_the_tree_tab_opens_on_the_root() -> void:
	_open_tree()
	assert_eq(screen.tab(), "tree")
	assert_ne(screen.selected_id(), "")
	assert_eq(screen.selected_id(), SkillTreeModel.root(screen.tree_model()))
	assert_not_null(screen.tree_view())

func test_the_direction_keys_and_the_dpad_follow_neighbor() -> void:
	_discover_all()
	_open_tree()
	var first := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.RIGHT)
	assert_ne(first, screen.selected_id(), "the first press must move, or this proves nothing")
	var presses := [[KEY_RIGHT, Vector2i.RIGHT], [KEY_S, Vector2i.DOWN], [KEY_A, Vector2i.LEFT], [KEY_UP, Vector2i.UP]]
	for p in presses:
		var expected := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), p[1])
		PadInput.key(p[0])
		assert_eq(screen.selected_id(), expected, str(p))
	var down := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.DOWN)
	PadInput.button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(screen.selected_id(), down)

func test_the_left_stick_moves_the_selection_in_all_four_directions_with_the_repeat() -> void:
	_discover_all()
	_open_tree()
	for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var expected := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), dir)
		Controls.last_stick = Vector2(dir)
		screen._process(0.016)
		assert_eq(screen.selected_id(), expected, str(dir))
		Controls.last_stick = Vector2.ZERO
		screen._process(0.016)
	var one := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.DOWN)
	var two := SkillTreeModel.neighbor(screen.tree_model(), one, Vector2i.DOWN)
	assert_ne(two, one, "needs two steps down to prove the repeat")
	Controls.last_stick = Vector2(0, 1)
	screen._process(0.016)
	assert_eq(screen.selected_id(), one)
	screen._process(0.2)
	assert_eq(screen.selected_id(), one, "held, inside the delay")
	screen._process(0.2)
	assert_eq(screen.selected_id(), two, "held past the delay: repeat")

func test_tree_zoom_flips_between_the_two_levels_from_the_key_and_the_stick_click() -> void:
	_open_tree()
	assert_false(screen.tree_overview())
	PadInput.key(KEY_Z)
	assert_true(screen.tree_overview())
	assert_eq(screen.tree_view().find_children("*", "Label", true, false).size(), 0, "the overview has no labels")
	PadInput.button(JOY_BUTTON_LEFT_STICK)
	assert_false(screen.tree_overview())

func test_a_tab_switch_resets_the_tree_and_tree_zoom_does_nothing_elsewhere() -> void:
	_discover_all()
	_open_tree()
	PadInput.key(KEY_RIGHT)
	PadInput.key(KEY_Z)
	screen.switch_tab(0)
	PadInput.key(KEY_Z)
	screen.switch_tab(1)
	assert_false(screen.tree_overview())
	assert_eq(screen.selected_id(), SkillTreeModel.root(screen.tree_model()))

func test_the_camera_is_the_same_after_a_rebuild_and_keeps_the_selection_in_the_box() -> void:
	_discover_all()
	_open_tree()
	for i in 3:
		screen.tree_move(Vector2i.DOWN)
	var id := screen.selected_id()
	var before := screen.tree_view().panel_for(id).get_global_rect()
	screen.open()  # rebuilds the open tab
	var after := screen.tree_view().panel_for(id).get_global_rect()
	assert_eq(after, before)
	assert_true(SkillTreeView.BOX.encloses(after))

func test_the_tree_tab_stays_on_the_screen_at_both_zooms() -> void:
	_discover_all()
	_open_tree()
	for overview in [false, true]:
		screen.set_tree_overview(overview)
		for c in screen.find_children("*", "Control", true, false):
			var r: Rect2 = c.get_global_rect()
			assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))

func test_a_scheme_change_keeps_the_selection_and_the_zoom_and_switches_the_hint() -> void:
	_discover_all()
	_open_tree()
	PadInput.key(KEY_RIGHT)
	PadInput.key(KEY_Z)
	var sel := screen.selected_id()
	assert_string_contains(screen.hint_text(), "Z Zoom")
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.9)  # the pad becomes the scheme: Controls.scheme_changed rebuilds the open screen
	assert_string_contains(screen.hint_text(), "L3 Zoom")
	assert_eq(screen.selected_id(), sel)
	assert_true(screen.tree_overview())

func test_the_card_shows_the_selected_node_and_a_stub_shows_no_name() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	_open_tree()
	screen.select_tree_node("water_blade")
	var card := "\n".join(screen.detail_texts())
	assert_string_contains(card, "???")
	assert_false(card.contains("Water Blade"))
	screen.select_tree_node("appraisal")
	assert_string_contains("\n".join(screen.detail_texts()), "Appraisal")

func test_accept_on_the_tree_changes_nothing() -> void:
	_open_tree()
	var slots_before: Array = player.skillset.slots.slots.duplicate()
	screen.accept()
	assert_eq(player.skillset.slots.slots, slots_before)
	assert_true(screen.is_open())
	assert_eq(screen.tab(), "tree")

func test_the_tree_zoom_action_has_a_key_and_a_stick_click() -> void:
	Controls.ensure_actions()
	var evs := InputMap.action_get_events("tree_zoom")
	assert_true(evs.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_Z))
	assert_true(evs.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_LEFT_STICK))
