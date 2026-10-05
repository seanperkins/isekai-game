class_name SpeciesBody
extends RefCounted
## The body a species moves with: the world probes the movement steps need (floor, wall, ceiling, ledges, steps, surfaces, thread
## casts), the species' VerbRunner step, the pull of a mantle or a zip, the crawl on a surface, the collision box and the move itself.
## Both the movement sandbox and the Player use it. A tick is `fill_input`, `think`, then `move`; the caller does what it needs between
## the last two (the sandbox its landing judgement, the Player the water). The body's collision mask is 7: hard solids (layer 1),
## one-way ledges (layer 2) and slick solids (layer 3, value 4).

const WALL_RANGE := 6.0
## The wolf's vault probe: how far ahead it looks (s of travel, at least VAULT_MIN_REACH px) and from how far above the tallest step.
const VAULT_LOOKAHEAD := 0.12
const VAULT_MIN_REACH := 6.0
const VAULT_HEADROOM := 20.0
## The biped's mantle probe: how far inside the ledge the top is read (px), how far above the feet it looks, the shrink of the room
## check, and the lift a pull's blocked test starts from.
const MANTLE_INSET := 4.0
const MANTLE_HEADROOM := 40.0
const MANTLE_ROOM_SHRINK := 2.0
const MANTLE_LIFT := 1.0

var body: CharacterBody2D
var profile: MovementProfile
var state := MoveState.new()
## The vertical speed the step handed the body this tick, before the move: a landing's impact (the move zeroes the body's own).
var fall_speed := 0.0
var _shape: CollisionShape2D
var _box: RectangleShape2D
var _was_on_floor := false
var _landed := false

func _init(p_body: CharacterBody2D, p_shape: CollisionShape2D, p_box: RectangleShape2D) -> void:
	body = p_body
	_shape = p_shape
	_box = p_box

## A new profile and a fresh state: no momentum or timers carry over a switch.
func set_profile(p: MovementProfile) -> void:
	profile = p
	state = MoveState.new()
	body.velocity = Vector2.ZERO

## True while the spider is on a surface (the crawl owns the body this tick).
func is_crawling() -> bool:
	return state.surface_n != Vector2.ZERO

## True on the tick the body touched the floor after being in the air.
func landed() -> bool:
	return _landed

## Fills what the world says into `i`: the floor, the ceiling, the room above, the wall, the one-way floor and the species' probes.
## `hostile` is a Callable returning whether the body overlaps a hostile (the wolf's pounce marks the contact).
func fill_input(i: MoveInput, hostile := Callable()) -> void:
	_was_on_floor = body.is_on_floor()
	i.on_floor = _was_on_floor
	i.clearance_above = _clearance()
	i.wall_side = _wall_side(i.dir)
	i.on_ceiling = body.is_on_ceiling()
	i.on_oneway_floor = _was_on_floor and _stands_on_oneway()
	if profile.verbs.has("crawl"):
		i.sweep = _sweep
		i.ray = _ray
	if profile.verbs.has("zip"):
		i.cast = _cast
	if profile.id == "wolf":
		i.step_ahead = _step_ahead()
		i.touching_hostile = hostile.call() if hostile.is_valid() else false
	if profile.verbs.has("mantle"):
		i.mantle = _mantle(i.wall_side)

## The species' verbs for this tick, and the one-way ledges the body may drop through. `speed_scale` multiplies the walking speed (a
## stat), `jump_boost` the jump.
func think(i: MoveInput, dt: float, jump_boost := 1.0, speed_scale := 1.0) -> void:
	VerbRunner.step(state, i, profile, dt, speed_scale, jump_boost)
	body.set_collision_mask_value(2, state.fall_through <= 0.0)  # a press of down on a one-way ledge drops through it

## Moves the body. On a surface the crawl owns it (the step's shift, the surface's box) and this returns true; otherwise a zip's or
## a mantle's pull is applied, the box is set, `adjust(velocity) -> Vector2` may change the velocity just before the move (the
## caller's last word: water, a landing judgement), then `move_and_slide`. False for an ordinary move.
func move(adjust := Callable()) -> bool:
	_landed = false
	if state.surface_n != Vector2.ZERO:
		_crawl()
		return true
	if profile.verbs.has("mantle") and state.surface_shift != Vector2.ZERO \
			and body.test_move(body.global_transform.translated(Vector2(0.0, -MANTLE_LIFT)), state.surface_shift):
		state.surface_shift = Vector2.ZERO  # something is in the way of the pull (a ceiling over the approach): it stops
		state.mantle_left = 0.0
		state.mantle_event = "blocked"
	body.global_position += state.surface_shift  # a zip or a mantle pulls the body while it is on no surface
	apply_box()
	fall_speed = state.velocity.y
	body.velocity = state.velocity
	if adjust.is_valid():
		body.velocity = adjust.call(body.velocity)
	body.move_and_slide()
	state.velocity = body.velocity
	_landed = not _was_on_floor and body.is_on_floor()
	return false

## The collision box: flat while spread or sliding, its bottom always on the floor.
func apply_box() -> void:
	var size := BodyConfig.spread_size() if VerbRunner.is_flat(state, profile) else BodyConfig.size()
	_box.size = size
	_shape.position.y = BodyConfig.BOTTOM - size.y / 2.0

## The spider on a surface: the step says how far to move and which way is up; this moves the body by it, shapes the box to the
## surface (24 wide on a wall) and lets physics push it out of any overlap the box swap leaves.
func _crawl() -> void:
	body.global_position += state.surface_shift
	_box.size = SurfaceStep.box_size(state.surface_n)
	_shape.position = Vector2.ZERO
	body.move_and_collide(Vector2.ZERO)
	body.velocity = Vector2.ZERO
	state.velocity = Vector2.ZERO

## The zip's cast: the first hard solid along the segment (a one-way ledge's top only for a downward cast), relative to the body.
## A ledge's side or underside is not an anchor: the ray looks past it.
func _cast(from: Vector2, to: Vector2, include_oneway: bool) -> Dictionary:
	var exclude: Array[RID] = [body.get_rid()]
	for _k in 4:
		var q := PhysicsRayQueryParameters2D.create(body.global_position + from, body.global_position + to, 7 if include_oneway else 5, exclude)
		var hit := body.get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return {}
		var collider := hit["collider"] as CollisionObject2D
		var oneway := collider.collision_layer == 2
		if oneway and (hit["normal"] as Vector2).dot(Vector2.UP) < 0.9:
			exclude.append(collider.get_rid())
			continue
		return {"point": (hit["position"] as Vector2) - body.global_position, "normal": hit["normal"], "oneway": oneway, "slick": collider.collision_layer == 4}
	return {}

## Whether the floor the body just slid on is a one-way ledge: its contacts, not a ray under the centre, so a body standing on a
## ledge's edge (the centre past the end, the box still on it) counts.
func _stands_on_oneway() -> bool:
	if not body.is_on_floor():
		return false
	for k in body.get_slide_collision_count():
		var col := body.get_slide_collision(k)
		if col.get_normal().dot(Vector2.UP) > 0.7 and (col.get_collider() as CollisionObject2D).collision_layer == 2:
			return true
	return false

## The crawl's forward probe: how far the box can move along `motion` and what it meets.
func _sweep(motion: Vector2) -> Dictionary:
	var col := KinematicCollision2D.new()
	if not body.test_move(body.global_transform, motion, col):
		return {}
	return {"travel": col.get_travel(), "normal": col.get_normal(), "slick": (col.get_collider() as CollisionObject2D).collision_layer == 4}

## The crawl's ray probe, from the body's centre: what a one-way-aware ray meets (SurfaceStep.NONE, HARD or ONEWAY).
func _ray(from: Vector2, to: Vector2, hard_only: bool) -> int:
	var q := PhysicsRayQueryParameters2D.create(body.global_position + from, body.global_position + to, 5 if hard_only else 7, [body.get_rid()])
	var hit := body.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return SurfaceStep.NONE
	var layer := (hit["collider"] as CollisionObject2D).collision_layer
	return SurfaceStep.SLICK if layer == 4 else (SurfaceStep.ONEWAY if layer == 2 else SurfaceStep.HARD)

## Which side a wall is on within WALL_RANGE (the side the input points to first), 0 for none or on the floor, except for a
## species whose burst ends at a wall (the wolf's pounce runs along the floor into one).
func _wall_side(dir: float) -> int:
	if body.is_on_floor() and not _walls_on_floor():
		return 0
	var first := 1 if dir >= 0.0 else -1
	for side in [first, -first]:
		if body.test_move(body.global_transform, Vector2(side * WALL_RANGE, 0.0)):
			return side
	return 0

func _walls_on_floor() -> bool:
	for row in profile.bursts:
		if (row as BurstDef).ends_at_wall:
			return true
	return false

## The wolf's vault probe: the height of the hard step (a hard or slick solid, never a one-way ledge) at the end of a ray down
## from above the tallest step it clears, VAULT_LOOKAHEAD seconds of travel ahead of the leading edge. 0 for none, when
## it is not running along the floor, or for a hit under 1 px (the floor itself). A wall taller than the ray starts inside
## it, which the ray does not hit: that is a wall too.
func _step_ahead() -> float:
	var way := signf(state.velocity.x)
	if way == 0.0 or not body.is_on_floor():
		return 0.0
	var x := body.global_position.x + way * (_box.size.x / 2.0 + maxf(VAULT_MIN_REACH, absf(state.velocity.x) * VAULT_LOOKAHEAD))
	var feet := body.global_position.y + BodyConfig.BOTTOM
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, feet - profile.vault_step - VAULT_HEADROOM), Vector2(x, feet + 2.0), 5, [body.get_rid()])
	var hit := body.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	var height := feet - (hit["position"] as Vector2).y
	return height if height >= 1.0 else 0.0

## The biped's mantle probe: the displacement from the centre to standing on the hard ledge whose wall is within WALL_RANGE on
## `side`, or ZERO. The ledge's top is the first hit of a ray down, a few px inside the ledge (hard and slick solids, never a
## one-way ledge; a wall taller than the ray starts inside it, which is no hit); the target sits on the top, inset past the
## wall's face, and is reported only when the standing box fits there.
func _mantle(side: int) -> Vector2:
	if side == 0 or body.is_on_floor():
		return Vector2.ZERO
	var half := _box.size.x / 2.0
	var col := KinematicCollision2D.new()
	if not body.test_move(body.global_transform, Vector2(side * WALL_RANGE, 0.0), col):
		return Vector2.ZERO
	var gap := absf(col.get_travel().x)
	var feet := body.global_position.y + BodyConfig.BOTTOM
	var x := body.global_position.x + side * (gap + half + MANTLE_INSET)
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, feet - MANTLE_HEADROOM), Vector2(x, feet + 2.0), 5, [body.get_rid()])
	var hit := body.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Vector2.ZERO
	var rise := feet - (hit["position"] as Vector2).y
	if rise <= 0.0:
		return Vector2.ZERO
	var target := Vector2(side * (gap + 2.0 * half + 2.0), -rise)
	var room := RectangleShape2D.new()
	room.size = BodyConfig.size() - Vector2(MANTLE_ROOM_SHRINK, MANTLE_ROOM_SHRINK)  # the standing box, whatever the pose now
	var shape_q := PhysicsShapeQueryParameters2D.new()
	shape_q.shape = room
	shape_q.transform = Transform2D(0.0, body.global_position + target)
	shape_q.collision_mask = 5
	shape_q.exclude = [body.get_rid()]
	if not body.get_world_2d().direct_space_state.intersect_shape(shape_q, 1).is_empty():
		return Vector2.ZERO
	return target

## Free px above the body: 0 when it could not rise STAND_RISE (a low ceiling), else plenty.
func _clearance() -> float:
	return 0.0 if body.test_move(body.global_transform, Vector2(0.0, -VerbRunner.STAND_RISE)) else 1000.0
