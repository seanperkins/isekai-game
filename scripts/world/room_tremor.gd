class_name RoomTremor
extends Node2D
## The ground shakes in a room with `tremor` (the warning that a boss is ahead): every MIN_GAP to MAX_GAP seconds it emits the world event
## boss_tremor ({"strength", "near"}: the audio catalog picks a far or a near rumble by the tag), jolts the camera through ctx["shake"] when
## the world supplies one, and drops a few specks of dust from the ceiling. (`Tremor` is already the skill, hence the name.)

const MIN_GAP := 5.0
const MAX_GAP := 9.0
## The camera shake in px per unit of strength, and for how long; a strength at or above NEAR_AT is the near rumble.
const SHAKE_PER_STRENGTH := 4.0
const SHAKE_SECONDS := 0.5
const NEAR_AT := 0.5
const DUST_GROUP := "tremor_dust"
const DUST_SECONDS := 1.2
const DUST_SPECKS := 6

var _strength := 0.0
var _width := 640.0
var _ctx: Dictionary = {}
var _rng: RandomNumberGenerator
var _dust_rng := RandomNumberGenerator.new()
var _left := 0.0

func setup(def: RoomDef, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	name = "RoomTremor"
	_strength = def.tremor
	_width = def.pixel_size().x
	_ctx = ctx
	_rng = rng
	_dust_rng.randomize()
	_left = _rng.randf_range(MIN_GAP, MAX_GAP)

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left += _rng.randf_range(MIN_GAP, MAX_GAP)  # the overshoot stays in the clock, so the schedule does not drift with the frame rate
	_rumble()

func _rumble() -> void:
	EventBus.world_event.emit("boss_tremor", {"strength": _strength, "near": _strength >= NEAR_AT, "pos": global_position})
	var shake: Callable = _ctx.get("shake", Callable())
	if shake.is_valid():
		shake.call(_strength * SHAKE_PER_STRENGTH, SHAKE_SECONDS)
	for _k in DUST_SPECKS:
		var speck := ColorRect.new()
		speck.size = Vector2(2, 3)
		speck.color = Color(0.55, 0.5, 0.45, 0.8)
		speck.position = Vector2(_dust_rng.randf_range(RoomDef.WALL, _width - RoomDef.WALL), RoomDef.WALL)
		speck.add_to_group(DUST_GROUP)
		add_child(speck)
		var tween := speck.create_tween().set_parallel(true)
		tween.tween_property(speck, "position:y", speck.position.y + _dust_rng.randf_range(40.0, 90.0), DUST_SECONDS)
		tween.tween_property(speck, "modulate:a", 0.0, DUST_SECONDS)
		tween.chain().tween_callback(speck.queue_free)
