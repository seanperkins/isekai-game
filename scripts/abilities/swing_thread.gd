extends ThreadAbility
## Evolved Sticky Thread: a longer, faster rope with a stronger launch. Holds enemies.
## Default aim is up and forward, where the anchors usually are.

func _init() -> void:
	rope_range = 200.0
	reel_speed = 120.0
	release_boost = 1.4

func aim_dir() -> Vector2:
	return aim.normalized() if aim != Vector2.ZERO else Vector2(actor.facing, -1.0).normalized()
