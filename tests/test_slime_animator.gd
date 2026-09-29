extends GutTest
## State -> clip -> frame name. Pure logic; the sheet is only used to check the names exist.

func _clips() -> Dictionary:
	return {
		"idle": {"frames": ["a", "b"], "fps": 2.0, "loop": true},
		"once": {"frames": ["x", "y", "z"], "fps": 10.0, "loop": false},
		"spread": {"frames": ["s1", "s2"], "fps": 20.0, "loop": false, "exit": ["s2", "s1"]}}

func test_a_loop_cycles_and_wraps() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("idle")
	assert_eq(a.frame(), "a")
	a.advance(0.5)
	assert_eq(a.frame(), "b")
	a.advance(0.5)
	assert_eq(a.frame(), "a")

func test_a_one_shot_holds_its_last_frame() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("once")
	a.advance(5.0)
	assert_eq(a.frame(), "z")

func test_playing_the_same_state_again_does_not_restart_it() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("once")
	a.advance(0.15)
	assert_eq(a.frame(), "y")
	a.play("once")
	assert_eq(a.frame(), "y")

func test_a_new_state_starts_from_its_first_frame() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("once")
	a.advance(0.3)
	a.play("idle")
	assert_eq(a.state(), "idle")
	assert_eq(a.frame(), "a")

func test_leaving_spread_plays_its_exit_frames_first() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("spread")
	a.advance(1.0)
	assert_eq(a.frame(), "s2")
	a.play("idle")
	assert_eq(a.state(), "idle")
	assert_eq(a.frame(), "s2")          # the exit clip runs first
	a.advance(1.0 / SlimeAnimator.EXIT_FPS)
	assert_eq(a.frame(), "s1")
	a.advance(1.0 / SlimeAnimator.EXIT_FPS)
	assert_eq(a.frame(), "a")           # then the new state

func test_an_unknown_state_is_ignored() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("idle")
	a.play("nonsense")
	assert_eq(a.state(), "idle")

func test_every_state_has_a_clip_of_real_frames() -> void:
	var clips := SlimeAnimator.load_clips()
	var sheet := SpriteSheet.load_set("slime")
	for state in SlimeState.ALL:
		assert_true(clips.has(state), state)
		var clip: Dictionary = clips[state]
		assert_gt(float(clip["fps"]), 0.0, state)
		assert_false(clip["frames"].is_empty(), state)
		for name in clip["frames"] + clip.get("exit", []):
			assert_true(sheet.has_frame(name), "%s uses a frame that is not on the sheet: %s" % [state, name])

func test_the_run_cycle_is_four_frames_and_idle_two() -> void:
	var clips := SlimeAnimator.load_clips()
	assert_eq(clips["run"]["frames"], ["run_1", "run_2", "run_3", "run_4"])
	assert_eq(clips["idle"]["frames"], ["idle_1", "idle_2"])
	assert_eq(clips["spread"]["exit"], ["spread_2", "spread_1"])
