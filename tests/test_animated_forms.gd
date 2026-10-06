extends GutTest
## The twins whose forms have been animated (data/form_clips.json, assets/sheets/anim_<form>): the sheets are whole, every clip plays on its
## sheet, and the twin that wears the form really plays it.

var _clips := {}
var _speeds := {}

func before_all() -> void:
	_clips = SlimeAnimator.load_clips(Enemy.form_clips_path)
	_speeds = _clips.get("_walk_speeds", {})
	_clips.erase("_walk_speeds")  # the speed each form's walk was built for is a table beside the forms, not a form

func _twin_of(form: String) -> CreatureDef:
	for d in DefLoader.load_dir("res://data/creatures"):
		if d.form == form and d.origin == "twin":
			return d
	return null

func test_there_are_animated_forms() -> void:
	assert_gt(_clips.size(), 0)

func test_every_animated_form_has_the_walk_speed_its_clips_were_built_for() -> void:
	assert_eq(_speeds.keys().size(), _clips.size())
	for form in _clips:
		assert_true(_speeds.has(form), form)
		assert_gt(float(_speeds[form]), 5.0, "%s: a walk that goes somewhere" % form)

func test_every_animated_form_has_a_sheet_with_normals_whose_frames_are_all_one_size() -> void:
	for form in _clips:
		var set_name: String = "anim_" + form
		assert_true(SpriteSheet.available(set_name), set_name)
		var sheet := SpriteSheet.load_set(set_name)
		assert_true(sheet.has_normals(), "%s is lit" % set_name)
		var size := Vector2.ZERO
		for n in sheet.frame_names():
			if size == Vector2.ZERO:
				size = sheet.frame_size(n)
			assert_eq(sheet.frame_size(n), size, "%s/%s: every frame is cut to the same box" % [set_name, n])

func test_every_clip_names_frames_its_sheet_has_and_the_states_the_engine_asks_for_are_there() -> void:
	for form in _clips:
		var sheet := SpriteSheet.load_set("anim_" + form)
		for state in _clips[form]:
			var clip: Dictionary = _clips[form][state]
			assert_gt(float(clip["fps"]), 0.0, "%s/%s" % [form, state])
			for n in clip["frames"]:
				assert_true(sheet.has_frame(n), "%s/%s uses %s" % [form, state, n])
		for state in ["idle", "walk"]:
			assert_true(_clips[form].has(state), "%s has %s" % [form, state])
		assert_eq(_clips[form].has("hurt"), _clips[form].has("downed"), "%s: a hurt pose comes with its downed one" % form)
		assert_eq(_clips[form].has("windup"), _clips[form].has("recover"), "%s: a windup comes with its recover" % form)

func test_the_loops_loop_and_the_actions_do_not() -> void:
	for form in _clips:
		for state in _clips[form]:
			var is_loop: bool = state in ["idle", "walk", "run"]
			assert_eq(bool(_clips[form][state]["loop"]), is_loop, "%s/%s" % [form, state])

func test_every_animated_form_is_worn_by_a_twin_that_plays_it() -> void:
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	for form in _clips:
		var def := _twin_of(form)
		assert_not_null(def, "a twin wears %s" % form)
		if def == null:
			continue
		var e := Enemy.new()
		e.setup(def, skills)
		add_child_autofree(e)
		e._update_visual(0.0)
		assert_eq(e._anim_state, "idle", form)
		assert_true((e.get_node("Sprite") as Sprite2D).texture is CanvasTexture, "%s is drawn lit" % form)
