class_name Vfx
extends RefCounted
## Short-lived visual effects for abilities. Effects are top-level (global coordinates),
## live beside the actor, fade out, and free themselves. Group "vfx". (A channel's persistent spray and tether strand are
## children of the ability instead, and not in the group.)

static func host(actor: Node2D) -> Node:
	return actor.get_parent() if actor.get_parent() != null else actor

static func line(actor: Node2D, from: Vector2, to: Vector2, color: Color, width: float, seconds: float) -> Line2D:
	var l := Line2D.new()
	l.add_to_group("vfx")
	l.top_level = true
	l.width = width
	l.default_color = color
	l.points = PackedVector2Array([from, to])
	host(actor).add_child(l)
	_fade(l, seconds)
	return l

## Five points on a shallow quadratic from `from` to `to` (the first is `from`, the last `to`), sagging a little.
static func sag_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var sag := minf(from.distance_to(to) * 0.06, 8.0)
	for i in 5:
		var t := i / 4.0
		out.append(from.lerp(to, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
	return out

## The silk look for a Line2D: the strand texture tiled along the line, 4 px wide.
static func style_strand(l: Line2D) -> void:
	l.texture = VfxArt.silk()
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.width = 4.0
	l.default_color = Color(0.95, 0.95, 1.0, 0.9)

## A thread flash: a silk strand that fades and frees itself.
static func strand(actor: Node2D, from: Vector2, to: Vector2, seconds: float) -> Line2D:
	var l := Line2D.new()
	l.add_to_group("vfx")
	l.top_level = true
	style_strand(l)
	l.points = sag_points(from, to)
	host(actor).add_child(l)
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
	host(actor).add_child(root)
	_fade(root, seconds)
	return root

static func _fade(node: CanvasItem, seconds: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, seconds)
	tw.tween_callback(node.queue_free)
