class_name Rage
extends RefCounted
## The window a verb opens on the player: a timed bonus (or a meter that kills stoke) with the price each one has. Spec keys, all optional:
##   seconds, stats                  the window and what it adds while it lasts
##   kill_refill, max_seconds        each kill adds seconds, up to a cap
##   meter {start, per_kill, decay, hold}   instead of seconds: 0 to 100, scaled bonus, and at 100 it cannot be stopped (the player is driven on)
##   crash {stats, seconds}          what follows the window
##   dry_lock                        a window that ended with no kill locks its verb this long
##   forbids [kinds, "items"]        what the player cannot do meanwhile
##   resist {damage type: percent}, no_flinch, bleed (seconds a blow bleeds)
##   kill_resets ["zip", "pounce"]   cooldowns a kill clears
##   unseen_in_dark                  hides the player in a dark room
##   alone {stats, isolated}         a bonus only with no packmate, and a multiplier on prey with no company
##   lasting {stat: amount}          paid when it ends, kept for the life (a curse)
##   swell {stat, per_kill, max}     each kill adds to a lasting stat, and to the body's size
##   blow {mult, knockback}          the pounce hits harder and shoves what it hits
##   toggle, beat, lock_blow         a stance: no clock, cast again to drop it; a beat of stillness to take it; no pounce while it is up

const SOURCE := "verb_rage"
const CRASH_SOURCE := "verb_rage_crash"
const ISOLATED_RANGE := 120.0
const FULL := 100.0
const HOLD_SECONDS := 4.0
const SWELL_SIZE := 0.05

var left := 0.0
var meter := 0.0
var skill_id := ""
var spec := {}
var _owner
var _fed := false
var _swelled := 0
var _hold := 0.0
var _crash_left := 0.0
var _mods: Array = []

func start(owner, p_spec: Dictionary, p_skill_id: String) -> void:
	_owner = owner
	spec = p_spec
	skill_id = p_skill_id
	_fed = false
	_hold = 0.0
	if _is_meter():
		meter = float(spec["meter"].get("start", 25.0))
		left = 0.0
	else:
		meter = 0.0
		left = 1.0e9 if bool(spec.get("toggle", false)) else float(spec.get("seconds", 5.0))
	_apply()

## Ends it now, paying what it ends with.
func stop() -> void:
	if not active():
		return
	left = 0.0
	meter = 0.0
	_end()

func blow_mult() -> float:
	return float(spec.get("blow", {}).get("mult", 1.0)) if active() else 1.0

func blow_knockback() -> float:
	return float(spec.get("blow", {}).get("knockback", 0.0)) if active() else 0.0

func locks_blow() -> bool:
	return active() and bool(spec.get("lock_blow", false))

func _is_meter() -> bool:
	return spec.has("meter")

func active() -> bool:
	return left > 0.0 or (_is_meter() and meter > 0.0)

## Forgets everything: a new life.
func reset() -> void:
	left = 0.0
	meter = 0.0
	_swelled = 0
	_crash_left = 0.0
	_hold = 0.0
	spec = {}
	_set_mods([], SOURCE)
	_set_mods([], CRASH_SOURCE)

func update(delta: float) -> void:
	if _crash_left > 0.0:
		_crash_left -= delta
		if _crash_left <= 0.0:
			_set_mods([], CRASH_SOURCE)
	if not active():
		return
	if _is_meter():
		var m: Dictionary = spec["meter"]
		if meter >= FULL:
			_hold += delta
			if _hold >= float(m.get("hold", HOLD_SECONDS)):
				meter = FULL - 0.01  # it ran its course at full: now it can drain
				_hold = 0.0
		else:
			meter = maxf(0.0, meter - float(m.get("decay", 6.0)) * delta)
	else:
		left -= delta
	if active():
		_apply()
	else:
		_end()

func on_kill(enemy) -> void:
	if not active():
		return
	_fed = true
	if _is_meter():
		meter = minf(FULL, meter + float(spec["meter"].get("per_kill", 25.0)))
	elif spec.has("kill_refill"):
		left = minf(float(spec.get("max_seconds", float(spec.get("seconds", 5.0)) * 2.0)), left + float(spec["kill_refill"]))
	if spec.has("swell"):
		var s: Dictionary = spec["swell"]
		if _swelled < int(s.get("max", 5)):
			_swelled += 1
			_owner.lasting_bonus(str(s.get("stat", "atk")), int(s.get("per_kill", 1)))
	for id in spec.get("kill_resets", []):
		_owner.reset_cooldown(str(id))
	_apply()

## A blow the player landed: it bleeds when the window says.
func on_hit(enemy) -> void:
	if active() and spec.has("bleed") and enemy is Enemy:
		enemy.bleed_for(float(spec["bleed"]))

func _end() -> void:
	_set_mods([], SOURCE)
	if spec.has("crash"):
		_crash_left = float(spec["crash"].get("seconds", 3.0))
		_set_mods(_mods_of(spec["crash"].get("stats", {}), 1.0), CRASH_SOURCE)
	for stat in spec.get("lasting", {}):
		_owner.lasting_bonus(str(stat), int(spec["lasting"][stat]))
	if not _fed and spec.has("dry_lock"):
		_owner.lock_verb(skill_id, float(spec["dry_lock"]))

func _apply() -> void:
	var scale := meter / FULL if _is_meter() else 1.0
	var mods := _mods_of(spec.get("stats", {}), scale)
	if spec.has("alone") and _owner.companions.is_empty():
		mods.append_array(_mods_of(spec["alone"].get("stats", {}), 1.0))
	_set_mods(mods, SOURCE)

func _mods_of(stats: Dictionary, scale: float) -> Array:
	var out: Array = []
	for stat in stats:
		var v := int(roundf(float(stats[stat]) * scale))
		if v != 0:
			out.append({"stat": stat, "op": "add", "value": v})
	return out

func _set_mods(mods: Array, source: String) -> void:
	if _owner == null:
		return
	if source == SOURCE:
		if mods == _mods:
			return
		_mods = mods
	_owner.stats.set_timed_modifiers(source, mods)
	_owner.refresh_stats()

func forbids(kind: String) -> bool:
	return active() and (spec.get("forbids", []) as Array).has(kind)

func percent_off(damage_type: String) -> int:
	if not active():
		return 0
	var r: Dictionary = spec.get("resist", {})
	return int(r.get(damage_type, r.get("*", 0)))

func no_flinch() -> bool:
	return active() and bool(spec.get("no_flinch", false))

func unseen() -> bool:
	return active() and bool(spec.get("unseen_in_dark", false)) and bool(_owner.in_dark)

## At full the player cannot stop: it runs on the way it faces.
func drives() -> bool:
	return active() and _is_meter() and meter >= FULL

## A multiplier on a blow at `enemy`: a lone hunter hits prey with no company harder.
func power_mult_vs(enemy) -> float:
	if not active() or not spec.has("alone") or not _owner.companions.is_empty():
		return 1.0
	for n in _owner.get_tree().get_nodes_in_group("actors"):
		if n is Enemy and n != enemy and n.global_position.distance_to(enemy.global_position) < ISOLATED_RANGE:
			return 1.0
	return float(spec["alone"].get("isolated", 1.0))

func swell_size() -> float:
	return 1.0 + SWELL_SIZE * float(_swelled)
