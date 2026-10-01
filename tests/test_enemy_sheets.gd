extends GutTest
## The four creature sheets: every listed frame is there at the listed scale, standing on the floor
## line, with shapes inside the frame, and every clip uses frames that exist.

const SETS := ["bat", "toad", "lizard", "spider", "spore_moth", "mushroom_crab", "vine_snake", "pale_moth", "glass_eel", "cave_crayfish",
	"drift_jelly", "bog_lizardman", "storm_eel", "gloom_wolf", "armed_ant", "stone_drake"]

func _listed(set_name: String) -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://tools/art/%s_frames.json" % set_name))
	return json.data

func test_every_sheet_loads_with_every_listed_frame() -> void:
	for set_name in SETS:
		assert_true(SpriteSheet.available(set_name), set_name)
		var sheet := SpriteSheet.load_set(set_name)
		var listed: Array = _listed(set_name)["frames"]
		assert_eq(sheet.frame_names().size(), listed.size(), set_name)
		for f in listed:
			assert_true(sheet.has_frame(f["name"]), "%s/%s" % [set_name, f["name"]])

func test_every_frame_has_a_traced_hurt_shape_on_the_floor_line_inside_its_frame() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		for n in sheet.frame_names():
			var size := sheet.frame_size(n)
			var hurt := sheet.hurt(n)
			assert_gte(hurt.size(), 3, "%s/%s" % [set_name, n])
			var lowest := -INF
			for p in hurt:
				lowest = maxf(lowest, p.y)
				assert_between(p.x, -size.x / 2.0 - 0.01, size.x / 2.0 + 0.01, "%s/%s" % [set_name, n])
				assert_between(p.y, -size.y - 0.01, 0.01, "%s/%s" % [set_name, n])
			assert_almost_eq(lowest, 0.0, 0.01, "%s/%s stands on the floor line" % [set_name, n])

func test_only_the_creatures_that_strike_have_attack_shapes() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		var listed: Array = _listed(set_name)["frames"]
		for f in listed:
			var expect: bool = f.has("attack_from")
			assert_eq(sheet.attack(f["name"]).size() >= 3, expect, "%s/%s" % [set_name, f["name"]])
	assert_true(_listed("lizard")["frames"].any(func(f): return f.has("attack_from")))
	assert_true(_listed("bat")["frames"].any(func(f): return f.has("attack_from")))
	assert_true(_listed("mushroom_crab")["frames"].any(func(f): return f.has("attack_from")))
	assert_true(_listed("vine_snake")["frames"].any(func(f): return f.has("attack_from")))
	assert_false(_listed("spore_moth")["frames"].any(func(f): return f.has("attack_from")), "the moth strikes with its puffs, not its body")
	assert_true(_listed("glass_eel")["frames"].any(func(f): return f.has("attack_from")), "the eel's dart")
	assert_true(_listed("storm_eel")["frames"].any(func(f): return f.has("attack_from")), "the storm eel's dart")
	assert_true(_listed("cave_crayfish")["frames"].any(func(f): return f.has("attack_from")), "the crayfish's lunge")
	assert_false(_listed("drift_jelly")["frames"].any(func(f): return f.has("attack_from")), "the jelly stings by touch")
	assert_false(_listed("bog_lizardman")["frames"].any(func(f): return f.has("attack_from")), "the lizardman strikes with its spear")
	assert_true(_listed("gloom_wolf")["frames"].any(func(f): return f.has("attack_from")), "the wolf's leap")
	assert_false(_listed("armed_ant")["frames"].any(func(f): return f.has("attack_from")), "the ant strikes by touch")
	assert_false(_listed("stone_drake")["frames"].any(func(f): return f.has("attack_from")), "the drake's hit is the slam check, not a frame")

func test_frames_keep_a_shared_scale_within_a_creature() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		var anchor: String = _listed(set_name)["anchor"]
		var ref := sheet.frame_size(anchor)
		for n in sheet.frame_names():
			var s := sheet.frame_size(n)
			assert_between(maxf(s.x, s.y), ref.x * 0.35, ref.x * 2.0, "%s/%s drifted from the anchor's scale (a thin upright pose counts by its height)" % [set_name, n])

func test_every_clip_uses_frames_that_exist_and_every_state_has_a_clip() -> void:
	var clips := SlimeAnimator.load_clips(Enemy.CLIPS)
	var states := {
		"bat": ["fly", "hover", "warn", "dive", "stunned", "hurt", "downed"],
		"toad": ["idle", "walk", "puff", "spit", "stunned", "hurt", "downed"],
		"lizard": ["idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"],
		"spider": ["hang", "drop", "crawl", "stunned", "hurt", "downed"],
		"spore_moth": ["fly", "stunned", "hurt", "downed"],
		"pale_moth": ["fly", "stunned", "hurt", "downed"],
		"mushroom_crab": ["idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"],
		"vine_snake": ["hide", "coil", "lunge", "rest", "slither", "stunned", "hurt", "downed"],
		"glass_eel": ["swim", "warn", "dart", "stunned", "hurt", "downed"],
		"cave_crayfish": ["idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"],
		"drift_jelly": ["drift", "stunned", "hurt", "downed"],
		"bog_lizardman": ["idle", "walk", "puff", "spit", "stunned", "hurt", "downed"],
		"storm_eel": ["swim", "warn", "dart", "stunned", "hurt", "downed"],
		"gloom_wolf": ["idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"],
		"armed_ant": ["idle", "walk", "stunned", "hurt", "downed"],
		"stone_drake": ["idle", "walk", "windup", "stomp", "stunned", "hurt", "downed"]}
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		for state in states[set_name]:
			assert_true(clips[set_name].has(state), "%s/%s has a clip" % [set_name, state])
			var clip: Dictionary = clips[set_name][state]
			assert_gt(float(clip["fps"]), 0.0)
			for fr in clip["frames"]:
				assert_true(sheet.has_frame(fr), "%s/%s uses a frame that is not on the sheet: %s" % [set_name, state, fr])

func test_every_frame_makes_a_valid_hit_shape_facing_either_way() -> void:
	# the engine decomposes a collision polygon into convex parts; a degenerate one logs an error every time the frame shows
	# (the vine snake's slither_2, mirrored, did) and leaves the body with no physics shape
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		for left in [false, true]:
			for n in sheet.frame_names():
				var shapes := SlimeShapes.new()
				add_child_autofree(shapes)
				shapes.refresh(sheet, n, left)
				assert_false(Geometry2D.decompose_polygon_in_convex(shapes.hurt_poly.polygon).is_empty(),
					"%s/%s hurt shape (left=%s) decomposes" % [set_name, n, left])
