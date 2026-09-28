class_name Vfx
extends RefCounted
## Short-lived visual effects for abilities. Effects are top-level (global coordinates),
## live beside the actor, fade out, and free themselves. Group "vfx".

static func _host(actor: Node2D) -> Node:
	return actor.get_parent() if actor.get_parent() != null else actor

static func line(actor: Node2D, from: Vector2, to: Vector2, color: Color, width: float, seconds: float) -> Line2D:
	var l := Line2D.new()
	l.add_to_group("vfx")
	l.top_level = true
	l.width = width
	l.default_color = color
	l.points = PackedVector2Array([from, to])
	_host(actor).add_child(l)
	_fade(l, seconds)
	return l

static func puffs(actor: Node2D, texture: Texture2D, positions: Array, color: Color, seconds: float) -> Node2D:
	var root := Node2D.new()
	root.add_to_group("vfx")
	root.top_level = true
	for p in positions:
		var s := Sprite2D.new()
		s.texture = texture
		s.position = p
		s.modulate = color
		root.add_child(s)
	_host(actor).add_child(root)
	_fade(root, seconds)
	return root

static func _fade(node: CanvasItem, seconds: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, seconds)
	tw.tween_callback(node.queue_free)
