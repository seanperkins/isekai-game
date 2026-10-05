class_name BossArenaModel
extends RefCounted
## The boss arena's state machine, a tick at a time (the BossArena node feeds it and does the work): waiting until the player crosses the
## threshold, then an intro whose doors slam halfway and whose end wakes the boss, then the fight, then won when the boss is downed. A
## boss downed before the fight (only a bug or a hazard can do that) is held and resolved when the fight begins, so the doors never
## stay shut with the boss already dead. Each event is returned once, in order: "intro", "seal", "wake", "won".

enum State { WAITING, INTRO, FIGHT, WON }

const INTRO_SECONDS := 0.8
const SEAL_AT := 0.4
## Float residue must not cost a tick at a boundary (0.4 s is 24 ticks of 1/60 only up to rounding).
const EPSILON := 1e-6

var state := State.WAITING

var _t := 0.0
var _sealed := false
var _downed_early := false

func tick(dt: float, in_threshold: bool, boss_downed: bool) -> PackedStringArray:
	var events := PackedStringArray()
	match state:
		State.WAITING:
			_downed_early = _downed_early or boss_downed
			if in_threshold:
				state = State.INTRO
				_t = 0.0
				events.append("intro")
		State.INTRO:
			_downed_early = _downed_early or boss_downed
			_t += dt
			if not _sealed and _t >= SEAL_AT - EPSILON:
				_sealed = true
				events.append("seal")
			if _t >= INTRO_SECONDS - EPSILON:
				state = State.FIGHT
				events.append("wake")
				if _downed_early:
					state = State.WON
					events.append("won")
		State.FIGHT:
			if boss_downed:
				state = State.WON
				events.append("won")
	return events
