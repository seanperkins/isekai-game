class_name VerbBond
extends RefCounted
## Verbs about the bond between the caster and other creatures: a lasting packmate (or two, or a swarm), an offer to a weakened creature, a pup that grows, a roar
## that turns the wild pack, a ride. VerbKinds.run hands every kind in KINDS here.

const KINDS := ["companion", "offer", "suckle", "roar", "mount", "stone"]
const SCHEMA := {
	"companion": {"creature": "text", "count": "number", "hp": "number", "swarm": "bool"},
	"offer": {"range": "number", "weak": "number"},
	"suckle": {"radius": "number", "hp": "number", "grow": "number"},
	"roar": {"radius": "number", "seconds": "number"},
	"mount": {"seconds": "number", "stats": "dict"},
	"stone": {"radius": "number", "max": "number", "slow": "bool", "heals": "number", "protect": "bool", "status": "status", "link": "number", "afraid_allies": "bool",
		"holy": "bool", "tether": "number", "seconds": "number"},
}
const OFFER_RANGE := 60.0
const OFFER_WEAK := 0.5
const SUCKLE_RADIUS := 80.0
const SUCKLE_HP := 3
const SUCKLE_GROW := 3
const ROAR_RADIUS := 400.0
const ROAR_SECONDS := 8.0
const MOUNT_SECONDS := 12.0
const STONE_MAX := 2
const SUCKLED_KEY := "verb_suckled"

static func run(kind: String, a: Ability, spec: Dictionary) -> void:
	match kind:
		"companion":
			companion(a, spec)
		"offer":
			offer(a, spec)
		"suckle":
			suckle(a, spec)
		"roar":
			roar(a, spec)
		"mount":
			mount(a, spec)
		"stone":
			stone(a, spec)

static func _def(id: String) -> CreatureDef:
	return VerbAlly._creature(id)

## Bonds `count` creatures of a kind as lasting companions, as many as the body keeps (Bond, Two companions, Knot).
static func companion(a: Ability, spec: Dictionary) -> void:
	if not a.actor.has_method("add_companion"):
		return
	var def := _def(str(spec.get("creature", "gloom_wolf")))
	for i in maxi(1, int(spec.get("count", 1))):
		var opts := {"swarm": bool(spec.get("swarm", false))}
		if spec.has("hp"):
			opts["hp"] = int(spec["hp"])
		a.actor.add_companion(def, a.actor.global_position + Vector2((float(i) - 0.5) * 16.0, 0.0), opts)

## Tames the nearest weakened creature that can be tamed with a carried part (Offer).
static func offer(a: Ability, spec: Dictionary) -> void:
	if a.actor.has_method("try_offer"):
		a.actor.try_offer(float(spec.get("range", OFFER_RANGE)), float(spec.get("weak", OFFER_WEAK)))

## Mends every companion and ally in reach; each `grow`th time a pup of the packmate's kind grows into a second packmate (Suckle).
static func suckle(a: Ability, spec: Dictionary) -> void:
	var radius := float(spec.get("radius", SUCKLE_RADIUS))
	var heal := int(spec.get("hp", SUCKLE_HP))
	var first: Companion = null
	for pal in a.actor.get_tree().get_nodes_in_group("companions"):
		if pal.caster == a.actor and pal.global_position.distance_to(a.actor.global_position) <= radius:
			pal.heal(heal)
			if first == null:
				first = pal
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [a.actor.global_position + Vector2(0, -8)], Color(1.0, 0.9, 0.6, 0.6), 0.5)
	if first == null or not a.actor.has_method("add_companion"):
		return
	var n := int(a.actor.get_meta(SUCKLED_KEY, 0)) + 1
	if n >= int(spec.get("grow", SUCKLE_GROW)):
		n = 0
		a.actor.add_companion(first.def, first.global_position + Vector2(-12, 0), {"hp": maxi(1, first.max_hp / 2)})
	a.actor.set_meta(SUCKLED_KEY, n)

## Every pack creature within `radius` fights for the caster for `seconds` (First Wolf's roar).
static func roar(a: Ability, spec: Dictionary) -> void:
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if e is Enemy and e.def.pack and e.global_position.distance_to(a.actor.global_position) <= float(spec.get("radius", ROAR_RADIUS)):
			e.turn_for(float(spec.get("seconds", ROAR_SECONDS)))

## Fuses with a companion for a ride: the stat window, and the companion takes the blows meant for its rider (Mount).
static func mount(a: Ability, spec: Dictionary) -> void:
	if not a.actor.has_method("mount_with"):
		return
	var pal = null
	for p in a.actor.get_tree().get_nodes_in_group("companions"):
		if p.caster == a.actor:
			pal = p
			break
	if pal == null:
		return
	var seconds := float(spec.get("seconds", MOUNT_SECONDS))
	a.actor.mount_with(pal, seconds)
	a.actor.rage_start({"seconds": seconds, "stats": spec.get("stats", {})}, a.skill_id)

## Plants a stone where the caster stands; only `max` stand at once, and a new one takes the oldest one's place (Hearth, Lar, Ward, a fear stone, holy ground).
static func stone(a: Ability, spec: Dictionary) -> void:
	var mine: Array = a.actor.get_tree().get_nodes_in_group("ward_stones").filter(func(s) -> bool: return s.caster == a.actor)
	while mine.size() >= int(spec.get("max", STONE_MAX)):
		mine.pop_front().free()
	var stone := WardStone.new()
	a.actor.get_parent().add_child(stone)
	stone.launch(a.actor, a.actor.global_position, spec)
