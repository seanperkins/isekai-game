class_name ShapeHit
extends RefCounted
## Hit tests between traced shapes, all in global points. A shape needs at least 3 points to count.

static func overlap(a: PackedVector2Array, b: PackedVector2Array, margin: float = 0.0) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	var grown := a
	if margin > 0.0:
		var out := Geometry2D.offset_polygon(a, margin)
		if out.is_empty():
			return false
		grown = out[0]
	return not Geometry2D.intersect_polygons(grown, b).is_empty()

## True when `point` is inside `shape` or within `radius` of it.
static func point_near(shape: PackedVector2Array, point: Vector2, radius: float) -> bool:
	if shape.size() < 3:
		return false
	var grown := shape
	if radius > 0.0:
		var out := Geometry2D.offset_polygon(shape, radius)
		if out.is_empty():
			return false
		grown = out[0]
	return Geometry2D.is_point_in_polygon(point, grown)

## A rectangle as four global points.
static func rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

## `local` shifted to a global origin.
static func moved(local: PackedVector2Array, origin: Vector2, scale := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in local:
		out.append(p * scale + origin)
	return out
