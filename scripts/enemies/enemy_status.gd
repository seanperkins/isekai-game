class_name EnemyStatus
extends RefCounted
## Enemy condition timers. Stun and downed timers pause while `held` (a predate hold).

const ACTIVE := 0
const STUNNED := 1
const DOWNED := 2
const GONE := 3
const STUN_SECONDS := 2.0
const DOWNED_SECONDS := 5.0

var state := ACTIVE
var held := false
var _timer := 0.0

func stun(seconds: float = STUN_SECONDS) -> void:
	if state == ACTIVE or state == STUNNED:
		state = STUNNED
		_timer = seconds

func down() -> void:
	if state != GONE:
		state = DOWNED
		_timer = DOWNED_SECONDS

func consume() -> void:
	state = GONE

func predatable() -> bool:
	return state == STUNNED or state == DOWNED

func update(delta: float) -> void:
	if held or state == ACTIVE or state == GONE:
		return
	_timer -= delta
	if _timer <= 0.0:
		state = ACTIVE if state == STUNNED else GONE
