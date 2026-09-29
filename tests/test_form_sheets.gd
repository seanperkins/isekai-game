extends GutTest
## The Weaver lineage is drawn end to end: four sheets of the slime's 21 frames each, at the form's scale.

const SETS := ["form_weaver", "form_snare", "form_arachne", "form_silkbound"]

func _listed(set_name: String) -> Array:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://tools/art/%s_frames.json" % set_name))
	return json.data["frames"]

func test_every_form_sheet_has_the_slimes_twenty_one_frames() -> void:
	var base := SpriteSheet.load_set("slime")
	for set_name in SETS:
		assert_true(SpriteSheet.available(set_name), set_name)
		var sheet := SpriteSheet.load_set(set_name)
		assert_eq(sheet.frame_names().size(), 21, set_name)
		for n in base.frame_names():
			assert_true(sheet.has_frame(n), "%s/%s" % [set_name, n])

func test_each_frame_is_the_listed_scaled_width_and_stands_on_the_floor_line() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		for f in _listed(set_name):
			var size := sheet.frame_size(f["name"])
			assert_eq(int(size.x), int(f["width"]), "%s/%s width" % [set_name, f["name"]])
			var lowest := -INF
			for p in sheet.hurt(f["name"]):
				lowest = maxf(lowest, p.y)
			assert_almost_eq(lowest, 0.0, 0.01, "%s/%s stands on the floor line" % [set_name, f["name"]])

func test_a_bigger_form_draws_bigger_than_the_base_slime() -> void:
	var base := SpriteSheet.load_set("slime").frame_size("idle_1").x
	var widths := []
	for set_name in SETS:
		widths.append(SpriteSheet.load_set(set_name).frame_size("idle_1").x)
	assert_gt(widths[0], base, "Weaver is bigger than the slime")
	assert_gt(widths[1], widths[0], "Snare is bigger than Weaver")
	assert_gt(widths[3], widths[1], "Silkbound is the biggest")

func test_only_the_tackle_has_an_attack_shape_in_every_form() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		for n in sheet.frame_names():
			assert_eq(sheet.attack(n).size() >= 3, n == "tackle", "%s/%s" % [set_name, n])

func test_every_slime_clip_plays_on_every_form_sheet() -> void:
	var clips := SlimeAnimator.load_clips()
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		for state in SlimeState.ALL:
			for n in clips[state]["frames"] + clips[state].get("exit", []):
				assert_true(sheet.has_frame(n), "%s: %s uses %s" % [set_name, state, n])

func test_the_form_data_validates_with_its_art_present() -> void:
	var forms := FormLoader.load_all()
	var skill_ids: Array = []
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			skill_ids.append(d.id)
	var errs := FormValidator.validate(forms, skill_ids, true)
	assert_eq(errs.size(), 0, str(errs))

func test_no_hit_shape_of_a_form_balloons_past_its_pixels() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		var image := sheet.texture.get_image()
		var shape_total := 0.0
		var pixel_total := 0.0
		for n in sheet.frame_names():
			var r := (sheet.frame_texture(n) as AtlasTexture).region
			var opaque := 0
			for y in int(r.size.y):
				for x in int(r.size.x):
					if image.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a >= 0.5:
						opaque += 1
			var poly := sheet.hurt(n)
			var a := 0.0
			for i in poly.size():
				var p := poly[i]
				var q := poly[(i + 1) % poly.size()]
				a += p.x * q.y - q.x * p.y
			shape_total += absf(a) * 0.5
			pixel_total += opaque
		assert_lte(shape_total, pixel_total * 1.15, "%s: shapes hug the pixels" % set_name)
