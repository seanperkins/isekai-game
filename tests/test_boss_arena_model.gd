extends GutTest
## Plan: boss arenas, Task 2. The arena's state machine: waiting, intro, fight, won, driven a tick at a time.

const DT := 1.0 / 60.0

var m: BossArenaModel

func before_each() -> void:
	m = BossArenaModel.new()

## Ticks until `event` appears (counting from the tick after `start`), at most `limit`; -1 when it never does.
func _ticks_until(event: String, in_threshold := false, boss_downed := false, limit := 200) -> int:
	for k in range(1, limit + 1):
		if m.tick(DT, in_threshold, boss_downed).has(event):
			return k
	return -1

func test_it_waits_until_the_threshold_is_crossed() -> void:
	for _k in 100:
		assert_eq(m.tick(DT, false, false), PackedStringArray())
	assert_eq(m.state, BossArenaModel.State.WAITING)

func test_crossing_starts_the_intro_with_one_intro_event() -> void:
	assert_eq(m.tick(DT, true, false), PackedStringArray(["intro"]))
	assert_eq(m.state, BossArenaModel.State.INTRO)
	assert_eq(m.tick(DT, true, false), PackedStringArray(), "standing on the line does not start it again")

func test_the_seal_comes_at_0_4_s_and_the_wake_at_0_8_s() -> void:
	m.tick(DT, true, false)
	var seal := _ticks_until("seal", true)
	assert_between(seal, 23, 25, "0.4 s at 60 Hz")
	var wake := seal + _ticks_until("wake", true)
	assert_between(wake, 47, 49, "0.8 s at 60 Hz")
	assert_eq(m.state, BossArenaModel.State.FIGHT)

func test_leaving_the_threshold_during_the_intro_does_not_cancel_it() -> void:
	m.tick(DT, true, false)
	assert_gt(_ticks_until("seal", false), 0, "the seal still comes with nobody on the line")
	assert_gt(_ticks_until("wake", false), 0)
	assert_eq(m.state, BossArenaModel.State.FIGHT)

func test_a_downed_boss_wins_from_the_fight() -> void:
	m.tick(DT, true, false)
	_ticks_until("wake", true)
	assert_eq(m.state, BossArenaModel.State.FIGHT)
	assert_eq(m.tick(DT, true, true), PackedStringArray(["won"]))
	assert_eq(m.state, BossArenaModel.State.WON)

func test_a_boss_downed_before_the_fight_is_held_and_wins_when_the_fight_begins() -> void:
	assert_eq(m.tick(DT, false, true), PackedStringArray(), "waiting: nothing opens")
	assert_eq(m.state, BossArenaModel.State.WAITING)
	m.tick(DT, true, true)
	var events := PackedStringArray()
	for _k in 60:
		events.append_array(m.tick(DT, true, true))
	assert_eq(events, PackedStringArray(["seal", "wake", "won"]), "the doors still shut and open, in order")
	assert_eq(m.state, BossArenaModel.State.WON)

func test_every_event_fires_once_and_won_is_final() -> void:
	var seen := PackedStringArray()
	for k in 300:
		seen.append_array(m.tick(DT, k >= 10, k >= 120))
	assert_eq(seen, PackedStringArray(["intro", "seal", "wake", "won"]))
	for _k in 60:
		assert_eq(m.tick(DT, true, true), PackedStringArray())
	assert_eq(m.state, BossArenaModel.State.WON)
