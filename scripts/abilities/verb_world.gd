class_name VerbWorld
extends RefCounted
## Verbs that work on the room: water over the low ground, a trail walked back along, a growth that creeps and shows the way. VerbKinds.run hands every kind in KINDS
## here.

const KINDS := ["flood", "trail", "network", "drink", "rig", "spin"]
const SCHEMA := {
	"flood": {"width": "number", "depth": "number", "seconds": "number"},
	"trail": {"seconds": "number", "speed": "number"},
	"network": {"radius": "number", "seconds": "number", "grow": "number"},
	"drink": {"range": "number", "hp": "number", "mp": "number"},
	"rig": {"range": "number"},
	"spin": {"ladder": "list"},
}
const FLOOD_WIDTH := 320.0
const FLOOD_DEPTH := 96.0
const FLOOD_SECONDS := 6.0
const FLOOR_PROBE := 400.0
const TRAIL_SECONDS := 30.0
const TRAIL_SPEED := 700.0
const NETWORK_RADIUS := 140.0
const NETWORK_SECONDS := 8.0
const NETWORK_GROW := 20.0
const DRINK_RANGE := 50.0
const RIG_RANGE := 200.0
const RIG_THROW_MULT := 1.5
const RIG_TRAP_SECONDS := 30.0
const RIG_SMOKE_SECONDS := 3.0
const RIG_SMOKE_RADIUS := 50.0
const SPIN_LADDER := ["ribs", "flesh", "claw", "bow_arm", "skull", "weapon_arm", "focus"]

static func run(kind: String, a: Ability, spec: Dictionary) -> void:
	match kind:
		"flood":
			flood(a, spec)
		"trail":
			trail(a, spec)
		"network":
			network(a, spec)
		"drink":
			drink(a, spec)
		"rig":
			rig(a, spec)
		"spin":
			spin(a, spec)

## Water fills the low ground round the caster for a while (Flood).
static func flood(a: Ability, spec: Dictionary) -> void:
	var from: Vector2 = a.actor.global_position
	var floor_hit = a.terrain_hit(from, from + Vector2(0.0, FLOOR_PROBE))
	var floor_y: float = floor_hit.y if floor_hit != null else from.y + BodyConfig.BOTTOM
	var w := float(spec.get("width", FLOOD_WIDTH))
	var d := float(spec.get("depth", FLOOD_DEPTH))
	var f := VerbFlood.new()
	a.actor.get_parent().add_child(f)
	f.launch(a.actor, Rect2(from.x - w / 2.0, floor_y - d, w, d), float(spec.get("seconds", FLOOD_SECONDS)))

## The first cast lays a trail; the second walks the caster back along it to its start and spends it (Recall).
static func trail(a: Ability, spec: Dictionary) -> void:
	for t in a.actor.get_tree().get_nodes_in_group("verb_trails"):
		if t.caster == a.actor:
			if a.actor.has_method("follow_path"):
				var back := PackedVector2Array()
				for i in range(t.points.size() - 1, -1, -1):
					back.append(t.points[i])
				a.actor.follow_path(back, float(spec.get("speed", TRAIL_SPEED)))
			t.spend()
			return
	var trail_ := VerbTrail.new()
	a.actor.get_parent().add_child(trail_)
	trail_.launch(a.actor, float(spec.get("seconds", TRAIL_SECONDS)))

## A growth that creeps outward from the caster (Network).
static func network(a: Ability, spec: Dictionary) -> void:
	for old in a.actor.get_tree().get_nodes_in_group("verb_networks"):
		if old.caster == a.actor:
			old.free()
	var n := VerbNetwork.new()
	a.actor.get_parent().add_child(n)
	n.launch(a.actor, a.actor.global_position, float(spec.get("radius", NETWORK_RADIUS)), float(spec.get("seconds", NETWORK_SECONDS)), float(spec.get("grow", NETWORK_GROW)))

## The nearest lamp or pool that can be drunk within `range` of the caster, or null.
static func drinkable(a: Ability, reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach + 0.001
	for n in a.actor.get_tree().get_nodes_in_group("interactable"):
		if n.has_method("is_dry") and n.is_dry():
			continue  # a lamp drunk dry has nothing left
		if n.has_method("prompt") and ["drink", "soak"].has(n.prompt()):
			var d: float = n.global_position.distance_to(a.actor.global_position)
			if d < best_d:
				best = n
				best_d = d
	return best

## Drinks the nearest lamp or glow pool dry: the light goes out, and the caster mends (Drink). With none in reach it is not ready.
static func drink(a: Ability, spec: Dictionary) -> void:
	var n := drinkable(a, float(spec.get("range", DRINK_RANGE)))
	if n == null:
		return
	var result = n.interact(a.actor)
	if result is bool and not result:
		return  # it was dry: nothing was drunk, so nothing is mended
	var health = a.actor.get("health")
	if health != null:
		health.heal(int(spec.get("hp", 0)))
	var mana = a.actor.get("mana")
	if mana != null:
		mana.restore(int(spec.get("mp", 0)))

## Crafts by the way the caster aims: forward a throwable from a carried part, down a rigged trap, up a smoke bomb from a part (Rig).
static func rig(a: Ability, spec: Dictionary) -> void:
	var actor = a.actor
	var aim: Vector2 = a.aim if a.aim != Vector2.ZERO else Vector2(float(actor.get("facing") if actor.get("facing") != null else 1), 0.0)
	if aim.y > 0.5:
		VerbKinds._trap(a, {"seconds": RIG_TRAP_SECONDS, "stun": 2.0})
		return
	if not actor.has_method("corrode_parts") or actor.craft_count() < 1:
		return  # a throwable and a smoke bomb are made from a part (a graft: never a key)
	actor.corrode_parts(1)
	if aim.y < -0.5:
		VerbKinds._veil(a, {"radius": RIG_SMOKE_RADIUS, "seconds": RIG_SMOKE_SECONDS})
		return
	a.power_mult *= RIG_THROW_MULT
	VerbKinds._bolt(a, {"range": float(spec.get("range", RIG_RANGE)), "pierce": false})
	a.power_mult /= RIG_THROW_MULT

## Two carried parts become one better one, a step up the ladder from the better of the two; the other is lost (Spin).
static func spin(a: Ability, spec: Dictionary) -> void:
	var actor = a.actor
	if not actor.has_method("collect_part") or actor.craft_count() < 2:
		return
	var ladder: Array = spec.get("ladder", SPIN_LADDER)
	var rank := 0
	for i in 2:
		var id: String = actor.inventory.take_craft()
		rank = maxi(rank, ladder.find(id))
	actor.collect_part(ladder[mini(rank + 1, ladder.size() - 1)])
