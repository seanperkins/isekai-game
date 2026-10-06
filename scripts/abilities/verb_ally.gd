class_name VerbAlly
extends Node2D
## A small ally a verb calls (Court, Sow, Sisters, Brood, Rise, an echo). It goes to the nearest foe of the caster's other team (floating, so a foe above or below is
## reached too) and strikes it, or stays by its caster when there is none, and goes when its time is up or its caster is gone. Group `verb_allies`, deliberately not
## `actors`: foes do not see it, so no ability can hit it. Unless it is `mortal`: then an awake enemy that touches it kills it.
##
## Options (launch's `opts`): mortal and hp, look (a creature id it wears), web (its blows slow), echo (it strikes with the caster's pounce), command (it goes for the
## caster's last target), carry (it brings loose parts to the caster).

const SPEED := 70.0
const FOLLOW_SPEED := 160.0
const FOLLOW_GAP := 24.0
const CHASE_RANGE := 200.0
const STRIKE_REACH := Vector2(14.0, 30.0)
const STRIKE_SECONDS := 0.8
const HURT_REACH := Vector2(12.0, 22.0)
const HURT_SECONDS := 1.0
const POUNCE_RANGE := 260.0
const WEB_SLOW := 2.0
const CARRY_RANGE := 220.0
const CARRY_DROP := 14.0
const RALLY_FASTER := 2.0
const FEAR_SPEED := 130.0
const FEAR_GAP := 120.0

var caster: Node2D
var hp := 0           # 0: it cannot be hurt
var _max_hp := 0
var mortal := false
var web := false
var echo := false
var command := false
var carry := false
var _power := 1
var _seconds := 0.0
var _elapsed := 0.0
var _strike_in := 0.0
var _hurt_in := 0.0
var _rally_t := 0.0
var _rally_power := 0
var _afraid_t := 0.0
var _carried: Node2D = null
var _errand: Node2D = null  # the part it is going for

func launch(p_caster: Node2D, at: Vector2, power: int, seconds: float, tint: Color, opts := {}) -> void:
	add_to_group("verb_allies")
	caster = p_caster
	global_position = at
	_power = power
	_seconds = seconds
	mortal = bool(opts.get("mortal", false))
	hp = int(opts.get("hp", 1)) if mortal else 0
	_max_hp = hp
	web = bool(opts.get("web", false))
	echo = bool(opts.get("echo", false))
	command = bool(opts.get("command", false))
	carry = bool(opts.get("carry", false))
	var s: Sprite2D
	var look := str(opts.get("look", ""))
	if look != "":
		s = Companion.make_look(_creature(look))
	else:
		s = Sprite2D.new()
		s.texture = Art.texture("slime_idle")
		s.scale = Vector2.ONE * 0.7
	s.modulate = tint if look == "" else s.modulate.lerp(tint, 0.25)
	add_child(s)

static var _defs := {}

static func _creature(id: String) -> CreatureDef:
	if _defs.is_empty():
		for c in DefLoader.load_dir("res://data/creatures"):
			_defs[c.id] = c
	return _defs.get(id, _defs.get(Enemy.PLACEHOLDER_LOOK))

## Rallied: for `seconds` it strikes faster and `power` harder (a horn).
func rally(seconds: float, power: int) -> void:
	_rally_t = maxf(_rally_t, seconds)
	_rally_power = power

## Mended (holy light): a mortal ally's hp comes back up to what it began with.
func mend(n: int) -> void:
	if mortal:
		hp = mini(hp + n, _max_hp)

## Afraid: it runs from its caster and does not fight (a fear stone's price).
func fear_for(seconds: float) -> void:
	_afraid_t = maxf(_afraid_t, seconds)

func is_afraid() -> bool:
	return _afraid_t > 0.0

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(caster) or _elapsed >= _seconds:
		_drop_carried()
		queue_free()
		return
	_strike_in = maxf(0.0, _strike_in - delta)
	_hurt_in = maxf(0.0, _hurt_in - delta)
	_rally_t = maxf(0.0, _rally_t - delta)
	_afraid_t = maxf(0.0, _afraid_t - delta)
	if mortal and _take_contact_hit():
		return
	if _afraid_t > 0.0:
		var away: Vector2 = global_position - caster.global_position
		if away.length() < FEAR_GAP:
			global_position += (away.normalized() if away.length() > 0.01 else Vector2.RIGHT) * FEAR_SPEED * delta
		return
	if (_carried != null or (_errand != null and is_instance_valid(_errand))) and _carry_step(delta):
		return  # an errand is finished before anything else
	var foe := _pick_foe()
	if foe == null:
		_idle(delta)
		return
	_fight(foe, delta)

func _fight(foe: Node2D, delta: float) -> void:
	var d: Vector2 = foe.global_position - global_position
	if absf(d.x) <= STRIKE_REACH.x and absf(d.y) <= STRIKE_REACH.y:
		if _strike_in <= 0.0:
			_strike(foe)
	else:
		global_position = global_position.move_toward(foe.global_position, SPEED * delta)

func _strike(foe: Node2D) -> void:
	foe.receive_hit(_power + (_rally_power if _rally_t > 0.0 else 0), "physical", global_position, "")
	if web and foe.has_method("slow_for"):
		foe.slow_for(WEB_SLOW)
	_strike_in = STRIKE_SECONDS / (RALLY_FASTER if _rally_t > 0.0 else 1.0)

## An echo of the caster's pounce: it goes at the nearest foe at once and strikes.
func pounce() -> void:
	var foe := _nearest_foe(POUNCE_RANGE)
	if foe == null:
		return
	global_position = foe.global_position + Vector2(-signf(foe.global_position.x - global_position.x) * 8.0, 0.0)
	_strike(foe)

func _idle(delta: float) -> void:
	if carry and _carry_step(delta):
		return
	if global_position.distance_to(caster.global_position) > FOLLOW_GAP:
		global_position = global_position.move_toward(caster.global_position, FOLLOW_SPEED * delta)

## Brings a part lying nearby to the caster. True while it is on an errand.
func _carry_step(delta: float) -> bool:
	if _carried != null and not is_instance_valid(_carried):
		_carried = null
	if _carried != null:
		global_position = global_position.move_toward(caster.global_position, FOLLOW_SPEED * delta)
		_carried.global_position = global_position
		if global_position.distance_to(caster.global_position) <= CARRY_DROP:
			_carried = null  # the pickup is at the caster's feet: it takes it
			_errand = null
		return true
	if _errand != null and not is_instance_valid(_errand):
		_errand = null
	if _errand == null:
		var best_d := CARRY_RANGE
		for n in get_tree().get_nodes_in_group("pickups"):
			var d: float = n.global_position.distance_to(global_position)
			if d < best_d and n.global_position.distance_to(caster.global_position) > CARRY_DROP:
				_errand = n
				best_d = d
	if _errand == null:
		return false
	if global_position.distance_to(_errand.global_position) <= CARRY_DROP:
		_carried = _errand
	else:
		global_position = global_position.move_toward(_errand.global_position, FOLLOW_SPEED * delta)
	return true

func _drop_carried() -> void:
	_carried = null

func _pick_foe() -> Node2D:
	if command and "last_target" in caster:
		var lead = caster.last_target
		if lead != null and is_instance_valid(lead) and lead.has_method("can_be_hit") and lead.can_be_hit() and lead.global_position.distance_to(global_position) <= CHASE_RANGE * 2.0:
			return lead
	return _nearest_foe(CHASE_RANGE)

func _nearest_foe(within: float) -> Node2D:
	var best: Node2D = null
	var best_d := within
	for n in get_tree().get_nodes_in_group("actors"):
		if n == caster or not n.has_method("receive_hit") or n.get("team") == caster.get("team"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		var d: float = n.global_position.distance_to(global_position)
		if d < best_d:
			best = n
			best_d = d
	return best

## An awake enemy in contact kills a mortal ally (or wears its `hp` down). True when it died.
func _take_contact_hit() -> bool:
	if _hurt_in > 0.0:
		return false
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Enemy) or n.dormant or n.is_rooted() or n.status.state != EnemyStatus.ACTIVE or n.is_turned():
			continue
		var d: Vector2 = n.global_position - global_position
		if absf(d.x) <= HURT_REACH.x and absf(d.y) <= HURT_REACH.y:
			hp -= int(n.def.stats.get("atk", 1))
			_hurt_in = HURT_SECONDS
			if hp <= 0:
				queue_free()
				remove_from_group("verb_allies")
				return true
			return false
	return false
