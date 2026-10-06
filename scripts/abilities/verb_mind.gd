class_name VerbMind
extends RefCounted
## Verbs that work on what enemies see and where they go: a stalker's opener, a husk that is swapped for, a short blink, a drifting light, an omen,
## a thread of fate, sabotage, a chase and a swarm. VerbKinds.run hands every kind in KINDS here.

const KINDS := ["stalk", "swap", "blink", "light", "omen", "fate", "sabotage", "chase", "disperse"]
const SCHEMA := {
	"stalk": {"seconds": "number", "opener": "number", "speed": "number", "hit_range": "number", "hit_half_width": "number", "crowd": "number", "crowd_range": "number"},
	"swap": {"seconds": "number", "beat": "number", "lure": "number"},
	"blink": {"distance": "number", "rob": "bool"},
	"light": {"seconds": "number", "speed": "number", "radius": "number", "reveal": "number"},
	"omen": {"range": "number", "seconds": "number"},
	"fate": {"range": "number", "seconds": "number"},
	"sabotage": {"range": "number", "seconds": "number", "backfire": "number"},
	"chase": {"range": "number", "seconds": "number", "spd": "number"},
	"disperse": {"seconds": "number"},
}
const TYPED := ["stalk", "omen", "sabotage"]
const STALK_SECONDS := 6.0
const STALK_OPENER := 4.0
const STALK_CROWD := 3
const STALK_CROWD_RANGE := 220.0
const STALK_SPEED := 420.0
const SWAP_SECONDS := 10.0
const SWAP_BEAT := 0.4
const SWAP_LURE := 180.0
const BLINK_DISTANCE := 90.0
const BLINK_ROB_REACH := 40.0
const BLINK_WALL_GAP := 10.0
const LIGHT_SECONDS := 8.0
const LIGHT_SPEED := 40.0
const LIGHT_RADIUS := 120.0
const LIGHT_REVEAL := 120.0
const OMEN_RANGE := 240.0
const OMEN_SECONDS := 10.0
const FATE_RANGE := 220.0
const FATE_SECONDS := 10.0
const SABOTAGE_RANGE := 160.0
const SABOTAGE_SECONDS := 6.0
const SABOTAGE_BACKFIRE := 0.25
const SABOTAGE_BACKFIRE_SECONDS := 3.0
const CHASE_RANGE := 260.0
const CHASE_SECONDS := 6.0
const CHASE_SPD := 60
const DISPERSE_SECONDS := 3.0
## The luck of a sabotage; a test can seed it.
static var rng := RandomNumberGenerator.new()

static func run(kind: String, a: Ability, spec: Dictionary) -> void:
	match kind:
		"stalk":
			stalk(a, spec)
		"swap":
			swap(a, spec)
		"blink":
			blink(a, spec)
		"light":
			light(a, spec)
		"omen":
			omen(a, spec)
		"fate":
			fate(a, spec)
		"sabotage":
			sabotage(a, spec)
		"chase":
			chase(a, spec)
		"disperse":
			disperse(a, spec)

## From plain sight it lays a veil (unless a crowd is watching); from under one it lunges and strikes for `opener` times the damage (Stalk-kill).
static func stalk(a: Ability, spec: Dictionary) -> void:
	var actor = a.actor
	if not VerbKinds._flag(actor, "cast_unseen"):
		if _crowd(a, float(spec.get("crowd_range", STALK_CROWD_RANGE))) >= int(spec.get("crowd", STALK_CROWD)):
			Vfx.puffs(actor, Art.texture("spit_glob"), [actor.global_position + Vector2(0, -8)], Color(1.0, 0.4, 0.4, 0.7), 0.4)
			a.cooldown_after = 0.5  # a crowd sees you: nothing was stalked
			return
		actor.veil_for(float(spec.get("seconds", STALK_SECONDS)))
		a.cooldown_after = 0.5  # the strike is the next cast
		Vfx.puffs(actor, Art.texture("spit_glob"), [actor.global_position + Vector2(0, -6)], Color(0.3, 0.3, 0.4, 0.6), 0.5)
		return
	var dir: Vector2 = a.aim_dir()
	actor.apply_impulse(Vector2(dir.x * float(spec.get("speed", STALK_SPEED)), 0.0))
	a.power_mult = float(spec.get("opener", STALK_OPENER))
	VerbKinds._strike(a, a.targets_in_front(float(spec.get("hit_range", 60.0)), float(spec.get("hit_half_width", 24.0))).slice(0, 1), spec)
	a.power_mult = 1.0
	Vfx.line(actor, actor.global_position, actor.global_position + dir * float(spec.get("hit_range", 60.0)), VerbKinds._color(spec), 5.0, 0.2)

static func _crowd(a: Ability, within: float) -> int:
	var n := 0
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if e is Enemy and not e.dormant and e.is_threat() and e.global_position.distance_to(a.actor.global_position) <= within:
			n += 1
	return n

## Every enemy within `radius` of the caster goes after `target` for `seconds`.
static func lure_enemies(a: Ability, radius: float, target: Node2D, seconds: float, reckless := false) -> void:
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if e is Enemy and e.global_position.distance_to(a.actor.global_position) <= radius:
			e.lure_to(target, seconds, reckless)

## The first cast leaves a husk that looks like the nearest creature (to scout) and draws enemies; the next trades places with it after a beat (Swap).
static func swap(a: Ability, spec: Dictionary) -> void:
	var actor = a.actor
	var husk = actor.get_meta("verb_swap_husk") if actor.has_meta("verb_swap_husk") else null
	if husk != null and is_instance_valid(husk) and husk.is_inside_tree():
		var beat := float(spec.get("beat", SWAP_BEAT))
		if actor.has_method("hold_still"):
			actor.hold_still(beat)
		actor.get_tree().create_timer(beat).timeout.connect(_trade_places.bind(actor, husk))
		actor.remove_meta("verb_swap_husk")
		return
	var seconds := float(spec.get("seconds", SWAP_SECONDS))
	husk = Vfx.puffs(actor, _scout_texture(a), [Vector2.ZERO], Color(1, 1, 1, 0.85), seconds)
	husk.global_position = actor.global_position
	husk.add_to_group("verb_husks")
	actor.set_meta("verb_swap_husk", husk)
	lure_enemies(a, float(spec.get("lure", SWAP_LURE)), husk, seconds)
	a.cooldown_after = 0.5  # the swap is the next cast

static func _trade_places(actor, husk) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(husk):
		return
	var here: Vector2 = actor.global_position
	actor.global_position = husk.global_position
	husk.global_position = here
	if "velocity" in actor:
		actor.velocity = Vector2.ZERO

## The look of the nearest enemy, else the caster's own.
static func _scout_texture(a: Ability) -> Texture2D:
	var best = null
	var best_d := INF
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if e is Enemy and e._sprite != null and e._sprite.texture != null:
			var d: float = e.global_position.distance_to(a.actor.global_position)
			if d < best_d:
				best = e
				best_d = d
	if best != null:
		return best._sprite.texture
	var own = a.actor.get_node_or_null("Sprite")
	return own.texture if own is Sprite2D else Art.texture("spit_glob")

## A short jump the way the caster faces, stopping short of a wall, that picks a pocket at the other end (Pocket).
static func blink(a: Ability, spec: Dictionary) -> void:
	var actor = a.actor
	var dir: Vector2 = a.aim_dir()
	var from: Vector2 = actor.global_position
	var to := from + dir * float(spec.get("distance", BLINK_DISTANCE))
	var rock = a.terrain_hit(from, to)
	if rock != null:
		to = from + dir * maxf(0.0, from.distance_to(rock) - BLINK_WALL_GAP)
	Vfx.puffs(actor, Art.texture("spit_glob"), [from + Vector2(0, -6), to + Vector2(0, -6)], Color(0.6, 1.0, 0.6, 0.7), 0.3)
	actor.global_position = to
	if "velocity" in actor:
		actor.velocity = Vector2.ZERO
	if bool(spec.get("rob", false)) and actor.has_method("pickpocket"):
		actor.pickpocket(BLINK_ROB_REACH)

## A light that drifts ahead; enemies near it follow it wherever it goes (Lure-light).
static func light(a: Ability, spec: Dictionary) -> void:
	for old in a.actor.get_tree().get_nodes_in_group("verb_lights"):
		if old.caster == a.actor:
			old.free()
	var l := VerbLight.new()
	a.actor.get_parent().add_child(l)
	l.launch(a.actor, a.actor.global_position + Vector2(0, -14), a.aim_dir(), float(spec.get("speed", LIGHT_SPEED)), float(spec.get("seconds", LIGHT_SECONDS)),
		float(spec.get("radius", LIGHT_RADIUS)), float(spec.get("reveal", LIGHT_REVEAL)))

## Marks the nearest foe in range to die in `seconds` unless it cleanses; a new omen takes the place of the last (Omen).
static func omen(a: Ability, spec: Dictionary) -> void:
	var foes := a.targets_around(float(spec.get("range", OMEN_RANGE))).filter(func(n): return n is Enemy)
	if foes.is_empty():
		return
	for old in a.actor.get_tree().get_nodes_in_group("verb_omens"):
		if old.caster == a.actor:
			old.cancel()
	var o := VerbOmen.new()
	a.actor.get_parent().add_child(o)
	o.launch(a.actor, foes[0], float(spec.get("seconds", OMEN_SECONDS)), str(spec.get("damage_type", "dark")))
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [foes[0].global_position + Vector2(0, -10)], VerbKinds._color(spec), float(spec.get("seconds", OMEN_SECONDS)))

## Ties a thread to the nearest foe: the next blow it lands on the caster goes back to it instead (Fate thread).
static func fate(a: Ability, spec: Dictionary) -> void:
	var foes := a.targets_around(float(spec.get("range", FATE_RANGE))).filter(func(n): return n is Enemy)
	if foes.is_empty() or not a.actor.has_method("fate_tie"):
		return
	a.actor.fate_tie(foes[0], float(spec.get("seconds", FATE_SECONDS)))
	Vfx.line(a.actor, a.actor.global_position, foes[0].global_position, Color(0.95, 0.85, 0.5, 0.8), 1.0, 0.5)

## Jams the nearest foe's verb and throwing, and turns every enemy hazard in range (a spear, a glob, a puff) against the nearest enemy; now and then it
## backfires and jams the caster instead (Sabotage).
static func sabotage(a: Ability, spec: Dictionary) -> void:
	var reach := float(spec.get("range", SABOTAGE_RANGE))
	var foes := a.targets_in_front(reach, 40.0).filter(func(n): return n is Enemy)
	var hazards: Array = a.actor.get_tree().get_nodes_in_group("hazards").filter(func(h): return h.global_position.distance_to(a.actor.global_position) <= reach)
	if foes.is_empty() and hazards.is_empty():
		return
	if rng.randf() < float(spec.get("backfire", SABOTAGE_BACKFIRE)):
		if a.actor.has_method("jam"):
			a.actor.jam(SABOTAGE_BACKFIRE_SECONDS)  # the device goes off in your hands
		return
	if not foes.is_empty():
		foes[0].disarm_for(float(spec.get("seconds", SABOTAGE_SECONDS)))
	var power := a.power()
	for h in hazards:
		var owner_ = _nearest_enemy(a, h.global_position)
		if owner_ != null:
			owner_.receive_hit(power, str(spec.get("damage_type", "physical")), h.global_position, "")
		h.queue_free()

static func _nearest_enemy(a: Ability, at: Vector2):
	var best = null
	var best_d := INF
	for e in a.actor.get_tree().get_nodes_in_group("actors"):
		if e is Enemy and e.can_be_hit() and e.global_position.distance_to(at) < best_d:
			best = e
			best_d = e.global_position.distance_to(at)
	return best

## A gallop that nothing slows, and a mark on the nearest foe that is running away: the pounce that catches it costs nothing (Chaser).
static func chase(a: Ability, spec: Dictionary) -> void:
	var seconds := float(spec.get("seconds", CHASE_SECONDS))
	VerbKinds._timed(a, "verb_chase", [{"stat": "spd", "op": "add", "value": int(spec.get("spd", CHASE_SPD))}], seconds)
	if not a.actor.has_method("chase_for"):
		return
	var prey = null
	for e in a.targets_around(float(spec.get("range", CHASE_RANGE))):
		if e is Enemy and (e.is_fleeing() or e.is_running_away()):
			prey = e
			break
	a.actor.chase_for(prey, seconds)

## The body breaks into a swarm for `seconds`: it passes through grates and walls that can be opened, and can neither cast nor strike (Disperse).
static func disperse(a: Ability, spec: Dictionary) -> void:
	if a.actor.has_method("swarm_for"):
		a.actor.swarm_for(float(spec.get("seconds", DISPERSE_SECONDS)))
		Vfx.puffs(a.actor, Art.texture("spit_glob"), [a.actor.global_position + Vector2(-6, -6), a.actor.global_position + Vector2(6, -2), a.actor.global_position + Vector2(0, -10)], Color(0.3, 0.3, 0.3, 0.8), 0.5)
