class_name RoomHidden
extends RoomBlock
## A door that looks like wall until the reveal verb shows it (the group `hidden`, `reveal()`): the way through opens and the doorway is
## drawn as a lit outline. The verb says `hidden_found` for each one it shows.

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	add_to_group("hidden")

func reveal() -> void:
	if not is_in_group("hidden"):
		return
	remove_from_group("hidden")
	if is_instance_valid(_body):
		_body.queue_free()
	var frame := Line2D.new()
	frame.points = PackedVector2Array([Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, size.y / 2.0),
		Vector2(-size.x / 2.0, size.y / 2.0), Vector2(-size.x / 2.0, -size.y / 2.0)])
	frame.width = 2.0
	frame.default_color = Color(1.0, 0.95, 0.6, 0.8)
	add_child(frame)
	add_child(Art.light(Color(1.0, 0.95, 0.6), 0.6, 1.2))
