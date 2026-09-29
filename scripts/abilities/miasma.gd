extends "res://scripts/abilities/poison_breath.gd"
## Evolved Poison Breath: the cone as today, and a poison cloud lingers where it ends (never inside or behind rock).

const CLOUD_RADIUS := 36.0
const CLOUD_SECONDS := 3.0

func _perform() -> void:
	super._perform()
	var dir := aim_dir()
	var from := actor.global_position
	var end := from + dir * RANGE
	var rock = terrain_hit(from, end)
	if rock != null:
		end = rock - dir * 2.0
	var cloud := SporeCloudArea.new()
	actor.get_parent().add_child(cloud)
	cloud.launch(end, CLOUD_RADIUS, CLOUD_SECONDS, actor, {"damage": 1, "slow": false, "color": Color(0.5, 0.9, 0.3, 0.3)})
