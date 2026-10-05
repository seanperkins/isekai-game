extends GutTest
## The opening's art is whole: the three sheets exist, every clip names real frames, every command the shipped copy offers (and
## the old lady's) has a commuter clip, and the backdrop is the 640x360 street.

const SETS := ["commuter", "truck", "grandma"]

func test_the_sheets_exist() -> void:
	for set_name in SETS:
		assert_true(SpriteSheet.available(set_name), set_name)

func test_every_clip_names_frames_that_are_on_its_sheet() -> void:
	var clips := SlimeAnimator.load_clips(OpeningActor.CLIPS)
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		assert_true(clips.has(set_name), set_name)
		for clip_name in clips[set_name]:
			var clip: Dictionary = clips[set_name][clip_name]
			assert_gt(float(clip["fps"]), 0.0, "%s/%s has a frame rate" % [set_name, clip_name])
			for frame in clip["frames"]:
				assert_true(sheet.has_frame(frame), "%s/%s names %s, which the sheet lacks" % [set_name, clip_name, frame])

func test_every_frame_on_a_sheet_is_used_by_a_clip() -> void:
	var clips := SlimeAnimator.load_clips(OpeningActor.CLIPS)
	for set_name in SETS:
		var used := {}
		for clip_name in clips[set_name]:
			for frame in clips[set_name][clip_name]["frames"]:
				used[frame] = true
		for frame in SpriteSheet.load_set(set_name).frame_names():
			assert_true(used.has(frame), "%s/%s is on the sheet but no clip plays it" % [set_name, frame])

func test_the_commuter_has_a_clip_for_every_command_the_copy_offers_and_for_the_battle() -> void:
	var clips: Dictionary = SlimeAnimator.load_clips(OpeningActor.CLIPS)["commuter"]
	var def := load("res://data/opening/opening.tres") as OpeningDef
	for choice in def.choices:
		assert_true(clips.has(OpeningScene.ACTION_CLIPS.get(choice["id"], "")), "a clip for the command %s" % choice["id"])
	assert_true(clips.has(OpeningScene.ACTION_CLIPS.get(def.grandma["id"], "")), "a clip for saving the old lady")
	for needed in ["idle", "hurt", "ko"]:
		assert_true(clips.has(needed), needed)
	var truck: Dictionary = SlimeAnimator.load_clips(OpeningActor.CLIPS)["truck"]
	for needed in ["idle", "charge", "idle_angry", "charge_angry"]:
		assert_true(truck.has(needed), "the truck has %s" % needed)
	var grandma: Dictionary = SlimeAnimator.load_clips(OpeningActor.CLIPS)["grandma"]
	for needed in ["idle", "safe"]:
		assert_true(grandma.has(needed), "the old lady has %s" % needed)

func test_the_backdrop_is_the_640_by_360_street() -> void:
	var texture := load("res://assets/opening/backdrop.png") as Texture2D
	assert_eq(texture.get_size(), Vector2(640, 360))
