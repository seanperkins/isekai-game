extends ThreadAbility
## Short thread: slows then holds an enemy, or swings from terrain up to 120 px away.

func _init() -> void:
	rope_range = 120.0
	reel_speed = 60.0
	release_boost = 1.0
