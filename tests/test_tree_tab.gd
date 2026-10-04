extends GutTest
## The Tree tab on the skill screen: moving the selection with keys, the D-pad, the stick and the mouse, the zoom, the camera
## across rebuilds, the card, and the forms band.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var skills: Array
var player: Player
var screen: SkillScreen
var _gut_layer: CanvasLayer
var _gut_layer_was_visible := true

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
	# GUT's own results panel is a full-screen Control on canvas layer 128, above the skill screen (layer 20): it would take every
	# real mouse click before the screen saw it. Hide it while these tests click, and put it back after.
	_gut_layer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if _gut_layer != null:
		_gut_layer_was_visible = _gut_layer.visible
		_gut_layer.visible = false

func after_each() -> void:
	if _gut_layer != null and is_instance_valid(_gut_layer):
		_gut_layer.visible = _gut_layer_was_visible
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

# --- the mouse ---

func _centre_of(id: String) -> Vector2:
	return screen.tree_view().panel_for(id).get_global_rect().get_center()

## A point inside the tree box that no panel covers (the gaps between columns are 14 px wide).
func _empty_point() -> Vector2:
	var box := SkillTreeView.BOX
	for y in range(int(box.position.y) + 2, int(box.end.y) - 2, 2):
		for x in range(int(box.position.x) + 2, int(box.end.x) - 2, 2):
			var p := Vector2(x, y)
			if not screen.tree_view().get_children().any(func(c): return c.get_global_rect().has_point(p)):
				return p
	return Vector2(-1, -1)

func test_a_real_click_on_a_node_selects_it_while_the_tree_is_paused() -> void:
	_discover_all()
	_open_tree()
	var target := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.RIGHT)
	assert_ne(target, screen.selected_id())
	assert_true(get_tree().paused, "the click must reach the view through PROCESS_MODE_ALWAYS")
	PadInput.mouse_click(_centre_of(target))
	await wait_process_frames(2)
	assert_eq(screen.selected_id(), target, "if this is red, the click is not reaching the panel through the stretch")

func test_the_wheel_flips_the_zoom() -> void:
	_open_tree()
	var centre := SkillTreeView.BOX.get_center()
	PadInput.mouse_click(centre, MOUSE_BUTTON_WHEEL_DOWN)
	await wait_process_frames(2)
	assert_true(screen.tree_overview())
	PadInput.mouse_click(centre, MOUSE_BUTTON_WHEEL_UP)
	await wait_process_frames(2)
	assert_false(screen.tree_overview())

func test_a_click_on_empty_space_changes_nothing() -> void:
	_discover_all()
	_open_tree()
	var empty := _empty_point()
	assert_ne(empty, Vector2(-1, -1), "the box has a gap somewhere")
	var sel := screen.selected_id()
	PadInput.mouse_click(empty)
	await wait_process_frames(2)
	assert_eq(screen.selected_id(), sel)
	assert_false(screen.tree_overview())

# --- the forms band ---

func test_the_tree_shows_the_forms_band_and_reads_reached_forms_from_the_progress() -> void:
	var progress := WorldProgress.new()
	progress.reach_form("weaver")
	screen.bind_world(null, progress)
	_open_tree()
	var nodes: Dictionary = screen.tree_model()["nodes"]
	assert_eq(nodes["slime"]["state"], SkillTreeModel.CURRENT)
	assert_eq(nodes["weaver"]["state"], SkillTreeModel.REACHED)

func test_a_form_card_shows_its_stage_blurb_and_grants_and_a_form_stub_shows_no_name() -> void:
	_open_tree()
	screen.select_tree_node("greater_slime")
	var gs: FormDef = player.forms["greater_slime"]
	var card := "\n".join(screen.detail_texts())
	assert_string_contains(card, gs.display_name)
	assert_string_contains(card, "Stage 2")
	assert_string_contains(card, "Grants: " + rules.get_def("regeneration").display_name)
	screen.select_tree_node("vast")
	card = "\n".join(screen.detail_texts())
	assert_string_contains(card, "???")
	assert_false(card.contains(player.forms["vast"].display_name))

func test_a_card_clips_no_wrapped_line_and_stacks_no_two_labels() -> void:
	_discover_all()
	_open_tree()
	for id in ["sticky_thread", "spore_cloud", "hydraulic_propulsion", "greater_slime", "slime"]:
		screen.select_tree_node(id)
		assert_eq(screen.selected_id(), id, "a node of a fresh soul's tree")
		var labels: Array = screen._detail.find_children("*", "Label", true, false)
		for l in labels:
			var lab := l as Label
			if lab.autowrap_mode != TextServer.AUTOWRAP_OFF:
				var n := float(lab.get_line_count())
				var needed := n * lab.get_line_height() + (n - 1.0) * lab.get_theme_constant("line_spacing")  # the renderer adds line_spacing between lines
				assert_lte(needed, lab.size.y + 0.5, "%s: '%s' is clipped" % [id, lab.text])
		for i in labels.size():
			for j in range(i + 1, labels.size()):
				assert_false(labels[i].get_rect().intersects(labels[j].get_rect()), "%s: '%s' overlaps '%s'" % [id, labels[i].text, labels[j].text])
