class_name PlayerAudioEvents
extends RefCounted
## Turns the player's per-frame physics state into audio-only world events: landings, and the
## start and stop of the run and wall-slide loops. Emits on EventBus.world_event unless a test
## injects emit_event.

const HARD_LANDING_SPEED := 400.0  # px/s: a drop of about 90 px
const MIN_LANDING_SPEED := 60.0    # slower than this is a step, not a landing
const RUN_SPEED := 40.0

var emit_event: Callable = Callable()
var _was_on_floor := true
var _running := false
var _sliding := false

## fall_speed is velocity.y read before move_and_slide(), which zeroes it on contact.
func update(on_floor: bool, fall_speed: float, vx: float, spread: bool, wall_sliding: bool) -> void:
	if on_floor and not _was_on_floor and fall_speed >= MIN_LANDING_SPEED:
		_emit("landed", {"hard": fall_speed >= HARD_LANDING_SPEED, "speed": fall_speed})
	_was_on_floor = on_floor
	_set_running(on_floor and not spread and absf(vx) > RUN_SPEED)
	_set_sliding(wall_sliding)

## Ends any loop that is running (death, a new run).
func reset() -> void:
	_set_running(false)
	_set_sliding(false)

func _set_running(now: bool) -> void:
	if now == _running:
		return
	_running = now
	if now:
		_emit("run_started", {})
	else:
		_emit("run_stopped", {})

func _set_sliding(now: bool) -> void:
	if now == _sliding:
		return
	_sliding = now
	if now:
		_emit("wall_slide_started", {})
	else:
		_emit("wall_slide_stopped", {})

func _emit(event_name: String, tags: Dictionary) -> void:
	if emit_event.is_valid():
		emit_event.call(event_name, tags)
	else:
		EventBus.world_event.emit(event_name, tags)
