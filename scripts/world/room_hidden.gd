class_name RoomHidden
extends RoomBlock
## A door that looks like wall until it is found: the reveal verb shows it from a distance (the group `hidden`, `reveal()`: the verb says
## `hidden_found`), and Inspect beside it searches it (it says `hidden_found` itself), so a form whose gate asks for a hidden room found is not
## locked behind its own verb. The way through opens and the doorway is drawn as a lit outline. Found once in a life it is not built again that life.

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	add_to_group("hidden")
	add_to_group("interactable")

func _ready() -> void:
	super._ready()
	var crack := ColorRect.new()  # a hairline the careful will see
	crack.color = Color(0.05, 0.05, 0.08, 0.7)
	crack.size = Vector2(2.0, size.y * 0.6)
	crack.position = Vector2(-1.0, -size.y * 0.3)
	add_child(crack)

func prompt() -> String:
	return "search"

func interact(player: Node) -> void:
	if not is_in_group("hidden"):
		return
	reveal()
	report(Deeds.HIDDEN_FOUND)
	player.inspect_report.emit(PackedStringArray(["Hollow wall", "You find a way through."]))

func reveal() -> void:
	if not is_in_group("hidden"):
		return
	remove_from_group("hidden")
	remove_from_group("interactable")
	if is_instance_valid(_body):
		_body.queue_free()
	var frame := Line2D.new()
	frame.points = PackedVector2Array([Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, size.y / 2.0),
		Vector2(-size.x / 2.0, size.y / 2.0), Vector2(-size.x / 2.0, -size.y / 2.0)])
	frame.width = 2.0
	frame.default_color = Color(1.0, 0.95, 0.6, 0.8)
	add_child(frame)
	add_child(Art.light(Color(1.0, 0.95, 0.6), 0.6, 1.2))
