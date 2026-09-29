extends ThreadAbility
## Evolved Sticky Thread: never ropes. It holds an enemy at once and leaves a web patch where the thread ends, slowing
## anything inside it. It webs a corridor or a floor, not a swing anchor.

const PATCH_RADIUS := 40.0
const PATCH_SECONDS := 4.0

func _init() -> void:
	rope_range = 120.0
	ropes = false

func _land(end: Vector2) -> void:
	var patch := SporeCloudArea.new()
	actor.get_parent().add_child(patch)
	patch.launch(end, PATCH_RADIUS, PATCH_SECONDS, actor, {"damage": 0, "slow": true, "look": "web", "color": Color(0.95, 0.95, 1.0, 0.85)})
