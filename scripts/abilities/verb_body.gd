class_name VerbBody
extends RefCounted
## Verbs about what the body does to a creature's flesh: weighing its essence against the caster's, devouring a corpse. VerbKinds.run hands every kind in
## KINDS here.

const KINDS := ["weigh", "devour", "raise", "soul"]
const SCHEMA := {
	"weigh": {"range": "number", "half_width": "number"},
	"devour": {"range": "number", "half_width": "number", "hp": "number"},
	"raise": {"range": "number", "seconds": "number"},
	"soul": {"range": "number", "hp": "number"},
}
const TYPED := ["weigh", "devour"]
const WEIGH_RANGE := 50.0
const WEIGH_HALF_WIDTH := 30.0
const DEVOUR_RANGE := 40.0
const DEVOUR_HEAL := 8
const BOSS_FRACTION := 0.25
const SOUL_HP := 6
const SOUL_RANGE := 240.0
const RAISE_RANGE := 120.0
const RAISE_SECONDS := 10.0

static func run(kind: String, a: Ability, spec: Dictionary) -> void:
	match kind:
		"weigh":
			weigh(a, spec)
		"devour":
			devour(a, spec)
		"raise":
			raise(a, spec)
		"soul":
			soul(a, spec)

## If the creature in front has less essence than the caster holds, it is drained at once (a boss loses a quarter instead); if it has as much or more
## the scales tip against the caster and nothing happens (Weigh).
static func weigh(a: Ability, spec: Dictionary) -> void:
	var foes := a.targets_in_front(float(spec.get("range", WEIGH_RANGE)), float(spec.get("half_width", WEIGH_HALF_WIDTH))).filter(func(n): return n is Enemy)
	if foes.is_empty():
		return
	var t: Enemy = foes[0]
	var theirs := 0
	for v in t.def.essences.values():
		theirs += int(v)
	var mine: int = a.actor.essence_weight() if a.actor.has_method("essence_weight") else 0
	if theirs >= mine:
		Vfx.puffs(a.actor, Art.texture("spit_glob"), [t.global_position + Vector2(0, -10)], Color(0.8, 0.3, 0.3, 0.7), 0.5)
		return
	var dealt: int = int(t.health.max_hp * BOSS_FRACTION) if t.hunting else t.health.hp
	var before := t.health.hp
	t.receive_hit(dealt, str(spec.get("damage_type", "dark")), a.actor.global_position, "weigh", true)
	var health = a.actor.get("health")
	if health != null:
		health.heal(maxi(1, before - t.health.hp))
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [t.global_position + Vector2(0, -10)], Color(0.55, 0.1, 0.1, 0.8), 0.6)

## Eats the nearest corpse in reach and heals; with none it is a swing at what is in front (the heft is the spec's).
static func devour(a: Ability, spec: Dictionary) -> void:
	var reach := float(spec.get("range", DEVOUR_RANGE))
	var corpse: Enemy = null
	var best := reach + 0.001
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if e is Enemy and e.status.state == EnemyStatus.DOWNED:
			var d: float = e.global_position.distance_to(a.actor.global_position)
			if d < best:
				corpse = e
				best = d
	if corpse != null:
		corpse.consume()
		a.no_swing = true  # a meal, not a blow
		var health = a.actor.get("health")
		if health != null:
			health.heal(int(spec.get("hp", DEVOUR_HEAL)))
		Vfx.puffs(a.actor, Art.texture("spit_glob"), [a.actor.global_position + Vector2(0, -6)], Color(0.6, 0.2, 0.2, 0.8), 0.5)
		return
	VerbKinds._strike(a, a.targets_in_front(reach, float(spec.get("half_width", 40.0))), spec)
	Vfx.line(a.actor, a.actor.global_position, a.actor.global_position + a.aim_dir() * reach, VerbKinds._color(spec), 6.0, 0.15)

## Every corpse in reach stands up as a dancer for `seconds`: it wears its own look and fights, dies to a touch, and is no longer a body. With no body near,
## nothing rises (Rise).
static func raise(a: Ability, spec: Dictionary) -> void:
	var reach := float(spec.get("range", RAISE_RANGE))
	var seconds := float(spec.get("seconds", RAISE_SECONDS))
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if not (e is Enemy) or e.status.state != EnemyStatus.DOWNED or e.global_position.distance_to(a.actor.global_position) > reach:
			continue
		var def: CreatureDef = e.consume()
		var ally := VerbAlly.new()
		a.actor.get_parent().add_child(ally)
		ally.launch(a.actor, e.global_position, maxi(a.power(), int(def.stats.get("atk", 1))), seconds, Color(0.8, 0.8, 1.0, 0.9), {"mortal": true, "look": def.id})

## Places the soul's anchor where the caster stands (one at a time): a death within its range is cheated once per life (Hidden soul).
static func soul(a: Ability, spec: Dictionary) -> void:
	for old in a.actor.get_tree().get_nodes_in_group("verb_souls"):
		if old.caster == a.actor:
			old.free()
	var anchor := VerbSoul.new()
	a.actor.get_parent().add_child(anchor)
	anchor.launch(a.actor, a.actor.global_position, int(spec.get("hp", SOUL_HP)), float(spec.get("range", SOUL_RANGE)))
