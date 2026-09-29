extends Ability
## Evolved Spore Cloud: a cloud that mends the slime and slows enemies. The value is its radius in px.

const SECONDS := 4.0

func _perform() -> void:
	var cloud := SporeCloudArea.new()
	actor.get_parent().add_child(cloud)
	cloud.launch(actor.global_position + aim_dir() * 32.0, float(value()), SECONDS, actor,
		{"damage": 0, "slow": true, "heals": 1, "color": Color(0.6, 1.0, 0.7, 0.3)})
