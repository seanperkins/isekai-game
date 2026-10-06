class_name VerbKinds
extends RefCounted
## The primitives a verb is built from. A verb is data: a skill whose active effect carries a `spec` ({"kind": ..., parameters}),
## which VerbAbility hands to run(). Damage is the skill's own (Damage.skill_power of the effect's value and the caster's ATK).

## The scene every data-defined verb uses.
const SCENE := "res://scenes/abilities/verb.tscn"
const KINDS := ["bolt", "burst", "ring", "dash", "zone", "mark", "heal", "ward", "buff", "pull", "aura", "chain", "engulf", "dissolve", "glide", "anchor", "decoy", "summon", "vine", "transmute", "copy", "reveal", "bridge", "trap", "forge", "rage", "weigh", "devour", "raise", "soul", "hunt", "bark", "flood", "trail", "network", "drink", "rig", "spin", "steal", "companion", "offer", "suckle", "roar", "mount", "stone", "veil", "stalk", "swap", "blink", "light", "omen", "fate", "sabotage", "chase", "disperse"]
## Each kind's keys and what they hold (validate() checks them). Every kind also takes `cooldown` (seconds, in place of the default);
## the kinds in TYPED also take damage_type, and those in STRIKES a status and `drain` (the fraction of the damage the caster heals).
## The keys of a window (Rage), as a verb's own spec (kind rage) or inside any verb's `rage`.
const RAGE_KEYS := {"seconds": "number", "stats": "dict", "kill_refill": "number", "max_seconds": "number", "meter": "dict", "crash": "dict", "dry_lock": "number",
	"forbids": "list", "resist": "dict", "no_flinch": "bool", "bleed": "number", "kill_resets": "list", "unseen_in_dark": "bool", "alone": "dict", "lasting": "dict",
	"swell": "dict", "blow": "dict", "hands": "bool", "size": "number", "burrow": "number", "recast": "dict", "toggle": "bool", "beat": "number", "lock_blow": "bool"}
## What a summon can be told (also inside any verb's `summon`): how many and for how long, whether they are mortal, what they look like, whether they web,
## pounce with the caller, follow its lead or carry parts, how late they come, whom they draw, what they turn, and what they hatch from.
const SUMMON_KEYS := {"count": "number", "seconds": "number", "mortal": "bool", "hp": "number", "look": "text", "web": "bool", "echo": "bool", "command": "bool",
	"carry": "bool", "delay": "number", "lure": "number", "turn": "dict", "from_cocoons": "number", "power_mult": "number", "focus": "dict"}
const SCHEMA := {
	"bolt": {"range": "number", "half_width": "number", "pierce": "bool", "jitter": "number", "returns": "bool", "cursed": "dict", "spend_hp": "bool", "hp_scale": "number", "loose": "bool",
		"reach_with": "dict", "spend_essence": "dict"},
	"burst": {"range": "number", "half_width": "number"},
	"ring": {"radius": "number"},
	"dash": {"speed": "number", "vertical": "number", "hit_range": "number", "hit_half_width": "number", "opener": "number", "smoke": "number", "ride": "dict", "trail": "dict", "drop": "number", "dim": "number", "lit_mult": "number", "hops": "number", "hop_gap": "number", "hop_lift": "number"},
	"zone": {"radius": "number", "seconds": "number", "slow": "bool", "heals": "number", "damage": "bool", "living_only": "bool", "ally_heals": "bool", "spreads": "bool"},
	"mark": {"range": "number", "delay": "number"},
	"heal": {"hp": "number", "mp": "number"},
	"ward": {"seconds": "number"},
	"buff": {"stats": "stats", "seconds": "number"},
	"pull": {"radius": "number", "seconds": "number", "strength": "number", "damage": "bool", "ahead": "number", "pickups": "bool"},
	"aura": {"radius": "number", "seconds": "number", "damage": "bool", "nail": "dict"},
	"chain": {"range": "number", "jump": "number", "hops": "number", "half_width": "number", "hop_delay": "number"},
	"engulf": {"range": "number", "seconds": "number", "small": "number"},
	"dissolve": {"range": "number", "half_width": "number", "corrode": "number"},
	"glide": {"seconds": "number", "fall": "number", "drift": "number", "needs_kill": "number"},
	"anchor": {"seconds": "number"},
	"decoy": {"seconds": "number", "speed": "number", "ward": "number", "lure": "number", "reverse": "number"},
	"summon": SUMMON_KEYS,
	"vine": {"height": "number", "seconds": "number", "grow": "number", "climb": "bool"},
	"transmute": {"from_units": "number", "to_units": "number", "choose": "bool"},
	"copy": {"seconds": "number"},
	"reveal": {"radius": "number"},
	"bridge": {"length": "number", "seconds": "number", "permanent": "bool", "anchors": "bool"},
	"trap": {"seconds": "number", "stun": "number", "lure": "number", "root": "number", "damage": "bool"},
	"forge": {"stat": "stat", "amount": "number", "parts": "number", "also": "dict", "needs_forge": "bool", "named": "bool"},
	"veil": {"seconds": "number", "lit_seconds": "number", "radius": "number", "disguise": "text", "no_web": "bool"},
	"rage": RAGE_KEYS,
}
## The kinds that hurt, which take a `damage_type`; STRIKES are the instant ones, which also take a `status`.
## The kinds an enemy casts (at the player, or on itself); a summon calls hostile minions, a window is a buff, a blink is a short step. The rest need a player's hands: a bridge, a vine, a reveal, a copy.
const ENEMY_KINDS := ["bolt", "burst", "ring", "dash", "zone", "mark", "pull", "aura", "chain", "heal", "ward", "buff", "rage", "blink", "devour", "summon"]
const TYPED := ["bolt", "burst", "ring", "dash", "mark", "zone", "pull", "aura", "chain", "engulf", "dissolve"]
const STRIKES := ["bolt", "burst", "ring", "dash", "mark", "chain", "dissolve"]
## Keys any kind may carry: its cooldown and deed, how long it holds the caster still or locks its blow, the radius it wakes enemies in, whether it is a web
## (a veil that stops webbing refuses it) and whether it can be cast once between rests.
const COMMON := {"cooldown": "number", "deed": "deed", "lock": "number", "still": "number", "alerts": "number", "web": "bool", "once_per_rest": "bool", "rage": "rage", "heft": "number", "summon": "dict", "rally": "dict", "curse": "dict", "blink": "dict", "alt": "dict", "wall": "dict", "needs_headroom": "number"}
const STATUSES := ["slow", "stun", "root", "flee", "calm", "confuse"]
const DASH_SPEED := 500.0
const DASH_VERTICAL := 0.6
const DASH_HIT_RANGE := 40.0
const DASH_HIT_HALF_WIDTH := 24.0
const HOP_GAP := 0.35
const WEB_SPREAD := 300.0
const HOP_LIFT := 220.0
const ZONE_RADIUS := 60.0
const ZONE_SECONDS := 3.0
const MARK_RANGE := 200.0
const MARK_DELAY := 4.0
const WARD_SECONDS := 2.0
const BUFF_SECONDS := 5.0
const PULL_RADIUS := 96.0
const PULL_SECONDS := 3.0
const PULL_STRENGTH := 90.0
const PULL_AHEAD := 70.0
const AURA_RADIUS := 60.0
const AURA_SECONDS := 6.0
const CHAIN_RANGE := 160.0
const CHAIN_JUMP := 80.0
const CHAIN_HOPS := 3
const CHAIN_HALF_WIDTH := 40.0
const ENGULF_RANGE := 40.0
const ENGULF_HALF_WIDTH := 30.0
const ENGULF_SECONDS := 3.0
const ENGULF_RADIUS := 6.0
const ENGULF_SMALL := 12
const DISSOLVE_RANGE := 60.0
const DISSOLVE_HALF_WIDTH := 40.0
const GLIDE_SECONDS := 1.5
const GLIDE_FALL := 40.0
const ANCHOR_SECONDS := 30.0
const ANCHOR_META := "verb_anchor"
const DECOY_SECONDS := 1.2
const DECOY_SPEED := 360.0
const DECOY_WARD := 0.6
const DECOY_LURE := 160.0
const SUMMON_COUNT := 3
const SUMMON_SECONDS := 10.0
const SUMMON_SPACING := 14.0
const VINE_HEIGHT := 160.0
const VINE_SECONDS := 10.0
const VINE_FLOOR_PROBE := 400.0
const TRANSMUTE_FROM := 3
const TRANSMUTE_TO := 2
const COPY_SECONDS := 8.0
const COPY_STATS := ["atk", "def"]
const COPY_SOURCE := "verb_copy"
const REVEAL_RADIUS := 160.0
const BRIDGE_LENGTH := 160.0
const BRIDGE_SECONDS := 15.0
const BRIDGE_REACH := 8.0
const ANCHOR_PROBE := 24.0
const TRAP_SECONDS := 30.0
const TRAP_STUN := 2.0
## How many of one caster's traps stand at once: a cast beyond it takes the place of the oldest.
const TRAP_MAX := 3
const HEFT_STILL := 0.35
const VEIL_SECONDS := 4.0
const VEIL_RADIUS := 60.0
const FORGE_STAT := "atk"
const FORGE_AMOUNT := 2
const FORGE_PARTS := 2
const BUFF_SOURCE := "verb_buff"
const BUFF_GENERATION := "verb_buff_generation"
const BOLT_RANGE := 260.0
const BOLT_HALF_WIDTH := 20.0
const BOLT_RETURN := 0.35
const COPY_RECAST := 0.6
const COPY_MOVE_LIFE := 2.0
const FORGE_REACH := 60.0
const DYED_MULT := 1.5
const LOOSE_RANGE := 220.0
const BURST_RANGE := 60.0
const BURST_HALF_WIDTH := 40.0
const RING_RADIUS := 72.0
const TYPE_COLOR := {"physical": Color(0.92, 0.92, 0.96), "poison": Color(0.55, 0.95, 0.3), "fire": Color(1.0, 0.55, 0.25),
	"water": Color(0.45, 0.75, 1.0), "holy": Color(1.0, 0.92, 0.5), "dark": Color(0.65, 0.45, 0.9)}

static func run(ability: Ability, spec_in: Dictionary) -> void:
	var spec := spec_in
	var actor_rage = ability.actor.get("rage")
	if spec_in.has("recast") and actor_rage != null and actor_rage.active() and actor_rage.skill_id == ability.skill_id:
		spec = spec_in["recast"]  # cast again with hands up: the other form of the verb
	if spec.has("alt"):  # every second cast is the other form
		var key := "verb_alt_%s" % ability.skill_id
		var n := int(ability.actor.get_meta(key, 0))
		ability.actor.set_meta(key, n + 1)
		if n % 2 == 1:
			spec = spec.duplicate()
			spec.merge(spec["alt"], true)
			spec.erase("alt")
	var heft := float(spec.get("heft", 1.0))
	ability.power_mult *= heft  # a heavy swing
	ability.no_swing = false
	_run_kind(ability, spec)
	ability.power_mult /= heft
	if heft != 1.0 and not ability.no_swing and not spec.has("still") and ability.actor.has_method("hold_still"):
		ability.actor.hold_still(HEFT_STILL)  # and a slow one
	_price(ability, spec)
	if spec.has("deed"):
		_deed(ability, str(spec["deed"]))

static func _run_kind(ability: Ability, spec: Dictionary) -> void:
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
		"pull":
			_pull(ability, spec)
		"aura":
			_aura(ability, spec)
		"chain":
			_chain(ability, spec)
		"engulf":
			_engulf(ability, spec)
		"dissolve":
			_dissolve(ability, spec)
		"glide":
			_glide(ability, spec)
		"anchor":
			_anchor(ability, spec)
		"decoy":
			_decoy(ability, spec)
		"summon":
			_summon(ability, spec)
		"vine":
			_vine(ability, spec)
		"transmute":
			_transmute(ability, spec)
		"copy":
			_copy(ability, spec)
		"reveal":
			_reveal(ability, spec)
		"bridge":
			_bridge(ability, spec)
		"trap":
			_trap(ability, spec)
		"forge":
			_forge(ability, spec)
		"veil":
			_veil(ability, spec)
		"rage":
			pass  # all of it is the window `_price` opens
		_:
			var kind := str(spec.get("kind", ""))
			if VerbMind.KINDS.has(kind):
				VerbMind.run(kind, ability, spec)
			elif VerbBody.KINDS.has(kind):
				VerbBody.run(kind, ability, spec)
			elif VerbBond.KINDS.has(kind):
				VerbBond.run(kind, ability, spec)
			elif VerbWorld.KINDS.has(kind):
				VerbWorld.run(kind, ability, spec)

## What a cast costs the caster besides MP, from the keys any kind may carry: it holds still, its own blow is locked, enemies around it wake, and a verb
## cast once between rests is spent.
static func _price(a: Ability, spec: Dictionary) -> void:
	if spec.has("lock") and a.actor.has_method("lock_blow"):
		a.actor.lock_blow(float(spec["lock"]))
	if spec.has("still") and a.actor.has_method("hold_still"):
		a.actor.hold_still(float(spec["still"]))
	if spec.has("alerts"):
		for e in a.actor.get_tree().get_nodes_in_group("actors"):
			if e is Enemy and e.global_position.distance_to(a.actor.global_position) <= float(spec["alerts"]):
				e.wake()
	if spec.has("summon"):
		var call_: Dictionary = {}
		call_.merge(spec["summon"], true)
		_summon(a, call_)
	if spec.has("wall"):  # a wall of web ahead
		var w: Dictionary = spec["wall"]
		var way := 1.0 if float(a.aim_dir().x) >= 0.0 else -1.0
		var wall := VerbWall.new()
		a.actor.get_parent().add_child(wall)
		wall.launch(a.actor, a.actor.global_position + Vector2(way * float(w.get("ahead", 30.0)), BodyConfig.BOTTOM), float(w.get("height", 60.0)), float(w.get("seconds", 8.0)), float(w.get("root", 1.5)))
	if spec.has("rally"):  # a horn rallies the caster's allies and companions
		var r: Dictionary = spec["rally"]
		for ally in a.actor.get_tree().get_nodes_in_group("verb_allies"):
			if ally.caster == a.actor:
				ally.rally(float(r.get("seconds", 6.0)), int(r.get("power", 2)))
		for pal in a.actor.get_tree().get_nodes_in_group("companions"):
			if pal.caster == a.actor:
				pal.rally(float(r.get("seconds", 6.0)), int(r.get("power", 2)))
	if spec.has("curse"):  # a decree marks everything in the room
		var c: Dictionary = spec["curse"]
		for e in a.actor.get_tree().get_nodes_in_group("actors"):
			if e is Enemy and e.global_position.distance_to(a.actor.global_position) <= float(c.get("range", 900.0)):
				e.curse_for(float(c.get("seconds", 10.0)), float(c.get("mult", 1.5)))
	if spec.has("blink"):  # and a blink, away from what is in front
		var b: Dictionary = spec["blink"]
		var dir: Vector2 = a.aim_dir() * (-1.0 if bool(b.get("away", false)) else 1.0)
		var from: Vector2 = a.actor.global_position
		var to := from + dir * float(b.get("distance", 70.0))
		var rock = a.terrain_hit(from, to)
		if rock != null:
			to = from + dir * maxf(0.0, from.distance_to(rock) - 10.0)
		a.actor.global_position = to
		if "velocity" in a.actor:
			a.actor.velocity = Vector2.ZERO
	if spec.has("cloud"):
		var cloud: Dictionary = {"radius": 50.0, "seconds": 4.0, "slow": true, "damage": true, "damage_type": "poison"}
		cloud.merge(spec["cloud"], true)
		_zone(a, cloud)  # a stench cloud where it stands
	if bool(spec.get("once_per_rest", false)):
		a.actor.set_meta(_spent_key(a), true)
	if a.actor.has_method("rage_start"):
		if spec.get("kind", "") == "rage":
			a.actor.rage_start(spec, a.skill_id)
		elif spec.has("rage"):
			a.actor.rage_start(spec["rage"], a.skill_id)

## A true/false property of an actor that may not have it (a stub, an enemy).
static func _flag(actor, name: String) -> bool:
	var v = actor.get(name)
	return v != null and bool(v)

static func _spent_key(a: Ability) -> String:
	return "verb_spent_%s" % a.skill_id

## A verb that can be cast once between rests and has been.
static func spent(a: Ability, spec: Dictionary) -> bool:
	return bool(spec.get("once_per_rest", false)) and a.actor != null and a.actor.has_meta(_spent_key(a))

static func _bolt(a: Ability, spec: Dictionary) -> void:
	var actor = a.actor
	var dir := a.aim_dir()
	var from: Vector2 = actor.global_position
	var reach := float(spec.get("range", BOLT_RANGE))
	if spec.has("reach_with"):  # a bow arm stretches it
		var gear = actor.get("inventory")
		if gear != null and gear.count(str(spec["reach_with"].get("part", ""))) > 0:
			reach *= float(spec["reach_with"].get("mult", 1.0))
	if spec.has("jitter"):  # shapeless: its reach is never quite the same
		reach *= 1.0 + VerbMind.rng.randf_range(-float(spec["jitter"]), float(spec["jitter"]))
	var mult := _shot_cost(a, spec)
	var rock = a.terrain_hit(from, from + dir * reach)
	if rock != null:
		reach = from.distance_to(rock)
	var half := float(spec.get("half_width", BOLT_HALF_WIDTH))
	a.power_mult *= mult
	_bolt_strike(a, spec, reach, half, from, dir)
	a.power_mult /= mult
	Vfx.line(actor, from, from + dir * reach, _color(spec), 2.0, 0.25)
	if bool(spec.get("returns", false)):  # a throw that returns, along the line it went
		actor.get_tree().create_timer(BOLT_RETURN).timeout.connect(_bolt_returns.bind(a, spec, reach, half, mult, from, dir))

static func _bolt_strike(a: Ability, spec: Dictionary, reach: float, half: float, from: Vector2, dir: Vector2) -> void:
	var targets := a.targets_from(from, dir, reach, half)
	if not bool(spec.get("pierce", true)):
		targets = targets.slice(0, 1)
	_strike(a, targets, spec)

static func _bolt_returns(a, spec: Dictionary, reach: float, half: float, mult: float, from: Vector2, dir: Vector2) -> void:  # untyped: the ability may be gone
	if not is_instance_valid(a) or not is_instance_valid(a.actor) or not a.actor.is_inside_tree():
		return
	a.power_mult *= mult
	_bolt_strike(a, spec, reach, half, from, dir)
	a.power_mult /= mult
	Vfx.line(a.actor, from + dir * reach, from, _color(spec), 2.0, 0.25)

## What a shot costs the caster and what it is worth: a cursed Nth shot (it hits harder and costs HP), HP spent on it (all but one, and each is worth `hp_scale`
## damage), a loose object thrown, an essence that dyes it. The damage multiplier.
static func _shot_cost(a: Ability, spec: Dictionary) -> float:
	var actor = a.actor
	var mult := 1.0
	if spec.has("cursed"):
		var key := "verb_shots_%s" % a.skill_id
		var n := int(actor.get_meta(key, 0)) + 1
		var c: Dictionary = spec["cursed"]
		if n >= int(c.get("every", 7)):
			n = 0
			mult *= float(c.get("mult", 3.0))
			var health = actor.get("health")
			if health != null:
				health.take_tick(int(c.get("hp", 4)))  # the seventh is the Devil's: it takes its due, but never the last HP
		actor.set_meta(key, n)
	if bool(spec.get("spend_hp", false)) and _pays(actor):
		var health = actor.get("health")
		if health != null:
			var spent: int = maxi(0, health.hp - 1)
			health.take_tick(spent)
			var base := maxi(1, a.power())
			mult *= float(base + roundi(float(spent) * float(spec.get("hp_scale", 1.0)))) / float(base)
	if bool(spec.get("loose", false)) and _pays(actor):
		var rock = _nearest_loose(actor)
		if rock != null:
			rock.remove_from_group("loose")
			rock.queue_free()
	if spec.has("spend_essence") and _pays(actor):
		for e in spec["spend_essence"]:
			actor.spend_essence_of(str(e), int(spec["spend_essence"][e]))
		mult *= DYED_MULT
	return mult

static func _nearest_loose(actor) -> Node2D:
	var best: Node2D = null
	var best_d := LOOSE_RANGE
	for n in actor.get_tree().get_nodes_in_group("loose"):
		var d: float = n.global_position.distance_to(actor.global_position)
		if d <= best_d:
			best = n
			best_d = d
	return best

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
	var actor = a.actor
	var hops := maxi(1, int(spec.get("hops", 1)))
	if hops > 1 and actor.has_method("in_talisman") and actor.in_talisman():
		return  # a talisman stops a hopping corpse
	var dir := a.aim_dir()
	var aim_before := a.aim
	var mult := 1.0
	if spec.has("drop") and actor.has_method("hangs") and actor.hangs():
		dir = Vector2.DOWN  # from the ceiling it falls on what is below
		a.aim = dir
		mult *= float(spec["drop"])
	if spec.has("dim") and _flag(actor, "in_dark"):
		mult *= float(spec["dim"])
	if spec.has("lit_mult") and not _flag(actor, "in_dark"):
		mult *= float(spec["lit_mult"])
	if spec.has("opener") and _flag(actor, "cast_unseen"):
		mult *= float(spec["opener"])  # a strike out of hiding hits harder
	if spec.has("ride"):  # a charge that is strong mounted and weak on foot
		var pals = actor.get("companions")
		mult *= float(spec["ride"].get("mounted", 1.0)) if pals != null and not pals.is_empty() else float(spec["ride"].get("foot", 1.0))
	a.power_mult *= mult
	_hop(a, spec, dir, hops > 1)
	a.power_mult /= mult
	a.aim = aim_before
	if spec.has("trail"):
		_flame_trail(a, spec, dir)
	var gap := float(spec.get("hop_gap", HOP_GAP))
	for i in range(1, hops):
		actor.get_tree().create_timer(gap * float(i)).timeout.connect(_hop_again.bind(a, spec, dir, mult))
	if spec.has("smoke") and actor.has_method("veil_for"):
		actor.veil_for(float(spec["smoke"]))  # a smoke bomb left behind hides the way out

## A trail of fire laid along the dash: small fields that burn what stands in them, and the caster's own packmates too.
static func _flame_trail(a: Ability, spec: Dictionary, dir: Vector2) -> void:
	var t: Dictionary = spec["trail"]
	var power := maxi(1, a.power() / 2)
	for i in maxi(1, int(t.get("count", 3))):
		var flame := VerbField.new()
		a.actor.get_parent().add_child(flame)
		flame.launch(a.actor, a.actor.global_position + Vector2(dir.x * float(t.get("gap", 24.0)) * float(i + 1), 0.0), float(t.get("radius", 14.0)), float(t.get("seconds", 3.0)),
			{"damage": power, "damage_type": str(spec.get("damage_type", "fire")), "pack": true, "color": _color(spec, 0.35)})

## One leap and its blow. A bounding verb holds the caster's direction between its hops.
static func _hop(a: Ability, spec: Dictionary, dir: Vector2, bounding: bool) -> void:
	var speed := float(spec.get("speed", DASH_SPEED))
	var hold := float(spec.get("hop_gap", HOP_GAP)) + 0.05 if bounding else 0.0
	var lift := -float(spec.get("hop_lift", HOP_LIFT)) if bounding else dir.y * speed * float(spec.get("vertical", DASH_VERTICAL))
	if hold > 0.0:
		a.actor.apply_impulse(Vector2(dir.x * speed, lift), hold)
	else:
		a.actor.apply_impulse(Vector2(dir.x * speed, lift))
	var reach := float(spec.get("hit_range", DASH_HIT_RANGE))
	_strike(a, a.targets_in_front(reach, float(spec.get("hit_half_width", DASH_HIT_HALF_WIDTH))), spec)
	var from: Vector2 = a.actor.global_position
	Vfx.line(a.actor, from, from + dir * reach, _color(spec), 4.0, 0.2)

static func _free_node(node) -> void:  # untyped: it may be gone already
	if is_instance_valid(node):
		node.queue_free()

static func _hop_again(a, spec: Dictionary, dir: Vector2, mult: float) -> void:  # untyped: the ability may be freed by now
	if not is_instance_valid(a) or not is_instance_valid(a.actor) or not a.actor.is_inside_tree():
		return
	a.power_mult *= mult
	_hop(a, spec, dir, true)
	a.power_mult /= mult

## A lingering cloud at the caster's feet. It slows by default; `damage` makes it hurt (the skill's power) and `heals` mends the caster.
static func _zone(a: Ability, spec: Dictionary) -> void:
	var cloud := SporeCloudArea.new()
	a.actor.get_parent().add_child(cloud)
	var power := a.power() if bool(spec.get("damage", false)) else 0
	cloud.launch(a.actor.global_position, float(spec.get("radius", ZONE_RADIUS)), float(spec.get("seconds", ZONE_SECONDS)), a.actor,
		{"damage": power, "slow": bool(spec.get("slow", true)), "heals": int(spec.get("heals", 0)), "color": _color(spec, 0.3),
		"damage_type": str(spec.get("damage_type", "poison")), "living_only": bool(spec.get("living_only", false)), "ally_heals": bool(spec.get("ally_heals", false))})
	if bool(spec.get("web", false)):
		for old in a.actor.get_tree().get_nodes_in_group("player_webs"):
			if bool(spec.get("spreads", false)) and old.global_position.distance_to(cloud.global_position) <= WEB_SPREAD:
				old.poison_up(maxi(1, power))  # the poison runs through the webs already spun
		cloud.add_to_group("player_webs")

## Brands the nearest foe in range; the hit lands `delay` seconds later if it is still there. The power is fixed at the cast.
static func _mark(a: Ability, spec: Dictionary) -> void:
	var foes := a.targets_around(float(spec.get("range", MARK_RANGE)))
	if foes.is_empty():
		return
	var target = foes[0]
	target.set_meta("verb_marked", true)  # until the mark lands: a kill in that time is a marked kill
	var power := a.power()
	var marker := Vfx.puffs(a.actor, Art.texture("spit_glob"), [target.global_position], _color(spec), float(spec.get("delay", MARK_DELAY)))
	marker.add_to_group("verb_marks")
	a.actor.get_tree().create_timer(float(spec.get("delay", MARK_DELAY))).timeout.connect(_mark_lands.bind(a.actor, target, power, spec))

static func _mark_lands(caster, target, power: int, spec: Dictionary) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	if not (target.has_method("can_be_hit") and not target.can_be_hit()):
		var from: Vector2 = caster.global_position if is_instance_valid(caster) else Vector2.INF
		_hit(target, power, spec, from, false, caster)
	if is_instance_valid(target):
		target.remove_meta("verb_marked")  # the mark is spent, landed or not

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

static func _buff(a: Ability, spec: Dictionary) -> void:
	var mods: Array = []
	for stat in spec.get("stats", {}):
		mods.append({"stat": stat, "op": "add", "value": int(spec["stats"][stat])})
	_timed(a, BUFF_SOURCE, mods, float(spec.get("seconds", BUFF_SECONDS)))

## Stat modifiers on the caster for `seconds`, in Stats' timed bucket so a skill refresh does not end them. A second cast of the same
## source replaces the first; the first cast's timer then does nothing.
static func _timed(a: Ability, source: String, mods: Array, seconds: float) -> void:
	var stats = a.actor.get("stats")
	if stats == null:
		return
	var key := "%s_%s" % [BUFF_GENERATION, source]
	var generation := int(a.actor.get_meta(key, 0)) + 1
	a.actor.set_meta(key, generation)
	stats.set_timed_modifiers(source, mods)
	a.actor.get_tree().create_timer(seconds).timeout.connect(_timed_ends.bind(a.actor, source, generation))

static func _timed_ends(actor, source: String, generation: int) -> void:
	if is_instance_valid(actor) and int(actor.get_meta("%s_%s" % [BUFF_GENERATION, source], 0)) == generation:
		actor.stats.set_timed_modifiers(source, [])

## Moves held essence from the element held most to the one held least, at a loss (Transmute).
static func _transmute(a: Ability, spec: Dictionary) -> void:
	if not a.actor.has_method("transmute_essence"):
		return
	var to := ""
	if bool(spec.get("choose", false)) and a.aim != Vector2.ZERO:  # aimed: the ring of elements, going round from the right
		var octant := posmod(roundi(atan2(-a.aim.y, a.aim.x) / (PI / 4.0)), 8)
		to = str(FormEffects.ELEMENT_WHEEL[octant])
	a.actor.transmute_essence(int(spec.get("from_units", TRANSMUTE_FROM)), int(spec.get("to_units", TRANSMUTE_TO)), to)

## The caster takes the last appraised creature's shape and attack and defence for a while, and the shape fades with the time; cast again while it lasts, it makes
## that creature's own move (Copy).
static func _copy(a: Ability, spec: Dictionary) -> void:
	if a.actor.has_method("is_copying") and a.actor.is_copying():
		var move: Dictionary = a.actor.copy_move()
		if not move.is_empty():
			var tmp := VerbAbility.new()
			tmp.actor = a.actor
			tmp.spec = move
			tmp.skill_id = a.actor.copy_def.verb
			tmp.values = SkillEffects.active_values(a.actor._rules.get_def(a.actor.copy_def.verb))
			a.actor.add_child(tmp)
			run(tmp, move)
			a.actor.get_tree().create_timer(COPY_MOVE_LIFE).timeout.connect(_free_node.bind(tmp))  # a delayed effect (a throw's return) needs it a while yet
		return
	var creature = a.actor.get("last_inspected")
	if creature == null:
		return
	var mods: Array = []
	for stat in COPY_STATS:
		var v := int(creature.stats.get(stat, 0))
		if v != 0:
			mods.append({"stat": stat, "op": "add", "value": v})
	_timed(a, COPY_SOURCE, mods, float(spec.get("seconds", COPY_SECONDS)))
	a.cooldown_after = COPY_RECAST  # the creature's own move comes next, well inside the copy
	if a.actor.has_method("copy_creature"):
		a.actor.copy_creature(creature, float(spec.get("seconds", COPY_SECONDS)))

## A field centred `ahead` of the caster that draws foes in (Maelstrom), and hurts them each second when the spec says.
static func _pull(a: Ability, spec: Dictionary) -> void:
	var at: Vector2 = a.actor.global_position + a.aim_dir() * float(spec.get("ahead", PULL_AHEAD))
	_field(a, spec, at, {"pull": float(spec.get("strength", PULL_STRENGTH)), "pickups": bool(spec.get("pickups", false))}, PULL_RADIUS, PULL_SECONDS)

## A field that stays on the caster and hurts what comes near (Guardian).
static func _aura(a: Ability, spec: Dictionary) -> void:
	if spec.has("nail") and a.actor.has_method("nail_for"):  # a visible weak point on the keeper
		a.actor.nail_for(float(spec["nail"].get("seconds", AURA_SECONDS)), int(spec["nail"].get("drain", 3)))
	_field(a, spec, a.actor.global_position, {"follow": a.actor}, AURA_RADIUS, AURA_SECONDS)

static func _field(a: Ability, spec: Dictionary, at: Vector2, opts: Dictionary, radius: float, seconds: float) -> void:
	var field := VerbField.new()
	a.actor.get_parent().add_child(field)
	opts["damage"] = a.power() if bool(spec.get("damage", false)) else 0
	opts["damage_type"] = str(spec.get("damage_type", "physical"))
	opts["color"] = _color(spec, 0.25)
	field.launch(a.actor, at, float(spec.get("radius", radius)), float(spec.get("seconds", seconds)), opts)

## Hits the nearest foe in front, then jumps to the nearest foe within `jump` of it that is not yet hit, `hops` times (Contagion).
static func _chain(a: Ability, spec: Dictionary) -> void:
	var first := a.targets_in_front(float(spec.get("range", CHAIN_RANGE)), float(spec.get("half_width", CHAIN_HALF_WIDTH)))
	if first.is_empty():
		return
	_chain_hit(a, spec, first[0], a.actor.global_position, [], 1 + int(spec.get("hops", CHAIN_HOPS)), a.power())

## One link of a chain: hits `current`, then jumps to the nearest foe not yet hit, at once or, for a contagion slow to build, after `hop_delay`.
static func _chain_hit(a, spec: Dictionary, current, from: Vector2, hit: Array, left: int, power: int) -> void:  # untyped: a timer may call this late
	if left <= 0 or not is_instance_valid(a) or not is_instance_valid(a.actor) or not is_instance_valid(current) or not current.is_inside_tree():
		return
	if current.get("team") == a.actor.get("team"):
		return  # it changed sides while the poison crept toward it
	hit.append(current)
	var here: Vector2 = current.global_position
	_hit(current, power, spec, from, false, a.actor)
	Vfx.line(a.actor, from, here, _color(spec), 2.0, 0.3)
	var next = null
	var best := float(spec.get("jump", CHAIN_JUMP)) + 0.001
	for f in a.targets_around(1.0e9):
		var d: float = f.global_position.distance_to(here)
		if not hit.has(f) and d < best:
			next = f
			best = d
	if next == null:
		return
	var delay := float(spec.get("hop_delay", 0.0))
	if delay > 0.0:
		a.actor.get_tree().create_timer(delay).timeout.connect(_chain_hit.bind(a, spec, next, here, hit, left - 1, power))
	else:
		_chain_hit(a, spec, next, here, hit, left - 1, power)

## Stuns the nearest foe in front that can be stunned and holds it while a field on it digests it, once a second (Engulf).
static func _engulf(a: Ability, spec: Dictionary) -> void:
	var seconds := float(spec.get("seconds", ENGULF_SECONDS))
	for t in a.targets_in_front(float(spec.get("range", ENGULF_RANGE)), ENGULF_HALF_WIDTH):
		if not (t is Enemy) or not t.def.predatable or int(t.def.stats.get("max_hp", 1)) > int(spec.get("small", ENGULF_SMALL)):
			continue  # only a small one can be swallowed
		t.status.stun(seconds)
		var hold := VerbHold.new()
		a.actor.get_parent().add_child(hold)
		hold.launch(a.actor, t, seconds)
		var digest := a.power() if a.value() > 0 else 0
		var field := VerbField.new()
		a.actor.get_parent().add_child(field)
		field.launch(a.actor, t.global_position, ENGULF_RADIUS, seconds,
			{"follow": t, "damage": digest, "damage_type": str(spec.get("damage_type", "physical")), "ignore_def": true, "color": _color(spec, 0.2)})
		return

## A short burst that skips an enemy's armour and opens whatever is in the group `dissolvable` (a weak gate or grate: its own
## `dissolve()`). The skill's damage to an ordinary target.
static func _dissolve(a: Ability, spec: Dictionary) -> void:
	var reach := float(spec.get("range", DISSOLVE_RANGE))
	var half := float(spec.get("half_width", DISSOLVE_HALF_WIDTH))
	var dir: Vector2 = a.aim_dir()
	var from: Vector2 = a.actor.global_position
	var targets := a.targets_in_front(reach, half)
	_strike(a, targets, spec, true, false)
	var ate := targets.any(func(t) -> bool: return t is Enemy and t.def.armored_charger)
	for n in a.actor.get_tree().get_nodes_in_group("dissolvable"):
		var d: Vector2 = n.global_position - from
		if d.dot(dir) >= -4.0 and d.dot(dir) <= reach and absf(d.cross(dir)) <= half and n.has_method("dissolve"):
			n.dissolve()
			ate = true
			_deed(a, Deeds.BARRIER_BROKEN, _id_tag(n))
	if ate and spec.has("corrode") and a.actor.has_method("corrode_parts"):
		a.actor.corrode_parts(int(spec["corrode"]))  # it eats the caster's own too
	Vfx.line(a.actor, from, from + dir * reach, _color(spec), 6.0, 0.2)

## A falling body falls slowly for a while (Ride).
static func _glide(a: Ability, spec: Dictionary) -> void:
	if a.actor.has_method("glide"):
		a.actor.glide(float(spec.get("seconds", GLIDE_SECONDS)), float(spec.get("fall", GLIDE_FALL)), float(spec.get("drift", 0.0)))

## The first cast lays a mark where the caster stands; a cast before it expires puts the caster back on it (Recall).
static func _anchor(a: Ability, spec: Dictionary) -> void:
	var now := float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)  # game time, not the wall clock
	var mark = a.actor.get_meta(ANCHOR_META) if a.actor.has_meta(ANCHOR_META) else null
	if mark != null and now <= float(mark["until"]) and int(mark["room"]) == _room_id(a.actor):
		a.actor.global_position = mark["at"]
		if "velocity" in a.actor:
			a.actor.velocity = Vector2.ZERO
		a.actor.remove_meta(ANCHOR_META)
		return
	a.actor.set_meta(ANCHOR_META, {"at": a.actor.global_position, "until": now + float(spec.get("seconds", ANCHOR_SECONDS)), "room": _room_id(a.actor)})
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [a.actor.global_position], Color(1, 1, 1, 0.7), 2.0)

## The room the caster is in (the World's `room`), 0 when its parent has none: a mark laid in one room is not returned to from another.
static func _room_id(actor: Node2D) -> int:
	var world = actor.get_parent()
	var room = world.get("room") if world != null else null
	return room.get_instance_id() if room != null else 0

## Leaves a husk of the caster's own look where it stood, is untouchable for a moment and throws itself away from where it faces (Shed).
static func _decoy(a: Ability, spec: Dictionary) -> void:
	var sprite = a.actor.get_node_or_null("Sprite")
	var texture: Texture2D = sprite.texture if sprite is Sprite2D else Art.texture("spit_glob")
	var husk := Vfx.puffs(a.actor, texture, [Vector2.ZERO], Color(1, 1, 1, 0.8), float(spec.get("seconds", DECOY_SECONDS)))
	husk.global_position = a.actor.global_position
	husk.add_to_group("verb_husks")
	if sprite is Sprite2D:
		husk.get_child(0).position = sprite.position
		husk.get_child(0).scale = sprite.scale
	if spec.has("lure"):
		VerbMind.lure_enemies(a, float(spec["lure"]), husk, float(spec.get("seconds", DECOY_SECONDS)))
	if spec.has("reverse"):
		for e in a.actor.get_tree().get_nodes_in_group("actors"):
			if e is Enemy and e.global_position.distance_to(a.actor.global_position) <= float(spec.get("lure", DECOY_LURE)):
				e.reverse_for(float(spec["reverse"]))
	if a.actor.has_method("ward"):
		a.actor.ward(float(spec.get("ward", DECOY_WARD)))
	if a.actor.has_method("apply_impulse"):
		a.actor.apply_impulse(Vector2(-float(a.actor.get("facing") if a.actor.get("facing") != null else 1) * float(spec.get("speed", DECOY_SPEED)), 0.0))

## Calls `count` small allies that fight for a while; a second call replaces the first (Court). See SUMMON_KEYS for what they can be told.
static func _summon(a: Ability, spec: Dictionary) -> void:
	if a.actor is Enemy:
		_summon_minions(a, spec)
		return
	for old in a.actor.get_tree().get_nodes_in_group("verb_allies"):
		if old.caster == a.actor:
			old.free()
	var count := maxi(1, int(spec.get("count", SUMMON_COUNT)))
	if spec.has("from_cocoons"):  # young hatch from the cocoons it carries, and none hatch without one
		var carried = a.actor.get("inventory")
		if carried == null or carried.cocoons().is_empty():
			return
		count = 0
		while not carried.cocoons().is_empty():
			carried.take_cocoon()
			count += int(spec["from_cocoons"])
	var power_mult := float(spec.get("power_mult", 1.0))
	if spec.has("focus"):  # a focus carried or worn is a minion more, and they hit harder
		var gear = a.actor.get("inventory")
		if gear != null and gear.count(str(spec["focus"].get("part", "focus"))) > 0:
			count += int(spec["focus"].get("count", 1))
			power_mult *= float(spec["focus"].get("power_mult", 1.0))
	var power := maxi(1, roundi(float(a.power()) * power_mult))
	var seconds := float(spec.get("seconds", SUMMON_SECONDS))
	var delay := float(spec.get("delay", 0.0))
	if delay > 0.0:
		a.actor.get_tree().create_timer(delay).timeout.connect(_call_allies.bind(a.actor, power, count, seconds, spec))
	else:
		_call_allies(a.actor, power, count, seconds, spec)
	if spec.has("turn"):
		var t: Dictionary = spec["turn"]
		for e in a.actor.get_tree().get_nodes_in_group("actors"):
			if e is Enemy and (t.get("ids", []) as Array).has(e.def.id) and e.global_position.distance_to(a.actor.global_position) <= float(t.get("radius", 300.0)):
				e.turn_for(float(t.get("seconds", seconds)))

## An enemy's summon: hostile minions of the creature it `look`s like (a wild slime without one), up to `count` alive at once, gone after `seconds`.
static func _summon_minions(a: Ability, spec: Dictionary) -> void:
	var caster: Enemy = a.actor
	var count := maxi(1, int(spec.get("count", SUMMON_COUNT)))
	var alive := 0
	for n in caster.get_tree().get_nodes_in_group("minions"):
		if n.get_meta("minion_of", null) == caster:
			alive += 1
	var def := VerbAlly._creature(str(spec.get("look", "wild_slime")))
	for i in maxi(0, count - alive):
		var minion := Enemy.new()
		minion.setup(def, VerbAlly.skill_defs())  # with its own verb: a summoned imp curses too
		caster.get_parent().add_child(minion)
		minion.global_position = caster.global_position + Vector2((float(i) - float(count - 1) / 2.0) * SUMMON_SPACING * 1.5, -4.0)
		minion.add_to_group("minions")
		minion.set_meta("minion_of", caster)
		caster.get_tree().create_timer(float(spec.get("seconds", SUMMON_SECONDS))).timeout.connect(_minion_goes.bind(minion))

static func _minion_goes(minion) -> void:  # untyped: it may be gone already
	if is_instance_valid(minion):
		minion.queue_free()

## The allies themselves (a timer may call this after the verb is gone, so its arguments are plain).
static func _call_allies(actor, power: int, count: int, seconds: float, spec: Dictionary) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var opts := {"mortal": bool(spec.get("mortal", false)), "hp": int(spec.get("hp", 1)), "look": str(spec.get("look", "")), "web": bool(spec.get("web", false)),
		"echo": bool(spec.get("echo", false)), "command": bool(spec.get("command", false)), "carry": bool(spec.get("carry", false))}
	var first: VerbAlly = null
	for i in count:
		var ally := VerbAlly.new()
		actor.get_parent().add_child(ally)
		ally.launch(actor, actor.global_position + Vector2((float(i) - float(count - 1) / 2.0) * SUMMON_SPACING, 0.0), power, seconds, Color(0.8, 1.0, 0.8, 0.9), opts)
		if first == null:
			first = ally
	if first != null and spec.has("lure"):
		for e in actor.get_tree().get_nodes_in_group("actors"):
			if e is Enemy and e.global_position.distance_to(actor.global_position) <= float(spec["lure"]):
				e.lure_to(first, seconds)

## One-way steps stacked up from the floor under the caster (Stalk).
static func _vine(a: Ability, spec: Dictionary) -> void:
	var from: Vector2 = a.actor.global_position
	var floor_point = a.terrain_hit(from, from + Vector2(0.0, VINE_FLOOR_PROBE))
	for old in a.actor.get_tree().get_nodes_in_group("verb_vines"):
		if old.get("caster") == a.actor:
			old.free()  # one at a time
	var vine := VerbVine.new()
	a.actor.get_parent().add_child(vine)
	vine.launch(floor_point if floor_point != null else from, float(spec.get("height", VINE_HEIGHT)), float(spec.get("seconds", VINE_SECONDS)),
		float(spec.get("grow", 0.0)), a.actor, bool(spec.get("climb", false)))

## Whatever is in the group `hidden` within `radius` shows itself (`reveal()`): a hidden exit, a weak floor, a shortcut.
static func _reveal(a: Ability, spec: Dictionary) -> void:
	var radius := float(spec.get("radius", REVEAL_RADIUS))
	for n in a.actor.get_tree().get_nodes_in_group("hidden"):
		if n.has_method("reveal") and n.global_position.distance_to(a.actor.global_position) <= radius:
			n.reveal()
			_deed(a, Deeds.HIDDEN_FOUND, _id_tag(n))
	var spots: Array = []
	for i in 12:
		spots.append(a.actor.global_position + Vector2.from_angle(TAU * float(i) / 12.0) * radius * 0.6)
	Vfx.puffs(a.actor, Art.texture("spit_glob"), spots, Color(1.0, 0.95, 0.6, 0.8), 0.4)

## A one-way plank at the caster's feet, `length` long, starting just ahead of it, the way it faces (Span). A second cast replaces it. A permanent one stays for the
## room, and both its ends need an anchor: ground under the caster and ground where it ends.
static func _bridge(a: Ability, spec: Dictionary) -> void:
	for old in a.actor.get_tree().get_nodes_in_group("verb_bridges"):
		if old.caster == a.actor:
			old.free()
	var length := float(spec.get("length", BRIDGE_LENGTH))
	var way := 1.0 if float(a.aim_dir().x) >= 0.0 else -1.0
	var from: Vector2 = a.actor.global_position
	var y := from.y + BodyConfig.BOTTOM
	if bool(spec.get("anchors", false)):
		var far_x := from.x + way * (BRIDGE_REACH + length)
		var here = a.terrain_hit(Vector2(from.x, y - 4.0), Vector2(from.x, y + ANCHOR_PROBE))
		var there = a.terrain_hit(Vector2(far_x, y - 4.0), Vector2(far_x, y + ANCHOR_PROBE))
		if here == null or there == null:
			Vfx.puffs(a.actor, Art.texture("spit_glob"), [from + Vector2(way * 20.0, -6.0)], Color(1.0, 0.5, 0.5, 0.6), 0.5)
			return  # no anchor at one end: nothing holds the web
	var bridge := VerbBridge.new()
	a.actor.get_parent().add_child(bridge)
	bridge.launch(a.actor, Vector2(from.x + way * (BRIDGE_REACH + length / 2.0), y), length, 1.0e9 if bool(spec.get("permanent", false)) else float(spec.get("seconds", BRIDGE_SECONDS)))

## A trap at the caster's feet that the first awake enemy to step on it springs for the skill's damage and a stun (Rig). A fourth
## standing trap of the caster's takes the place of the oldest.
static func _trap(a: Ability, spec: Dictionary) -> void:
	var mine: Array = a.actor.get_tree().get_nodes_in_group("verb_traps").filter(func(t) -> bool: return t.caster == a.actor)
	if mine.size() >= TRAP_MAX:
		mine[0].free()
	var trap := VerbTrap.new()
	a.actor.get_parent().add_child(trap)
	var hurts := bool(spec.get("damage", true))
	trap.launch(a.actor, a.actor.global_position, a.power() if hurts else 0, float(spec.get("seconds", TRAP_SECONDS)), float(spec.get("stun", TRAP_STUN if hurts else 0.0)),
		float(spec.get("lure", 0.0)), float(spec.get("root", 0.0)))

## Hides the caster from every enemy for `seconds`, or for `lit_seconds` in a lit room (Slink). With a `radius` it spins a web there instead, which hides
## whoever of the caster's stands in it (Veil). An attack, a cast or a blow that lands ends either.
static func _veil(a: Ability, spec: Dictionary) -> void:
	if not a.actor.has_method("veil_for"):
		return
	var seconds := float(spec.get("seconds", VEIL_SECONDS))
	if not _flag(a.actor, "in_dark"):
		seconds = float(spec.get("lit_seconds", seconds))
	if spec.has("radius"):
		var web := VerbVeil.new()
		a.actor.get_parent().add_child(web)
		web.launch(a.actor, a.actor.global_position, float(spec["radius"]), seconds)
	else:
		a.actor.veil_for(seconds, str(spec.get("disguise", "")), bool(spec.get("no_web", false)))
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [a.actor.global_position + Vector2(0, -6)], Color(0.8, 0.8, 0.95, 0.6), 0.5)

## Whether the caster can pay for the cast. Only a forge asks for anything: carried parts. A cast that cannot be paid for is not ready, so it
## costs nothing.
static func can_run(a: Ability, spec: Dictionary) -> bool:
	if spec.has("needs_headroom"):  # too big for a small gap
		var from: Vector2 = a.actor.global_position
		if a.terrain_hit(from, from + Vector2(0.0, -float(spec["needs_headroom"]))) != null:
			return false
	if _pays(a.actor):  # what a cast costs is a player's to pay: an enemy's verb is free
		if bool(spec.get("spend_hp", false)):
			var health = a.actor.get("health")
			if health == null or health.hp <= 1:
				return false  # nothing to spend
		for e in spec.get("spend_essence", {}):
			if a.actor.essence_held(str(e)) < int(spec["spend_essence"][e]):
				return false  # needs the blood to dye it
		if bool(spec.get("loose", false)) and _nearest_loose(a.actor) == null:
			return false  # needs loose objects
		if spec.has("needs_kill") and a.actor.kill_age() > float(spec["needs_kill"]):
			return false  # only after a kill
	var kind := str(spec.get("kind", ""))
	if kind == "drink" and VerbWorld.drinkable(a, float(spec.get("range", VerbWorld.DRINK_RANGE))) == null:
		return false  # no lamp or pool to eat
	if kind == "spin" and a.actor.has_method("collect_part") and a.actor.craft_count() < 2:
		return false  # two for one
	if kind == "forge":
		if bool(spec.get("needs_forge", false)) and not _forge_near(a):
			return false  # needs a forge
		return a.actor.has_method("craft_count") and a.actor.craft_count() >= int(spec.get("parts", FORGE_PARTS))
	return true

static func _forge_near(a: Ability) -> bool:
	for f in a.actor.get_tree().get_nodes_in_group("forges"):
		if f.global_position.distance_to(a.actor.global_position) <= FORGE_REACH:
			return true
	return false

## Whether the caster is a body that pays for a cast (a player), not an enemy.
static func _pays(actor) -> bool:
	return actor.has_method("essence_held")

## Spends carried parts on a lasting bonus to a stat for the life (Forge).
static func _forge(a: Ability, spec: Dictionary) -> void:
	if a.actor.forge(str(spec.get("stat", FORGE_STAT)), int(spec.get("amount", FORGE_AMOUNT)), int(spec.get("parts", FORGE_PARTS))):
		for stat in spec.get("also", {}):  # a second slot forged with it
			a.actor.lasting_bonus(str(stat), int(spec["also"][stat]))
		if bool(spec.get("named", false)) and a.actor.has_method("name_weapon"):
			a.actor.name_weapon()
	Vfx.puffs(a.actor, Art.texture("spit_glob"), [a.actor.global_position + Vector2(0, -8)], Color(1.0, 0.7, 0.3, 0.9), 0.4)

## The skill's damage to each target, then the spec's status. `ignore_def` skips an Enemy's DEF.
static func _strike(a: Ability, targets: Array, spec: Dictionary, ignore_def := false, counts := true) -> void:
	var power := a.power()
	for t in targets:
		_hit(t, power, spec, a.actor.global_position, ignore_def, a.actor)
	if counts and a.skill_id != "":  # a strike that found something is a hit, one that found nothing is a miss
		_deed(a, Deeds.SKILL_HIT if not targets.is_empty() else Deeds.SKILL_MISSED, {"id": a.skill_id})

## A deed the caster did, if the caster is the player (an enemy casting the same verb earns nothing).
## {"id": the node's id} for a room feature that has one (a barrier, a hidden door); {} for anything else in the group.
static func _id_tag(n: Node) -> Dictionary:
	return {"id": str(n.id)} if "id" in n and str(n.id) != "" else {}

static func _deed(a: Ability, event_name: String, tags := {}) -> void:
	if a.actor.has_method("emit_deed"):
		a.actor.emit_deed(event_name, tags)

static func _hit(t, power: int, spec: Dictionary, from: Vector2, ignore_def := false, caster = null) -> void:
	var type := str(spec.get("damage_type", "physical"))
	if caster != null and is_instance_valid(caster) and t is Enemy and caster.get("rage") != null:
		power = maxi(1, roundi(float(power) * caster.rage.power_mult_vs(t)))  # a lone hunter's prey with no company
	if type == "dark" and caster != null and is_instance_valid(caster) and caster.get("skillset") != null and caster.skillset.has("trait_dark_weak"):
		power = maxi(1, power / 2)  # weak dark powers
	if spec.has("size_scale") and t is Enemy:
		power = maxi(1, roundi(float(power) * clampf(float(t.def.stats.get("max_hp", 1)) / float(spec["size_scale"]), 0.4, 3.0)))  # the bigger the foe, the harder it falls
	if spec.has("vs_killer") and caster != null and is_instance_valid(caster) and t is Enemy and str(caster.get("avenge_target")) == str(t.def.id):
		power = maxi(1, roundi(float(power) * float(spec["vs_killer"])))  # what killed the last life
	var before := _hp(t)
	if ignore_def and t is Enemy:
		t.receive_hit(power, type, from, "", true)
	else:
		t.receive_hit(power, type, from, "")
	if caster != null and is_instance_valid(caster) and caster.get("rage") != null:
		caster.rage.on_hit(t)
	if caster != null and is_instance_valid(caster) and t is Enemy and caster.has_method("note_target"):
		caster.note_target(t)
	if spec.has("knockdown") and t is Enemy and int(t.def.stats.get("max_hp", 0)) >= DeedTags.HEAVY_HP:
		t.knock_down(float(spec["knockdown"]))  # a heavy one goes down too
	var delay := float(spec.get("status_delay", 0.0))
	if delay > 0.0 and is_instance_valid(t) and t.is_inside_tree():
		t.get_tree().create_timer(delay).timeout.connect(_apply_status.bind(t, spec.get("status", {})))  # slow to take hold
	else:
		_apply_status(t, spec.get("status", {}))
	var drain := float(spec.get("drain", 0.0))
	if drain > 0.0 and caster != null and is_instance_valid(caster) and not (caster.get("skillset") != null and caster.skillset.has("trait_no_drain")):
		var dealt := power if before < 0 else maxi(0, before - _hp(t))  # what the target actually lost; a target with no HP of its own takes the power
		var health = caster.get("health")
		if health != null and dealt > 0:
			health.heal(maxi(1, int(float(dealt) * drain)))  # the caster takes back some of what it dealt

## The target's HP, -1 for one that has none (a switch, a stub).
static func _hp(t) -> int:
	var health = t.get("health")
	return health.hp if health != null else -1

## slow: any actor that can be slowed. stun: an Enemy that can be eaten (the serpent cannot be stunned). root: any Enemy, a boss included.
## flee, calm, confuse: an Enemy that is not a hunting boss (the mind conditions, Enemy.flee_for and its kin).
static func _apply_status(t, status: Dictionary) -> void:
	if not is_instance_valid(t):
		return
	if status.has("slow") and t.has_method("slow_for"):
		t.slow_for(float(status["slow"]))
	if status.has("root") and t.has_method("root_for"):
		t.root_for(float(status["root"]))
	if status.has("flee") and t.has_method("flee_for"):
		t.flee_for(float(status["flee"]))
	if status.has("calm") and t.has_method("calm_for"):
		t.calm_for(float(status["calm"]))
	if status.has("confuse") and t.has_method("confuse_for"):
		t.confuse_for(float(status["confuse"]))
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
	if _schema(kind).is_empty():
		out.append("unknown verb kind '%s'" % kind)
		return out
	var keys: Dictionary = _schema(kind).duplicate()
	keys.merge(COMMON)  # any verb may say a deed (Deeds) when the player casts it
	if kind in TYPED or kind in VerbMind.TYPED or kind in VerbBody.TYPED:
		keys["damage_type"] = "text"
	if kind in STRIKES:
		keys["status"] = "status"
		keys["status_delay"] = "number"
		keys["knockdown"] = "number"
		keys["vs_killer"] = "number"
		keys["size_scale"] = "number"
		keys["cloud"] = "dict"
		keys["drain"] = "number"
	for key in spec:
		if key == "kind":
			continue
		if not keys.has(key):
			out.append("%s: unknown key '%s'" % [kind, key])
		elif not _fits(spec[key], keys[key]):
			out.append("%s: %s" % [kind, _expects(key, keys[key])])
		elif key == "drain" and (float(spec[key]) < 0.0 or float(spec[key]) > 1.0):
			out.append("%s: drain must be from 0 to 1" % kind)
		elif key == "deed" and not Deeds.known(str(spec[key])):
			out.append("%s: deed '%s' is not a deed" % [kind, spec[key]])
	if kind == "buff" and not spec.has("stats"):
		out.append("buff: stats must be a dictionary of stat id to number")
	return out

## The keys of a kind: the ones here, or a pack's.
static func _schema(kind: String) -> Dictionary:
	if SCHEMA.has(kind):
		return SCHEMA[kind]
	return VerbMind.SCHEMA.get(kind, VerbBody.SCHEMA.get(kind, VerbBond.SCHEMA.get(kind, VerbWorld.SCHEMA.get(kind, {}))))

static func _is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

static func _fits(v, what: String) -> bool:
	match what:
		"number":
			return _is_number(v)
		"bool":
			return typeof(v) == TYPE_BOOL
		"dict":
			return typeof(v) == TYPE_DICTIONARY
		"list":
			return typeof(v) == TYPE_ARRAY
		"text", "deed":
			return typeof(v) == TYPE_STRING and v != ""
		"stat":
			return typeof(v) == TYPE_STRING and Stats.DEFAULTS.has(v)
		"stats":
			return typeof(v) == TYPE_DICTIONARY and not v.is_empty() and v.keys().all(func(k): return Stats.DEFAULTS.has(k) and _is_number(v[k]))
		"status":
			return typeof(v) == TYPE_DICTIONARY and v.keys().all(func(k): return k in STATUSES and _is_number(v[k]))
		"rage":
			return typeof(v) == TYPE_DICTIONARY and _rage_fits(v)
	return false

## Whether a `rage` dictionary has only window keys of the right shape.
static func _rage_fits(v: Dictionary) -> bool:
	return v.keys().all(func(k): return RAGE_KEYS.has(k) and _fits(v[k], RAGE_KEYS[k]))

static func _expects(key: String, what: String) -> String:
	match what:
		"rage":
			return "rage must be a dictionary of window keys"
		"dict":
			return "%s must be a dictionary" % key
		"list":
			return "%s must be a list" % key
		"bool":
			return "%s must be true or false" % key
		"deed":
			return "deed must be a deed name"
		"stat":
			return "stat must be a stat id"
		"text":
			return "%s must be a damage type name" % key
		"stats":
			return "stats must be a dictionary of stat id to number"
		"status":
			return "status must be seconds of slow, stun, root, flee, calm or confuse"
	return "%s must be a number" % key
