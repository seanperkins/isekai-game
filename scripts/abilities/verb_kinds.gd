class_name VerbKinds
extends RefCounted
## The primitives a verb is built from. A verb is data: a skill whose active effect carries a `spec` ({"kind": ..., parameters}),
## which VerbAbility hands to run(). Damage is the skill's own (Damage.skill_power of the effect's value and the caster's ATK).

## The scene every data-defined verb uses.
const SCENE := "res://scenes/abilities/verb.tscn"
const KINDS := ["bolt", "burst", "ring", "dash", "zone", "mark", "heal", "ward", "buff"]
## Each kind's keys and what they hold (validate() checks them). Every kind also takes `cooldown` (seconds, in place of the default);
## the kinds in STRIKES also take damage_type and status.
const SCHEMA := {
	"bolt": {"range": "number", "half_width": "number", "pierce": "bool"},
	"burst": {"range": "number", "half_width": "number"},
	"ring": {"radius": "number"},
	"dash": {"speed": "number", "vertical": "number", "hit_range": "number", "hit_half_width": "number"},
	"zone": {"radius": "number", "seconds": "number", "slow": "bool", "heals": "number", "damage": "bool"},
	"mark": {"range": "number", "delay": "number"},
	"heal": {"hp": "number", "mp": "number"},
	"ward": {"seconds": "number"},
	"buff": {"stats": "stats", "seconds": "number"},
}
const STRIKES := ["bolt", "burst", "ring", "dash", "mark"]
const STATUSES := ["slow", "stun", "root"]
const DASH_SPEED := 500.0
const DASH_VERTICAL := 0.6
const DASH_HIT_RANGE := 40.0
const DASH_HIT_HALF_WIDTH := 24.0
const ZONE_RADIUS := 60.0
const ZONE_SECONDS := 3.0
const MARK_RANGE := 200.0
const MARK_DELAY := 4.0
const WARD_SECONDS := 2.0
const BUFF_SECONDS := 5.0
const BUFF_SOURCE := "verb_buff"
const BUFF_GENERATION := "verb_buff_generation"
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
		"dash":
			_dash(ability, spec)
		"zone":
			_zone(ability, spec)
		"mark":
			_mark(ability, spec)
		"heal":
			_heal(ability, spec)
		"ward":
			_ward(ability, spec)
		"buff":
			_buff(ability, spec)

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

static func _dash(a: Ability, spec: Dictionary) -> void:
	var dir := a.aim_dir()
	var speed := float(spec.get("speed", DASH_SPEED))
	a.actor.apply_impulse(Vector2(dir.x * speed, dir.y * speed * float(spec.get("vertical", DASH_VERTICAL))))
	var reach := float(spec.get("hit_range", DASH_HIT_RANGE))
	_strike(a, a.targets_in_front(reach, float(spec.get("hit_half_width", DASH_HIT_HALF_WIDTH))), spec)
	var from := a.actor.global_position
	Vfx.line(a.actor, from, from + dir * reach, _color(spec), 4.0, 0.2)

## A lingering cloud at the caster's feet. It slows by default; `damage` makes it hurt (the skill's power) and `heals` mends the caster.
static func _zone(a: Ability, spec: Dictionary) -> void:
	var cloud := SporeCloudArea.new()
	a.actor.get_parent().add_child(cloud)
	var power := Damage.skill_power(a.value(), a.actor_atk()) if bool(spec.get("damage", false)) else 0
	cloud.launch(a.actor.global_position, float(spec.get("radius", ZONE_RADIUS)), float(spec.get("seconds", ZONE_SECONDS)), a.actor,
		{"damage": power, "slow": bool(spec.get("slow", true)), "heals": int(spec.get("heals", 0)), "color": _color(spec, 0.3)})

## Brands the nearest foe in range; the hit lands `delay` seconds later if it is still there. The power is fixed at the cast.
static func _mark(a: Ability, spec: Dictionary) -> void:
	var foes := a.targets_around(float(spec.get("range", MARK_RANGE)))
	if foes.is_empty():
		return
	var target = foes[0]
	var power := Damage.skill_power(a.value(), a.actor_atk())
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [target.global_position], _color(spec), float(spec.get("delay", MARK_DELAY)))
	a.actor.get_tree().create_timer(float(spec.get("delay", MARK_DELAY))).timeout.connect(_mark_lands.bind(a.actor, target, power, spec))

static func _mark_lands(caster, target, power: int, spec: Dictionary) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	if target.has_method("can_be_hit") and not target.can_be_hit():
		return
	var from: Vector2 = caster.global_position if is_instance_valid(caster) else Vector2.INF
	_hit(target, power, spec, from)

static func _heal(a: Ability, spec: Dictionary) -> void:
	var health = a.actor.get("health")
	var mana = a.actor.get("mana")
	if health != null:
		health.heal(int(spec.get("hp", 0)))
	if mana != null:
		mana.restore(int(spec.get("mp", 0)))

static func _ward(a: Ability, spec: Dictionary) -> void:
	if a.actor.has_method("ward"):
		a.actor.ward(float(spec.get("seconds", WARD_SECONDS)))

## Stat modifiers on the caster for `seconds`, in Stats' timed bucket so a skill refresh does not end them. A second cast replaces
## the first; the first cast's timer then does nothing.
static func _buff(a: Ability, spec: Dictionary) -> void:
	var stats = a.actor.get("stats")
	if stats == null:
		return
	var mods: Array = []
	for stat in spec.get("stats", {}):
		mods.append({"stat": stat, "op": "add", "value": int(spec["stats"][stat])})
	var generation := int(a.actor.get_meta(BUFF_GENERATION, 0)) + 1
	a.actor.set_meta(BUFF_GENERATION, generation)
	stats.set_timed_modifiers(BUFF_SOURCE, mods)
	a.actor.get_tree().create_timer(float(spec.get("seconds", BUFF_SECONDS))).timeout.connect(_buff_ends.bind(a.actor, generation))

static func _buff_ends(actor, generation: int) -> void:
	if is_instance_valid(actor) and int(actor.get_meta(BUFF_GENERATION, 0)) == generation:
		actor.stats.set_timed_modifiers(BUFF_SOURCE, [])

## The skill's damage to each target, then the spec's status.
static func _strike(a: Ability, targets: Array, spec: Dictionary) -> void:
	var power := Damage.skill_power(a.value(), a.actor_atk())
	for t in targets:
		_hit(t, power, spec, a.actor.global_position)

static func _hit(t, power: int, spec: Dictionary, from: Vector2) -> void:
	t.receive_hit(power, str(spec.get("damage_type", "physical")), from, "")
	_apply_status(t, spec.get("status", {}))

## slow: any actor that can be slowed. stun: an Enemy that can be eaten (the serpent cannot be stunned). root: any Enemy, a boss included.
static func _apply_status(t, status: Dictionary) -> void:
	if status.has("slow") and t.has_method("slow_for"):
		t.slow_for(float(status["slow"]))
	if status.has("root") and t.has_method("root_for"):
		t.root_for(float(status["root"]))
	if status.has("stun") and t.get("status") != null and t.get("def") != null and t.def.predatable:
		t.status.stun(float(status["stun"]))

static func _color(spec: Dictionary, alpha := 1.0) -> Color:
	var c: Color = TYPE_COLOR.get(str(spec.get("damage_type", "physical")), Color.WHITE)
	c.a = alpha
	return c

## What is wrong with a spec, as messages (empty when it is fine). A bad spec is reported when the data is checked, never at cast time.
static func validate(spec: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var kind := str(spec.get("kind", ""))
	if not SCHEMA.has(kind):
		out.append("unknown verb kind '%s'" % kind)
		return out
	var keys: Dictionary = SCHEMA[kind].duplicate()
	keys["cooldown"] = "number"
	if kind in STRIKES:
		keys["damage_type"] = "text"
		keys["status"] = "status"
	for key in spec:
		if key == "kind":
			continue
		if not keys.has(key):
			out.append("%s: unknown key '%s'" % [kind, key])
		elif not _fits(spec[key], keys[key]):
			out.append("%s: %s" % [kind, _expects(key, keys[key])])
	if kind == "buff" and not spec.has("stats"):
		out.append("buff: stats must be a dictionary of stat id to number")
	return out

static func _is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

static func _fits(v, what: String) -> bool:
	match what:
		"number":
			return _is_number(v)
		"bool":
			return typeof(v) == TYPE_BOOL
		"text":
			return typeof(v) == TYPE_STRING and v != ""
		"stats":
			return typeof(v) == TYPE_DICTIONARY and not v.is_empty() and v.keys().all(func(k): return Stats.DEFAULTS.has(k) and _is_number(v[k]))
		"status":
			return typeof(v) == TYPE_DICTIONARY and v.keys().all(func(k): return k in STATUSES and _is_number(v[k]))
	return false

static func _expects(key: String, what: String) -> String:
	match what:
		"bool":
			return "%s must be true or false" % key
		"text":
			return "%s must be a damage type name" % key
		"stats":
			return "stats must be a dictionary of stat id to number"
		"status":
			return "status must be slow, stun or root seconds"
	return "%s must be a number" % key
