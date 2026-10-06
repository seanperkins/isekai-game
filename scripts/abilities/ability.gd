class_name Ability
extends Node2D
## Base for active skills. The actor supplies facing, team and apply_impulse() (and, for a channelling stream, velocity);
## targets are other-team members of group "actors". Abilities never emit gameplay events themselves.

const COOLDOWN_SECONDS := 0.8

var actor: Node2D
## The skill this is the ability of ("" for a bare ability), so the deeds a cast earns can name it.
var skill_id := ""
var values: Array = []
var level := 1
## Verb parameters from the skill's active effect (a data-defined verb: see VerbKinds). Empty for a scripted ability.
var spec := {}
## Cast direction (unit vector). Zero means "forward", i.e. the actor's facing.
var aim := Vector2.ZERO
var _cooldown := 0.0
## A multiplier on this cast's damage (a stalker's opener); 1 for an ordinary cast. And a cooldown the cast chose for itself (a verb whose next cast
## is the second half of it), -1 to keep the spec's.
var power_mult := 1.0
var cooldown_after := -1.0
## A heavy verb that did not swing (a meal instead of a blow) does not hold its caster still.
var no_swing := false

func setup(p_actor: Node2D, p_values: Array, p_level: int) -> void:
	actor = p_actor
	values = p_values
	level = p_level

func activate() -> bool:
	if _cooldown > 0.0 or actor == null:
		return false
	_cooldown = COOLDOWN_SECONDS
	_perform()
	return true

## True when off cooldown, so the player can check before spending MP.
func ready() -> bool:
	return _cooldown <= 0.0 and actor != null

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

## Channelling (opt in): an ability that can be held. `can_channel` is asked after `aim` is set and before anything is paid;
## `begin_channel` defaults to the one-shot cast, so a tap is today's cast; `channel_tick` returns false to end the hold;
## `end_channel` starts the cooldown. `max_channel` is the hold's cap in seconds (0 = none), set in `_init()` like
## `rope_range`, since a subclass cannot redeclare a parent const.
var max_channel := 0.0

func can_channel() -> bool:
	return false

func begin_channel() -> void:
	_perform()

func channel_tick(_delta: float) -> bool:
	return true

## `hard` is a stop from outside the hold (menu, hit, room change): subclasses also hide their persistent nodes at once.
func end_channel(_hard := false) -> void:
	_cooldown = COOLDOWN_SECONDS

func value() -> int:
	if values.is_empty():
		return 0
	return int(values[clampi(level, 1, values.size()) - 1])

## The most a cast may deal, 0 for no limit. An enemy's verb is held to a multiple of its ATK, so a boss's table value cannot one-shot.
var power_cap := 0

## The damage of a cast: the skill's table value amplified by the caster's ATK, held to `power_cap` when one is set.
func power() -> int:
	var p := Damage.skill_power(value(), actor_atk())
	if power_mult != 1.0:
		p = maxi(1, roundi(float(p) * power_mult))
	return mini(p, power_cap) if power_cap > 0 else p

## The caster's ATK, 1 for an actor without stats (test stubs). Read with get() so a stub needs no property.
func actor_atk() -> int:
	var s = actor.get("stats")
	return int(s.get_stat("atk")) if s != null else 1

func aim_dir() -> Vector2:
	return aim.normalized() if aim != Vector2.ZERO else Vector2(actor.facing, 0.0)

## Every other-team actor that can be hit, unsorted (a corpse must not shadow a living target behind it).
func _foes() -> Array:
	var out: Array = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n == actor or n.get("team") == actor.team or not n.has_method("receive_hit"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		out.append(n)
	return out

## Other-team actors within `radius` of the caster, nearest first.
func targets_around(radius: float) -> Array:
	var out: Array = _foes().filter(func(n): return actor.global_position.distance_to(n.global_position) <= radius)
	out.sort_custom(func(a, b): return actor.global_position.distance_to(a.global_position) < actor.global_position.distance_to(b.global_position))
	return out

## Other-team actors along the aim within `range_px`, at most `half_width` off the line,
## nearest first.
func targets_in_front(range_px: float, half_width: float) -> Array:
	return targets_from(actor.global_position, aim_dir(), range_px, half_width)

## The same from a point and a direction of the caller's choosing (a thrown thing's line, kept as it was thrown).
func targets_from(origin: Vector2, dir: Vector2, range_px: float, half_width: float) -> Array:
	var out: Array = []
	for n in _foes():
		var d: Vector2 = n.global_position - origin
		var along := d.dot(dir)
		if along >= -4.0 and along <= range_px and absf(d.cross(dir)) <= half_width:
			out.append(n)
	out.sort_custom(func(a, b): return (a.global_position - origin).dot(dir) < (b.global_position - origin).dot(dir))
	return out

## The first terrain point on the segment, or null. Actors never block the thread.
func terrain_hit(from: Vector2, to: Vector2):
	var query := PhysicsRayQueryParameters2D.create(from, to)
	var skip: Array[RID] = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n is CollisionObject2D:
			skip.append(n.get_rid())
	query.exclude = skip
	var hit := actor.get_world_2d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit["position"]

func _perform() -> void:
	pass
