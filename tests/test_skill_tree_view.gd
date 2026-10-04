extends GutTest
## The Tree tab's drawing: the camera as a function of selection and zoom, the panels, the edges and the mouse signals.

var skills: Array
var rules: SkillRulesEngine
var compendium: CompendiumModel
var model: Dictionary

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, [])
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	rules.start_run()
	for id in compendium.states():
		compendium.raise(id, CompendiumModel.State.OWNED_ONCE)
	model = SkillTreeModel.build(rules, compendium, {}, [], "slime")

func _view(sel: String, overview := false) -> SkillTreeView:
	var v := SkillTreeView.new()
	add_child_autofree(v)
	v.show_model(model, sel, overview)
	return v

func _box() -> Rect2:
	return Rect2(Vector2.ZERO, SkillTreeView.BOX.size)

func _node_rect(cam: Dictionary, id: String) -> Rect2:
	return Rect2(cam["offset"] + model["nodes"][id]["pos"] * cam["scale"], SkillTreeModel.NODE_SIZE * cam["scale"])

func _button(index: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = true
	return ev

func _stub_model() -> void:
	compendium = CompendiumModel.new(skills, [])
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	model = SkillTreeModel.build(rules, compendium, {}, [], "slime")

func test_the_camera_is_a_pure_function_of_selection_and_zoom() -> void:
	for id in model["nodes"]:
		assert_eq(SkillTreeView.camera(model, id, false), SkillTreeView.camera(model, id, false), id)
	var a := _view("leap")
	var b := _view("leap")
	assert_eq(a.panel_for("leap").position, b.panel_for("leap").position, "a rebuild draws the same picture")

func test_the_normal_camera_keeps_every_selection_inside_the_box() -> void:
	for id in model["nodes"]:
		var cam := SkillTreeView.camera(model, id, false)
		assert_eq(cam["scale"], 1.0)
		assert_true(_box().encloses(_node_rect(cam, id)), "%s at %s" % [id, _node_rect(cam, id)])

func test_a_selection_and_its_edge_neighbors_share_the_screen_when_they_fit() -> void:
	for id in model["nodes"]:
		var group := SkillTreeView.neighborhood(model, id)
		if group.size.x > _box().size.x or group.size.y > _box().size.y:
			continue
		var cam := SkillTreeView.camera(model, id, false)
		var shown := Rect2(cam["offset"] + group.position, group.size)
		assert_true(_box().encloses(shown), "%s and its neighbors at %s" % [id, shown])

func test_the_overview_fits_the_whole_canvas() -> void:
	var cam := SkillTreeView.camera(model, "leap", true)
	assert_lt(cam["scale"], 1.0)
	for id in model["nodes"]:
		assert_true(_box().encloses(_node_rect(cam, id)), id)

func test_the_normal_zoom_labels_a_node_with_its_name() -> void:
	var labels := _view("leap").panel_for("leap").find_children("*", "Label", true, false)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Leap")

func test_a_stub_is_drawn_without_its_name() -> void:
	_stub_model()
	var labels := _view("water_blade").panel_for("water_blade").find_children("*", "Label", true, false)
	assert_eq(labels[0].text, "???")

func test_the_overview_draws_dots_without_labels() -> void:
	var v := _view("leap", true)
	assert_eq(v.find_children("*", "Label", true, false).size(), 0)
	assert_lt(v.panel_for("leap").size.x, SkillTreeModel.NODE_SIZE.x)

func test_edges_are_bright_when_known_and_dim_to_a_stub() -> void:
	var v := _view("leap", true)
	assert_eq(v.segments.size(), model["edges"].size())
	assert_true(v.segments.all(func(s): return s["color"] == SkillScreen.COL_BORDER))
	_stub_model()
	var stubbed := _view("hydraulic_propulsion", true)
	assert_eq(stubbed.segments.map(func(s): return s["color"]), [SkillScreen.COL_DIM, SkillScreen.COL_DIM])

func test_panels_wholly_outside_the_box_are_not_built() -> void:
	var v := _view(SkillTreeModel.root(model))
	assert_lt(v.panel_count(), model["nodes"].size(), "at the normal zoom the canvas is wider than the box")
	for c in v.get_children():
		assert_true(_box().intersects(Rect2(c.position, c.size)), str(c.name))

func test_a_click_on_a_node_asks_for_it_once_the_frame_is_over() -> void:
	var v := _view("leap")
	watch_signals(v)
	v.panel_for("leap").gui_input.emit(_button(MOUSE_BUTTON_LEFT))
	assert_signal_not_emitted(v, "node_clicked", "deferred: the panel is still inside its own gui_input")
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(v, "node_clicked", ["leap"])

func test_the_wheel_asks_for_a_zoom_and_a_click_on_empty_space_asks_for_nothing() -> void:
	var v := _view("leap")
	watch_signals(v)
	v.gui_input.emit(_button(MOUSE_BUTTON_WHEEL_DOWN))
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(v, "zoom_requested", [true])
	v.gui_input.emit(_button(MOUSE_BUTTON_WHEEL_UP))
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(v, "zoom_requested", [false])
	v.gui_input.emit(_button(MOUSE_BUTTON_LEFT))
	await wait_process_frames(1)
	assert_signal_not_emitted(v, "node_clicked")

func test_with_the_forms_band_every_group_is_no_taller_than_the_box_and_shares_the_screen_when_it_fits() -> void:
	var forms := FormLoader.load_all()
	model = SkillTreeModel.build(rules, compendium, forms, forms.keys(), "slime")
	for id in model["nodes"]:
		var group := SkillTreeView.neighborhood(model, id)
		assert_lte(group.size.y, _box().size.y, id + " and its neighbors stack within one box")
		if group.size.x > _box().size.x:
			continue  # a stage-2 or stage-3 form's neighbors span three columns: see the Self-Review
		var cam := SkillTreeView.camera(model, id, false)
		assert_true(_box().encloses(Rect2(cam["offset"] + group.position, group.size)), id)
