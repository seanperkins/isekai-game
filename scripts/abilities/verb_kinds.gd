class_name VerbKinds
extends RefCounted
## The primitives a verb is built from. A verb is data: a skill whose active effect carries a `spec` ({"kind": ..., parameters}),
## which VerbAbility hands to run(). Damage is the skill's own (Damage.skill_power of the effect's value and the caster's ATK).

## The scene every data-defined verb uses.
const SCENE := "res://scenes/abilities/verb.tscn"
const KINDS := ["bolt", "burst", "ring", "dash", "zone", "mark", "heal", "ward", "buff", "pull", "aura", "chain", "engulf", "dissolve", "glide", "anchor", "decoy", "summon", "vine", "transmute", "copy", "reveal", "bridge"]
## Each kind's keys and what they hold (validate() checks them). Every kind also takes `cooldown` (seconds, in place of the default);
## the kinds in TYPED also take damage_type, and those in STRIKES a status and `drain` (the fraction of the damage the caster heals).
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
	"pull": {"radius": "number", "seconds": "number", "strength": "number", "damage": "bool", "ahead": "number"},
	"aura": {"radius": "number", "seconds": "number", "damage": "bool"},
	"chain": {"range": "number", "jump": "number", "hops": "number", "half_width": "number"},
	"engulf": {"range": "number", "seconds": "number"},
	"dissolve": {"range": "number", "half_width": "number"},
	"glide": {"seconds": "number", "fall": "number"},
	"anchor": {"seconds": "number"},
	"decoy": {"seconds": "number", "speed": "number", "ward": "number"},
	"summon": {"count": "number", "seconds": "number"},
	"vine": {"height": "number", "seconds": "number"},
	"transmute": {"from_units": "number", "to_units": "number"},
	"copy": {"seconds": "number"},
	"reveal": {"radius": "number"},
	"bridge": {"length": "number", "seconds": "number"},
}
## The kinds that hurt, which take a `damage_type`; STRIKES are the instant ones, which also take a `status`.
## The kinds an enemy casts (at the player, or on itself). The rest need a player's hands: a summon, a bridge, a vine, a reveal, a copy.
const ENEMY_KINDS := ["bolt", "burst", "ring", "dash", "zone", "mark", "pull", "aura", "chain", "heal", "ward", "buff"]
const TYPED := ["bolt", "burst", "ring", "dash", "mark", "zone", "pull", "aura", "chain", "engulf", "dissolve"]
const STRIKES := ["bolt", "burst", "ring", "dash", "mark", "chain", "dissolve"]
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
const DISSOLVE_RANGE := 60.0
const DISSOLVE_HALF_WIDTH := 40.0
const GLIDE_SECONDS := 1.5
const GLIDE_FALL := 40.0
const ANCHOR_SECONDS := 30.0
const ANCHOR_META := "verb_anchor"
const DECOY_SECONDS := 1.2
const DECOY_SPEED := 360.0
const DECOY_WARD := 0.6
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
	if spec.has("deed"):
		_deed(ability, str(spec["deed"]))

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
	var power := a.power() if bool(spec.get("damage", false)) else 0
	cloud.launch(a.actor.global_position, float(spec.get("radius", ZONE_RADIUS)), float(spec.get("seconds", ZONE_SECONDS)), a.actor,
		{"damage": power, "slow": bool(spec.get("slow", true)), "heals": int(spec.get("heals", 0)), "color": _color(spec, 0.3),
		"damage_type": str(spec.get("damage_type", "poison"))})

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
	if a.actor.has_method("transmute_essence"):
		a.actor.transmute_essence(int(spec.get("from_units", TRANSMUTE_FROM)), int(spec.get("to_units", TRANSMUTE_TO)))

## The caster takes the last appraised creature's attack and defence for a while (Copy).
static func _copy(a: Ability, spec: Dictionary) -> void:
	var creature = a.actor.get("last_inspected")
	if creature == null:
		return
	var mods: Array = []
	for stat in COPY_STATS:
		var v := int(creature.stats.get(stat, 0))
		if v != 0:
			mods.append({"stat": stat, "op": "add", "value": v})
	_timed(a, COPY_SOURCE, mods, float(spec.get("seconds", COPY_SECONDS)))

## A field centred `ahead` of the caster that draws foes in (Maelstrom), and hurts them each second when the spec says.
static func _pull(a: Ability, spec: Dictionary) -> void:
	var at: Vector2 = a.actor.global_position + a.aim_dir() * float(spec.get("ahead", PULL_AHEAD))
	_field(a, spec, at, {"pull": float(spec.get("strength", PULL_STRENGTH))}, PULL_RADIUS, PULL_SECONDS)

## A field that stays on the caster and hurts what comes near (Guardian).
static func _aura(a: Ability, spec: Dictionary) -> void:
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
	var power := a.power()
	var jump := float(spec.get("jump", CHAIN_JUMP))
	var hit: Array = []
	var current = first[0]
	var from: Vector2 = a.actor.global_position
	for i in 1 + int(spec.get("hops", CHAIN_HOPS)):
		hit.append(current)
		var here: Vector2 = current.global_position
		_hit(current, power, spec, from, false, a.actor)
		Vfx.line(a.actor, from, here, _color(spec), 2.0, 0.3)
		var next = null
		var best := jump + 0.001
		for f in a.targets_around(1.0e9):
			var d: float = f.global_position.distance_to(here)
			if not hit.has(f) and d < best:
				next = f
				best = d
		if next == null:
			break
		from = here
		current = next

## Stuns the nearest foe in front that can be stunned and holds it while a field on it digests it, once a second (Engulf).
static func _engulf(a: Ability, spec: Dictionary) -> void:
	var seconds := float(spec.get("seconds", ENGULF_SECONDS))
	for t in a.targets_in_front(float(spec.get("range", ENGULF_RANGE)), ENGULF_HALF_WIDTH):
		if not (t is Enemy) or not t.def.predatable:
			continue
		t.status.stun(seconds)
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
	_strike(a, a.targets_in_front(reach, half), spec, true, false)
	for n in a.actor.get_tree().get_nodes_in_group("dissolvable"):
		var d: Vector2 = n.global_position - from
		if d.dot(dir) >= -4.0 and d.dot(dir) <= reach and absf(d.cross(dir)) <= half and n.has_method("dissolve"):
			n.dissolve()
			_deed(a, Deeds.BARRIER_BROKEN)
	Vfx.line(a.actor, from, from + dir * reach, _color(spec), 6.0, 0.2)

## A falling body falls slowly for a while (Ride).
static func _glide(a: Ability, spec: Dictionary) -> void:
	if a.actor.has_method("glide"):
		a.actor.glide(float(spec.get("seconds", GLIDE_SECONDS)), float(spec.get("fall", GLIDE_FALL)))

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
	if a.actor.has_method("ward"):
		a.actor.ward(float(spec.get("ward", DECOY_WARD)))
	if a.actor.has_method("apply_impulse"):
		a.actor.apply_impulse(Vector2(-float(a.actor.get("facing") if a.actor.get("facing") != null else 1) * float(spec.get("speed", DECOY_SPEED)), 0.0))

## Calls `count` small allies that fight for a while; a second call replaces the first (Court).
static func _summon(a: Ability, spec: Dictionary) -> void:
	for old in a.actor.get_tree().get_nodes_in_group("verb_allies"):
		if old.caster == a.actor:
			old.free()
	var count := maxi(1, int(spec.get("count", SUMMON_COUNT)))
	var power := a.power()
	for i in count:
		var ally := VerbAlly.new()
		a.actor.get_parent().add_child(ally)
		ally.launch(a.actor, a.actor.global_position + Vector2((float(i) - float(count - 1) / 2.0) * SUMMON_SPACING, 0.0), power,
			float(spec.get("seconds", SUMMON_SECONDS)), Color(0.8, 1.0, 0.8, 0.9))

## One-way steps stacked up from the floor under the caster (Stalk).
static func _vine(a: Ability, spec: Dictionary) -> void:
	var from: Vector2 = a.actor.global_position
	var floor_point = a.terrain_hit(from, from + Vector2(0.0, VINE_FLOOR_PROBE))
	var vine := VerbVine.new()
	a.actor.get_parent().add_child(vine)
	vine.launch(floor_point if floor_point != null else from, float(spec.get("height", VINE_HEIGHT)), float(spec.get("seconds", VINE_SECONDS)))

## Whatever is in the group `hidden` within `radius` shows itself (`reveal()`): a hidden exit, a weak floor, a shortcut.
static func _reveal(a: Ability, spec: Dictionary) -> void:
	var radius := float(spec.get("radius", REVEAL_RADIUS))
	for n in a.actor.get_tree().get_nodes_in_group("hidden"):
		if n.has_method("reveal") and n.global_position.distance_to(a.actor.global_position) <= radius:
			n.reveal()
			_deed(a, Deeds.HIDDEN_FOUND)
	var spots: Array = []
	for i in 12:
		spots.append(a.actor.global_position + Vector2.from_angle(TAU * float(i) / 12.0) * radius * 0.6)
	Vfx.puffs(a.actor, Art.texture("spit_glob"), spots, Color(1.0, 0.95, 0.6, 0.8), 0.4)

## A one-way plank at the caster's feet, `length` long, starting just ahead of it, the way it faces (Span). A second cast replaces it.
static func _bridge(a: Ability, spec: Dictionary) -> void:
	for old in a.actor.get_tree().get_nodes_in_group("verb_bridges"):
		if old.caster == a.actor:
			old.free()
	var length := float(spec.get("length", BRIDGE_LENGTH))
	var way := 1.0 if float(a.aim_dir().x) >= 0.0 else -1.0
	var from: Vector2 = a.actor.global_position
	var bridge := VerbBridge.new()
	a.actor.get_parent().add_child(bridge)
	bridge.launch(a.actor, Vector2(from.x + way * (BRIDGE_REACH + length / 2.0), from.y + BodyConfig.BOTTOM), length, float(spec.get("seconds", BRIDGE_SECONDS)))

## The skill's damage to each target, then the spec's status. `ignore_def` skips an Enemy's DEF.
static func _strike(a: Ability, targets: Array, spec: Dictionary, ignore_def := false, counts := true) -> void:
	var power := a.power()
	for t in targets:
		_hit(t, power, spec, a.actor.global_position, ignore_def, a.actor)
	if counts and a.skill_id != "":  # a strike that found something is a hit, one that found nothing is a miss
		_deed(a, Deeds.SKILL_HIT if not targets.is_empty() else Deeds.SKILL_MISSED, {"id": a.skill_id})

## A deed the caster did, if the caster is the player (an enemy casting the same verb earns nothing).
static func _deed(a: Ability, event_name: String, tags := {}) -> void:
	if a.actor.has_method("emit_deed"):
		a.actor.emit_deed(event_name, tags)

static func _hit(t, power: int, spec: Dictionary, from: Vector2, ignore_def := false, caster = null) -> void:
	var type := str(spec.get("damage_type", "physical"))
	var before := _hp(t)
	if ignore_def and t is Enemy:
		t.receive_hit(power, type, from, "", true)
	else:
		t.receive_hit(power, type, from, "")
	_apply_status(t, spec.get("status", {}))
	var drain := float(spec.get("drain", 0.0))
	if drain > 0.0 and caster != null and is_instance_valid(caster):
		var dealt := power if before < 0 else maxi(0, before - _hp(t))  # what the target actually lost; a target with no HP of its own takes the power
		var health = caster.get("health")
		if health != null and dealt > 0:
			health.heal(maxi(1, int(float(dealt) * drain)))  # the caster takes back some of what it dealt

## The target's HP, -1 for one that has none (a switch, a stub).
static func _hp(t) -> int:
	var health = t.get("health")
	return health.hp if health != null else -1

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
	keys["deed"] = "deed"  # any verb may say a deed (Deeds) when the player casts it
	if kind in TYPED:
		keys["damage_type"] = "text"
	if kind in STRIKES:
		keys["status"] = "status"
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

static func _is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

static func _fits(v, what: String) -> bool:
	match what:
		"number":
			return _is_number(v)
		"bool":
			return typeof(v) == TYPE_BOOL
		"text", "deed":
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
		"deed":
			return "deed must be a deed name"
		"text":
			return "%s must be a damage type name" % key
		"stats":
			return "stats must be a dictionary of stat id to number"
		"status":
			return "status must be slow, stun or root seconds"
	return "%s must be a number" % key
