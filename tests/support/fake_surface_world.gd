class_name FakeSurfaceWorld
extends RefCounted
## A tiny world of axis-aligned rectangles for testing the crawl without physics: the two probes MoveInput carries (a box
## sweep and a ray), the body's centre and the box's orientation. The terrain constants are the crawl spike's.

const FLOOR := Rect2(-200, 0, 1800, 40)
const BLOCK := Rect2(200, -100, 100, 100)
const PILLAR := Rect2(450, -160, 40, 160)
const SLAB := Rect2(450, -200, 300, 40)
const LEDGE := Rect2(850, -50, 120, 6)
const SEAM_A := Rect2(1100, -60, 50, 60)
const SEAM_B := Rect2(1150, -60, 50, 60)
const WALL_L := Rect2(-240, -400, 40, 440)
const WALL_R := Rect2(1600, -400, 40, 440)
const EPS := 0.001

## The body's centre and the normal of the surface it is on, which sets the box: 28x24 on a floor or ceiling, 24x28 on a wall.
var pos := Vector2(0, -12)
var n := Vector2.UP
var _hard: Array[Rect2] = []
var _oneway: Array[Rect2] = []

static func build_spike_terrain() -> FakeSurfaceWorld:
	var w := FakeSurfaceWorld.new()
	for r in [FLOOR, BLOCK, PILLAR, SLAB, SEAM_A, SEAM_B, WALL_L, WALL_R]:
		w.add_hard(r)
	w.add_oneway(LEDGE)
	return w

func add_hard(r: Rect2) -> void:
	_hard.append(r)

func add_oneway(r: Rect2) -> void:
	_oneway.append(r)

func half() -> Vector2:
	return Vector2(14, 12) if absf(n.y) > 0.5 else Vector2(12, 14)

## A fresh input whose probes look at this world from the body's current place.
func input() -> MoveInput:
	var i := MoveInput.new()
	i.sweep = _sweep
	i.ray = _ray
	return i

## Moves the body by what the step asked for and takes the surface it chose.
func apply(s: MoveState) -> void:
	pos += s.surface_shift
	if s.surface_n != Vector2.ZERO:
		n = s.surface_n

func _sweep(motion: Vector2) -> Dictionary:
	var best := 2.0
	var normal := Vector2.ZERO
	var h := half()
	for r in _hard:
		var e := Rect2(r.position - h, r.size + h * 2.0)
		var hit := _enter(pos, motion, e)
		if hit.is_empty():
			continue
		var t: float = hit["t"]
		if t < best:
			best = t
			normal = hit["normal"]
	if best > 1.0:
		return {}
	return {"travel": motion * best, "normal": normal}

## When the point `p` moving by `m` enters the (strict interior of the) rectangle `e`: `{"t": 0..1, "normal": Vector2}`.
static func _enter(p: Vector2, m: Vector2, e: Rect2) -> Dictionary:
	var t0 := 0.0
	var t1 := 1.0
	var normal := Vector2.ZERO
	for axis in 2:
		var lo: float = e.position[axis]
		var hi: float = e.end[axis]
		var a: float = p[axis]
		var d: float = m[axis]
		if absf(d) < EPS:
			if a <= lo + EPS or a >= hi - EPS:
				return {}
			continue
		var ta := (lo - a) / d
		var tb := (hi - a) / d
		var face := -1.0 if d > 0.0 else 1.0  # moving up the axis meets the low face, whose normal points the other way
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		if ta > t0:
			t0 = ta
			normal = Vector2.ZERO
			normal[axis] = face
		t1 = minf(t1, tb)
		if t0 > t1 - EPS:
			return {}
	if t0 < 0.0:
		return {}  # already inside it
	return {"t": t0, "normal": normal}

func _ray(from: Vector2, to: Vector2, hard_only: bool) -> int:
	var a := pos + from
	var b := pos + to
	var best := 2.0
	var kind := 0
	for r in _hard:
		var t := _segment(a, b, r)
		if t >= 0.0 and t < best:
			best = t
			kind = 1
	if not hard_only and to.y > from.y:  # a one-way ledge stops a ray going down onto it
		for r in _oneway:
			var t := _segment(a, b, r)
			if t >= 0.0 and t < best:
				best = t
				kind = 2
	return kind

## The first t in 0..1 at which the segment a to b meets the closed rectangle r, or -1.
static func _segment(a: Vector2, b: Vector2, r: Rect2) -> float:
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		var p: float = a[axis]
		var d: float = b[axis] - p
		if absf(d) < EPS:
			if p < lo or p > hi:
				return -1.0
			continue
		var ta := (lo - p) / d
		var tb := (hi - p) / d
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return -1.0
	return t0
