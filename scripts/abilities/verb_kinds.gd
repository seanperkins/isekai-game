class_name VerbKinds
extends RefCounted
## The primitives a verb is built from. A verb is data: a skill whose active effect carries a `spec` ({"kind": ..., parameters}),
## which VerbAbility hands to run(). Damage is the skill's own (Damage.skill_power of the effect's value and the caster's ATK).

const KINDS := ["bolt", "burst", "ring"]
const BOLT_RANGE := 260.0
const BOLT_HALF_WIDTH := 20.0
const BURST_RANGE := 60.0
const BURST_HALF_WIDTH := 40.0
const RING_RADIUS := 72.0
const TYPE_COLOR := {"physical": Color(0.92, 0.92, 0.96), "poison": Color(0.55, 0.95, 0.3), "fire": Color(1.0, 0.55, 0.25),
	"water": Color(0.45, 0.75, 1.0), "holy": Color(1.0, 0.92, 0.5), "dark": Color(0.65, 0.45, 0.9)}

static func run(ability: Ability, spec: Dictionary) -> void:
	match spec.get("kind", ""):
		"bolt":
			_bolt(ability, spec)
		"burst":
			_burst(ability, spec)
		"ring":
			_ring(ability, spec)

static func _bolt(a: Ability, spec: Dictionary) -> void:
	var dir := a.aim_dir()
	var from := a.actor.global_position
	var reach := float(spec.get("range", BOLT_RANGE))
	var rock = a.terrain_hit(from, from + dir * reach)
	if rock != null:
		reach = from.distance_to(rock)
	var targets := a.targets_in_front(reach, float(spec.get("half_width", BOLT_HALF_WIDTH)))
	if not bool(spec.get("pierce", true)):
		targets = targets.slice(0, 1)
	_strike(a, targets, spec)
	Vfx.line(a.actor, from, from + dir * reach, _color(spec), 2.0, 0.25)

static func _burst(a: Ability, spec: Dictionary) -> void:
	var reach := float(spec.get("range", BURST_RANGE))
	_strike(a, a.targets_in_front(reach, float(spec.get("half_width", BURST_HALF_WIDTH))), spec)
	var from := a.actor.global_position
	Vfx.line(a.actor, from, from + a.aim_dir() * reach, _color(spec), 6.0, 0.15)

static func _ring(a: Ability, spec: Dictionary) -> void:
	var radius := float(spec.get("radius", RING_RADIUS))
	_strike(a, a.targets_around(radius), spec)
	var spots: Array = []
	for i in 8:
		spots.append(a.actor.global_position + Vector2.from_angle(TAU * float(i) / 8.0) * radius * 0.7)
	Vfx.puffs(a.actor, Art.texture("spit_glob"), spots, _color(spec), 0.3)

## The skill's damage to each target, then the spec's status.
static func _strike(a: Ability, targets: Array, spec: Dictionary) -> void:
	var power := Damage.skill_power(a.value(), a.actor_atk())
	var type := str(spec.get("damage_type", "physical"))
	for t in targets:
		t.receive_hit(power, type, a.actor.global_position, "")
		_apply_status(t, spec.get("status", {}))

## slow: any actor that can be slowed. stun: an Enemy that can be eaten (the serpent cannot be stunned).
static func _apply_status(t, status: Dictionary) -> void:
	if status.has("slow") and t.has_method("slow_for"):
		t.slow_for(float(status["slow"]))
	if status.has("stun") and t.get("status") != null and t.get("def") != null and t.def.predatable:
		t.status.stun(float(status["stun"]))

static func _color(spec: Dictionary) -> Color:
	return TYPE_COLOR.get(str(spec.get("damage_type", "physical")), Color.WHITE)
