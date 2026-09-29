extends GutTest
## The Audio autoload end to end: events become cues, loops stop, the duck and biome behave.
## The audio driver is a dummy in headless runs, so these check routing and state, not sound.

var _duck_effect: AudioEffectAmplify

func before_each() -> void:
	Audio.reset()
	Audio.last_cue = ""
	_duck_effect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
	_duck_effect.volume_db = 0.0

func after_each() -> void:
	get_tree().paused = false
	Audio.reset()

func test_a_world_event_plays_its_cue() -> void:
	EventBus.world_event.emit("landed", {"hard": true})
	assert_eq(Audio.last_cue, "slime_land_hard")
	EventBus.world_event.emit("tackled", {})
	assert_eq(Audio.last_cue, "slime_tackle")

func test_a_game_event_plays_its_cue_and_skill_used_picks_by_id() -> void:
	EventBus.game_event.emit(Events.JUMPED, {"from": "ground"})
	assert_eq(Audio.last_cue, "slime_launch")
	Audio.last_cue = ""
	EventBus.game_event.emit(Events.SKILL_USED, {"id": "water_blade"})
	assert_eq(Audio.last_cue, "skill_water_blade")

func test_silent_and_unknown_events_play_nothing() -> void:
	EventBus.game_event.emit(Events.MANA_SPENT, {})
	EventBus.world_event.emit("not_an_event", {})
	assert_eq(Audio.last_cue, "")

func test_skill_rules_signals_play_their_stingers() -> void:
	SkillRules.skill_unlocked.emit("leap")
	assert_eq(Audio.last_cue, "skill_unlock")
	SkillRules.skill_leveled.emit("leap", 2)
	assert_eq(Audio.last_cue, "skill_rank_up")

func test_a_loop_starts_once_and_a_stop_event_ends_it() -> void:
	EventBus.world_event.emit("run_started", {})
	assert_true(Audio.is_looping("slime_run"))
	EventBus.world_event.emit("run_started", {})  # a second start does not stack
	assert_true(Audio.is_looping("slime_run"))
	EventBus.world_event.emit("run_stopped", {})
	assert_false(Audio.is_looping("slime_run"))

func test_reset_stops_every_loop() -> void:
	EventBus.world_event.emit("run_started", {})
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	assert_true(Audio.is_looping("slime_heartbeat"))
	Audio.reset()
	assert_false(Audio.is_looping("slime_run"))
	assert_false(Audio.is_looping("slime_heartbeat"))

func test_dying_ends_the_heartbeat_before_the_death_cue_plays() -> void:
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	EventBus.world_event.emit("run_started", {})
	EventBus.world_event.emit("player_died", {})
	assert_false(Audio.is_looping("slime_heartbeat"))
	assert_false(Audio.is_looping("slime_run"))
	assert_eq(Audio.last_cue, "slime_death")

func test_reset_frees_every_voice_and_forgets_cooldowns() -> void:
	EventBus.game_event.emit(Events.ABSORBED, {"essence": "poison", "source": "toad"})
	SkillRules.skill_unlocked.emit("leap")
	Audio.reset()
	assert_eq(Audio._pool.busy_count(), 0)
	Audio.last_cue = ""
	EventBus.game_event.emit(Events.ABSORBED, {"essence": "poison", "source": "toad"})
	assert_eq(Audio.last_cue, "eat_absorb", "the cooldown from before the reset is gone")

func test_a_new_run_stops_loops_left_from_the_last_one() -> void:
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	SkillRules.run_started.emit()
	assert_false(Audio.is_looping("slime_heartbeat"))

func test_an_absorb_burst_plays_once() -> void:
	Audio.last_cue = ""
	for i in 8:
		EventBus.game_event.emit(Events.ABSORBED, {"essence": "poison", "source": "toad"})
	assert_eq(Audio.last_cue, "eat_absorb")
	assert_eq(Audio._pool.busy_count(), 1)

func test_a_cue_with_a_missing_file_warns_once_and_does_not_crash() -> void:
	Audio.catalog.cues["ghost"] = {"files": ["sfx/ghost_1.ogg"], "bus": "UI", "volume_db": -6}
	Audio.play_cue("ghost")
	Audio.play_cue("ghost")
	assert_eq(Audio.last_cue, "", "nothing played")
	Audio.catalog.cues.erase("ghost")

func test_the_menu_ducks_the_music_and_releases_it() -> void:
	EventBus.world_event.emit("menu_opened", {})
	await get_tree().create_timer(0.4, true).timeout
	assert_almost_eq(_duck_effect.volume_db, Audio.DUCK_DB, 0.5)
	EventBus.world_event.emit("menu_closed", {})
	await get_tree().create_timer(0.9, true).timeout
	assert_almost_eq(_duck_effect.volume_db, 0.0, 0.5)

func test_a_stinger_timer_from_before_a_reset_does_not_release_a_newer_duck() -> void:
	var stale_epoch: int = Audio._duck_epoch
	Audio.reset()  # a new run, a death: everything before it is forgotten, timers included
	EventBus.world_event.emit("menu_opened", {})
	Audio._release_stinger_duck(stale_epoch)  # the old stinger's timer fires now
	assert_eq(Audio._duck_holds, 1, "the menu's duck is still held")
	Audio._release_stinger_duck(Audio._duck_epoch)  # a current stinger's timer does release
	assert_eq(Audio._duck_holds, 0)

func test_the_duck_still_runs_while_the_tree_is_paused() -> void:
	assert_eq(Audio.process_mode, Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	EventBus.world_event.emit("menu_opened", {})
	await get_tree().create_timer(0.4, true).timeout
	get_tree().paused = false
	assert_almost_eq(_duck_effect.volume_db, Audio.DUCK_DB, 0.5)

func test_ui_voices_run_while_paused_and_gameplay_voices_do_not() -> void:
	Audio.play_cue("ui_confirm")
	var ui_slot := 0
	for i in Audio.VOICES:
		if Audio._pool.cue_at(i) == "ui_confirm":
			ui_slot = i
	assert_eq(Audio._voices[ui_slot][0].process_mode, Node.PROCESS_MODE_ALWAYS)
	Audio.play_cue("slime_tackle")
	for i in Audio.VOICES:
		if Audio._pool.cue_at(i) == "slime_tackle":
			assert_eq(Audio._voices[i][0].process_mode, Node.PROCESS_MODE_PAUSABLE)

# --- music director -------------------------------------------------------------

func _director() -> MusicDirector:
	var d := MusicDirector.new()
	d.setup(CueCatalog.load_file("res://data/audio/cues.json"), OneshotScheduler.new(RandomNumberGenerator.new()))
	add_child_autofree(d)
	return d

func test_crossfade_gains_keep_equal_power() -> void:
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var g := MusicDirector.fade_gains(t)
		assert_almost_eq(g.x * g.x + g.y * g.y, 1.0, 0.0001)
	assert_eq(MusicDirector.fade_gains(0.0), Vector2(0.0, 1.0))

func test_entering_the_same_biome_does_not_restart_the_bed() -> void:
	var d := _director()
	assert_true(d.set_biome("cave"))
	assert_eq(d.current_music, "res://assets/audio/music/cave.ogg")
	assert_false(d.set_biome("cave"))
	assert_true(d.set_biome("grotto"))
	assert_eq(d.current_area, "grotto")

func test_an_unknown_biome_warns_and_keeps_the_current_bed() -> void:
	var d := _director()
	d.set_biome("cave")
	assert_false(d.set_biome("moon"))
	assert_eq(d.current_area, "cave")
	assert_push_warning_count(1)

func test_the_audio_autoload_switches_biome_and_reverb() -> void:
	Audio.director.current_area = ""
	Audio.set_biome("flooded")
	await get_tree().create_timer(1.2, true).timeout
	var reverb := AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX_World"), 0) as AudioEffectReverb
	assert_almost_eq(reverb.wet, 0.45, 0.02)
	Audio.set_biome("cave")
