class_name OneshotScheduler
extends RefCounted
## Random ambience one-shots (drips, pings, hums) for the current biome: a random cue on a random
## interval, at a random offset up to `radius` px from the player.

var _rng: RandomNumberGenerator
var _entry := {}
var _left := 0.0

func _init(p_rng: RandomNumberGenerator) -> void:
	_rng = p_rng

## entry is a biome's `oneshots`: {"cues": [...], "interval": [low, high], "radius": px}.
func set_biome(entry: Dictionary) -> void:
	_entry = entry
	_left = _next_delay()

## Advances time; returns the one-shots due now as [{"cue": id, "offset": Vector2}].
func advance(delta: float) -> Array:
	if _entry.is_empty():
		return []
	_left -= delta
	if _left > 0.0:
		return []
	_left = _next_delay()
	var cues: Array = _entry["cues"]
	var angle := _rng.randf() * TAU
	var reach := _rng.randf() * float(_entry["radius"])
	return [{"cue": cues[_rng.randi() % cues.size()], "offset": Vector2(cos(angle), sin(angle)) * reach}]

func _next_delay() -> float:
	var interval: Array = _entry["interval"]
	return _rng.randf_range(float(interval[0]), float(interval[1]))
