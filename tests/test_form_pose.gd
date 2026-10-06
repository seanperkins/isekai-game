extends GutTest
## How an animated form (clips built by tools/art/blender) is played by a body that is not the enemy: the walk plays as fast as the body goes, so a
## planted foot stays planted at any speed; data/form_clips.json holds the clips and the speed they were built for.

func test_a_walk_plays_as_fast_as_the_body_goes_against_the_speed_it_was_built_for() -> void:
	assert_almost_eq(FormPose.rate("walk", 60.0, 60.0), 1.0, 0.001)
	assert_almost_eq(FormPose.rate("walk", 30.0, 60.0), 0.5, 0.001)
	assert_almost_eq(FormPose.rate("walk", 120.0, 60.0), 2.0, 0.001, "a faster body steps faster")
	assert_almost_eq(FormPose.rate("walk", 5.0, 60.0), FormPose.RATE_RANGE.x, 0.001, "but never to a standstill")
	assert_almost_eq(FormPose.rate("walk", 5000.0, 60.0), FormPose.RATE_RANGE.y, 0.001)

func test_a_run_is_built_for_the_run_speed_times_the_walk() -> void:
	assert_almost_eq(FormPose.rate("run", 60.0 * FormPose.RUN_SPEED, 60.0), 1.0, 0.001)
	assert_almost_eq(FormPose.rate("run", 60.0 * FormPose.RUN_SPEED * 1.5, 60.0), 1.5, 0.001)

func test_anything_else_plays_at_its_own_pace_and_a_body_at_rest_at_its_own() -> void:
	for state in ["idle", "recover", "hurt", "windup"]:
		assert_eq(FormPose.rate(state, 100.0, 60.0), 1.0, state)
	assert_eq(FormPose.rate("walk", 0.0, 60.0), 1.0)
	assert_eq(FormPose.rate("run", 0.5, 60.0), 1.0)

func test_a_body_runs_when_it_goes_clearly_faster_than_the_walk() -> void:
	assert_false(FormPose.running(60.0, 60.0))
	assert_false(FormPose.running(60.0 * FormPose.RUN_RATIO, 60.0), "at the ratio itself it still walks")
	assert_true(FormPose.running(60.0 * FormPose.RUN_RATIO + 1.0, 60.0))

func test_the_clip_file_holds_each_forms_clips_and_the_walk_speed_they_were_built_for() -> void:
	assert_true(FormClips.has_form("wolf_warg"))
	assert_false(FormClips.has_form("no_such_form"))
	assert_false(FormClips.has_form("_walk_speeds"), "the speed table is not a form")
	var clips := FormClips.clips_of("wolf_warg")
	for state in ["idle", "walk", "run", "windup", "recover", "hurt"]:
		assert_true(clips.has(state), state)
	assert_almost_eq(FormClips.walk_speed_of("wolf_warg"), 58.929, 0.01)
	assert_eq(FormClips.walk_speed_of("no_such_form"), Enemy.BASE_SPEED, "a form with no recorded speed walks at the default")
	assert_eq(FormClips.sheet_of("wolf_warg"), "anim_wolf_warg")
