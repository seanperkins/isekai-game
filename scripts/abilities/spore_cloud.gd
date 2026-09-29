class_name SporeCloud
extends Ability
## A lingering spore cloud a little way in front of the caster: it slows and poisons enemies for a while.
## The active value is the cloud's radius in px; its duration grows with level.

static func duration_for(level: int) -> float:
	return 2.0 + 0.25 * float(level - 1)

func _perform() -> void:
	var cloud := SporeCloudArea.new()
	actor.get_parent().add_child(cloud)
	cloud.launch(actor.global_position + aim_dir() * 32.0, float(value()), SporeCloud.duration_for(level), actor)
