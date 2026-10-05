extends GutTest
## A theme takes the music over from the room's bed: the bed is held silent under it and comes back when it ends.

func before_each() -> void:
	Audio.reset()

func after_each() -> void:
	get_tree().paused = false
	Audio.reset()

func _director(fade_in := 0.1, fade_out := 0.1) -> MusicDirector:
	var catalog := CueCatalog.load_file("res://data/audio/cues.json")
	catalog.themes["quick"] = {"music": "music/opening_battle.ogg", "fade_in": fade_in, "fade_out": fade_out}
	var d := MusicDirector.new()
	d.setup(catalog, OneshotScheduler.new(RandomNumberGenerator.new()))
	add_child_autofree(d)
	return d

## The biome crossfade is a real 2 s tween; a test that wants the settled state ends it and applies the final gains.
func _finish_crossfade(d: MusicDirector) -> void:
	if d._fade != null:
		d._fade.kill()
	d._apply_fade(1.0)

func _settle(seconds := 0.3) -> void:
	await get_tree().create_timer(seconds, true).timeout

func test_theme_gains_keep_equal_power_and_swap_places_when_leaving() -> void:
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var entering := MusicDirector.theme_gains(t, true)
		assert_almost_eq(entering.x * entering.x + entering.y * entering.y, 1.0, 0.0001)
		var leaving := MusicDirector.theme_gains(t, false)
		assert_almost_eq(leaving.x, entering.y, 0.0001)
		assert_almost_eq(leaving.y, entering.x, 0.0001)
	var close := Vector2(0.0001, 0.0001)
	assert_almost_eq(MusicDirector.theme_gains(0.0, true), Vector2(0.0, 1.0), close, "the theme is silent and the bed full at the start")
	assert_almost_eq(MusicDirector.theme_gains(1.0, true), Vector2(1.0, 0.0), close, "and the other way round at the end")

func test_a_theme_starts_once() -> void:
	var d := _director()
	assert_true(d.start_theme("quick"))
	assert_eq(d.theme_id, "quick")
	assert_false(d.start_theme("quick"))

func test_an_unknown_theme_warns_and_changes_nothing() -> void:
	var d := _director()
	assert_false(d.start_theme("nope"))
	assert_eq(d.theme_id, "")
	assert_push_warning_count(1)

func test_stopping_a_theme_that_is_not_playing_does_nothing() -> void:
	var d := _director()
	assert_false(d.stop_theme())

func test_the_bed_is_held_silent_under_the_theme_and_returns_after_it() -> void:
	var d := _director()
	d.set_biome("cave")
	_finish_crossfade(d)
	assert_almost_eq(d.bed_gain(), 1.0, 0.001)
	assert_gt(d.bed_volume_db(), -3.0, "the bed is at its level")
	d.start_theme("quick")
	await _settle()
	assert_almost_eq(d.theme_gain(), 1.0, 0.01)
	assert_almost_eq(d.bed_gain(), 0.0, 0.01)
	assert_lt(d.bed_volume_db(), -60.0, "the room's music is out of the way")
	assert_true(d.stop_theme())
	await _settle()
	assert_eq(d.theme_id, "")
	assert_almost_eq(d.theme_gain(), 0.0, 0.01)
	assert_almost_eq(d.bed_gain(), 1.0, 0.01)
	assert_gt(d.bed_volume_db(), -3.0, "and it is back")

func test_a_biome_change_during_a_theme_stays_silent_until_the_theme_ends() -> void:
	var d := _director()
	d.set_biome("cave")
	_finish_crossfade(d)
	d.start_theme("quick")
	await _settle()
	d.set_biome("grotto")
	_finish_crossfade(d)
	assert_lt(d.bed_volume_db(), -60.0, "the new room's music waits for the theme")
	d.stop_theme()
	await _settle()
	assert_gt(d.bed_volume_db(), -3.0)

func test_end_theme_is_immediate() -> void:
	var d := _director(0.1, 5.0)
	d.set_biome("cave")
	_finish_crossfade(d)
	d.start_theme("quick")
	await _settle()
	d.end_theme()
	assert_eq(d.theme_id, "")
	assert_almost_eq(d.theme_gain(), 0.0, 0.0001)
	assert_almost_eq(d.bed_gain(), 1.0, 0.0001)
	assert_gt(d.bed_volume_db(), -3.0)

func test_stopping_part_way_through_the_fade_in_does_not_jump() -> void:
	var d := _director(1.0, 1.0)
	d.start_theme("quick")
	await _settle(0.35)
	var before := d.theme_gain()
	assert_gt(before, 0.05)
	assert_lt(before, 0.95)
	d.stop_theme()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(d.theme_gain(), before + 0.02, "it fades out from where it was, not from full")
	assert_gt(d.theme_gain(), before - 0.3)

func test_the_audio_autoload_runs_the_theme_from_its_events() -> void:
	EventBus.world_event.emit("opening_started", {})
	assert_eq(Audio.director.theme_id, "opening_battle")
	EventBus.world_event.emit("opening_ended", {})
	await _settle(2.2)  # past its 1.8 s fade out
	assert_eq(Audio.director.theme_id, "")
	assert_almost_eq(Audio.director.bed_gain(), 1.0, 0.01)

func test_a_reset_ends_the_theme_at_once() -> void:
	EventBus.world_event.emit("opening_started", {})
	Audio.reset()
	assert_eq(Audio.director.theme_id, "")
	assert_almost_eq(Audio.director.bed_gain(), 1.0, 0.0001)

func test_the_theme_keeps_playing_while_the_tree_is_paused() -> void:
	get_tree().paused = true
	EventBus.world_event.emit("opening_started", {})
	assert_false(Audio.director.theme_player().stream_paused, "the opening pauses the game; its music must not")

# --- the panel's finding: a reset in the middle of a biome change must not disturb the crossfade ---

func test_a_reset_between_a_biome_change_and_its_first_fade_step_leaves_the_crossfade_alone() -> void:
	# A rebirth in another biome: the new bed has just been started (silent), the old one is still playing at its level, and
	# the run's reset (which ends any theme) lands before the crossfade has taken a step.
	var d := _director()
	d.set_biome("cave")
	_finish_crossfade(d)
	d.set_biome("grotto")
	d.end_theme()
	assert_lt(d.bed_volume_db(), -60.0, "the incoming bed has not begun to fade in; it must not jump to full volume")
	var outgoing: AudioStreamPlayer = d._music[1 - d._front]
	assert_gt(outgoing.volume_db, -3.0, "and the outgoing bed keeps playing at its level")

func test_the_audio_autoload_survives_a_reset_during_a_biome_change() -> void:
	Audio.director.current_area = ""
	Audio.set_biome("cave")
	_finish_crossfade(Audio.director)
	Audio.set_biome("grotto")
	Audio.reset()
	assert_lt(Audio.director.bed_volume_db(), -60.0)
	_finish_crossfade(Audio.director)
	Audio.director.current_area = ""
