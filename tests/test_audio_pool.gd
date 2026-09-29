extends GutTest
## Voice pool, combo pitch and the ambience one-shot scheduler. Pure logic with an injected clock and RNG.

var now := 0.0

func _clock() -> float:
	return now

func _pool(capacity := 4) -> VoicePool:
	now = 0.0
	return VoicePool.new(capacity, _clock)

func test_the_pool_hands_out_distinct_free_slots() -> void:
	var p := _pool()
	var seen := {}
	for i in 4:
		seen[p.acquire("c%d" % i, -6.0, 0.0)] = true
	assert_eq(seen.size(), 4)
	assert_eq(p.busy_count(), 4)

func test_a_cue_inside_its_cooldown_is_dropped() -> void:
	var p := _pool()
	assert_ne(p.acquire("absorb", -6.0, 0.06), -1)
	now = 0.03
	assert_eq(p.acquire("absorb", -6.0, 0.06), -1)
	assert_eq(p.busy_count(), 1)
	now = 0.07
	assert_ne(p.acquire("absorb", -6.0, 0.06), -1)

func test_a_burst_in_one_frame_plays_once() -> void:
	var p := _pool(16)
	var played := 0
	for i in 12:  # twelve essence units absorbed in the same frame
		if p.acquire("eat_absorb", -10.0, 0.06) != -1:
			played += 1
	assert_eq(played, 1)

func test_a_full_pool_steals_the_quietest_voice() -> void:
	var p := _pool(3)
	var loud := p.acquire("loud", -3.0, 0.0)
	var quiet := p.acquire("quiet", -20.0, 0.0)
	var mid := p.acquire("mid", -10.0, 0.0)
	var stolen := p.acquire("new", -6.0, 0.0)
	assert_eq(stolen, quiet)
	assert_eq(p.cue_at(stolen), "new")
	assert_eq(p.cue_at(loud), "loud")
	assert_eq(p.cue_at(mid), "mid")
	assert_eq(p.busy_count(), 3)

func test_equally_quiet_voices_lose_the_oldest_first() -> void:
	var p := _pool(2)
	now = 1.0
	var first := p.acquire("a", -10.0, 0.0)
	now = 2.0
	p.acquire("b", -10.0, 0.0)
	now = 3.0
	assert_eq(p.acquire("c", -10.0, 0.0), first)

func test_release_frees_a_slot_for_reuse() -> void:
	var p := _pool(2)
	var a := p.acquire("a", -6.0, 0.0)
	p.acquire("b", -6.0, 0.0)
	p.release(a)
	assert_eq(p.busy_count(), 1)
	assert_eq(p.acquire("c", -6.0, 0.0), a)

# --- combo pitch ----------------------------------------------------------------

func test_combo_pitch_climbs_inside_the_window_and_resets_after_it() -> void:
	now = 0.0
	var c := ComboPitch.new(_clock)
	assert_eq(c.next("absorb", 0.8, 3), 0)
	now = 0.3
	assert_eq(c.next("absorb", 0.8, 3), 1)
	now = 0.6
	assert_eq(c.next("absorb", 0.8, 3), 2)
	now = 0.9
	assert_eq(c.next("absorb", 0.8, 3), 3)
	now = 1.2
	assert_eq(c.next("absorb", 0.8, 3), 3, "capped at max_steps")
	now = 5.0
	assert_eq(c.next("absorb", 0.8, 3), 0, "a gap resets the run")

func test_combo_pitch_tracks_each_cue_separately() -> void:
	now = 0.0
	var c := ComboPitch.new(_clock)
	c.next("a", 1.0, 5)
	now = 0.2
	assert_eq(c.next("b", 1.0, 5), 0)
	assert_eq(c.next("a", 1.0, 5), 1)

# --- one-shot scheduler ---------------------------------------------------------

func _entry() -> Dictionary:
	return {"cues": ["drip", "ping"], "interval": [1.0, 1.0], "radius": 100}

func test_nothing_is_due_without_a_biome() -> void:
	var s := OneshotScheduler.new(RandomNumberGenerator.new())
	assert_eq(s.advance(10.0), [])

func test_a_one_shot_fires_when_the_interval_passes_within_the_radius() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := OneshotScheduler.new(rng)
	s.set_biome(_entry())
	assert_eq(s.advance(0.5), [])
	var due := s.advance(0.6)
	assert_eq(due.size(), 1)
	assert_true(["drip", "ping"].has(due[0]["cue"]))
	assert_lte(due[0]["offset"].length(), 100.0)
	assert_eq(s.advance(0.5), [], "the next one waits a full interval")

func test_changing_biome_restarts_the_wait() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := OneshotScheduler.new(rng)
	s.set_biome(_entry())
	s.advance(0.9)
	s.set_biome(_entry())
	assert_eq(s.advance(0.5), [])
