class_name EnemyStatus
extends RefCounted
## Enemy condition timers. Stun and downed timers pause while `held` (a predate hold).

const ACTIVE := 0
const STUNNED := 1
const DOWNED := 2
const GONE := 3
## The death effect is playing: no AI, not attackable, not edible, and no timer (update() skips it).
const DYING := 4
const STUN_SECONDS := 3.0
const DOWNED_SECONDS := 5.0

var state := ACTIVE
var held := false
## A dormant enemy's status is frozen: nothing stuns it (the Tremor ability calls stun() itself after a refused hit).
var frozen := false
var _timer := 0.0

## Stuns for `seconds`; on a creature already stunned the longer timer stays (a short stun never shortens a long one).
func stun(seconds: float = STUN_SECONDS) -> void:
	if frozen:
		return
	if state == ACTIVE or state == STUNNED:
		_timer = seconds if state == ACTIVE else maxf(_timer, seconds)
		state = STUNNED

func down() -> void:
	if state != GONE:
		state = DOWNED
		_timer = DOWNED_SECONDS

func die() -> void:
	if state != GONE:
		state = DYING

func consume() -> void:
	state = GONE

func predatable() -> bool:
	return state == STUNNED or state == DOWNED

func update(delta: float) -> void:
	if held or state == ACTIVE or state == GONE or state == DYING:
		return
	_timer -= delta
	if _timer <= 0.0:
		state = ACTIVE if state == STUNNED else GONE
