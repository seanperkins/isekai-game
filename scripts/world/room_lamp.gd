class_name RoomLamp
extends RoomDeed
## A lamp to drink from (Inspect, "drink"): `lamp_drunk`, once per life per lamp. It dims when drunk.

var _light: Node
var _dry := false

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	add_to_group("interactable")

func _ready() -> void:
	if get_child_count() == 0:
		var stand := ColorRect.new()
		stand.color = Color(0.4, 0.3, 0.2)
		stand.size = Vector2(4, 12)
		stand.position = Vector2(-2, -12)
		add_child(stand)
		var bowl := ColorRect.new()
		bowl.color = Color(1.0, 0.8, 0.35)
		bowl.size = Vector2(10, 5)
		bowl.position = Vector2(-5, -17)
		add_child(bowl)
		_light = Art.light(Color(1.0, 0.8, 0.4), 0.8, 1.2)
		add_child(_light)

func prompt() -> String:
	return "drink"

## True once the lamp has been drunk (here or earlier in this life): it has nothing more to give.
func is_dry() -> bool:
	return _dry or _drunk_earlier()

## The ledger says this lamp was drunk earlier in this life (a room built again does not forget).
func _drunk_earlier() -> bool:
	var l = ledger if ledger != null else get_node_or_null("/root/SkillRules")
	return l != null and l.count(Deeds.LAMP_DRUNK, {"id": id}) > 0

## Drinks the lamp. True when there was oil in it, false when it was dry already.
func interact(player: Node) -> bool:
	var drunk := report(Deeds.LAMP_DRUNK)  # false when it was drunk before, by this node or earlier in this life
	_dry = true
	if is_instance_valid(_light):
		_light.queue_free()
	player.inspect_report.emit(PackedStringArray(["Lamp", "You drink the oil. It tastes of smoke and old wax." if drunk else "The lamp is dry."]))
	return drunk
