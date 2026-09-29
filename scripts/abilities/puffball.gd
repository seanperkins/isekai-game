extends Ability
## Evolved Spore Cloud: a pod lobbed along the aim bursts where it lands into a wide cloud. The landing point is computed at
## cast time by stepping the arc, so nothing flies (the effects draw the pod). The value is the cloud's radius in px.

const SPEED := 220.0
const LIFT := 150.0
const GRAVITY := 600.0
const STEP := 1.0 / 30.0
const MAX_STEPS := 40  # 1.33 s: straight up needs 1.23 s to return to launch height
const SECONDS := 3.0

## Where the pod comes down: the first rock the arc meets (a little short of it), or where the last segment ends.
func landing_point() -> Vector2:
	var pos := actor.global_position
	var vel := aim_dir() * SPEED + Vector2(0.0, -LIFT)
	for i in MAX_STEPS:
		var next := pos + vel * STEP
		vel.y += GRAVITY * STEP
		var rock = terrain_hit(pos, next)
		if rock != null:
			return rock - (next - pos).normalized() * 2.0
		pos = next
	return pos

func _perform() -> void:
	var cloud := SporeCloudArea.new()
	actor.get_parent().add_child(cloud)
	cloud.launch(landing_point(), float(value()), SECONDS, actor)
