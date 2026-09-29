class_name SkillRulesEngine
extends Node
## Owns per-run skill state: counters, owned skills and levels, and rule evaluation.
## Every incoming event goes through one FIFO work queue. Unlocks and level-ups append
## internal events to the same queue, so parents are always processed before children
## and nothing recurses. Events that arrive while draining are queued (re-entrancy guard).

signal skill_unlocked(id: String)
signal skill_leveled(id: String, level: int)
signal run_started
signal inspect_processed(tags: Dictionary, appraisal_level: int)
## An evolution's conditions are met; it unlocks only when the player spends EP (evolve()).
signal evolution_ready(id: String)
## recheck_levels() finished; `levels_gained` counts the levels it added across all skills.
signal rechecked(levels_gained: int)
## A skill that was granted (a rebirth kit) has now met its unlock conditions: the player understands it.
signal skill_discovered(id: String)

const MAX_ITERATIONS := 64
const APPRAISAL_ID := "appraisal"
## The highest level a skill may reach at the body's first stage; the body raises it on evolving.
const BASE_STAGE_CAP := 5

var run_active := false
## Levels are capped by the body's stage (5, 8, 12, 15). A skill above the cap stops levelling but its
## counters keep counting, so evolving (recheck_levels) can level it straight to the new cap.
var stage_cap := BASE_STAGE_CAP
## True while recheck_levels() runs, so the announcer can say one line instead of one per level.
var rechecking := false
var report_error: Callable = func(msg: String) -> void: push_error(msg)
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _defs := {}        # id -> SkillDef (enemy_only excluded)
var _listeners := {}   # event name -> Array[SkillDef]
var _ledger := Ledger.new()
var _owned := {}       # id -> {"level": int, "base": int}
var _unlock_log: Array = []
var _queue: Array = []
var _draining := false
var _run_start := 0.0
var _ready_evolutions := {}
var _granted := {}     # id -> true: granted without its unlock, until its conditions are met

func setup(defs: Array) -> void:
	_defs.clear()
	_listeners.clear()
	for d in defs:
		if d.source == "enemy_only":
			continue
		_defs[d.id] = d
		for ev in d.listens_to():
			if not _listeners.has(ev):
				_listeners[ev] = []
			_listeners[ev].append(d)

func start_run() -> void:
	reset_run()
	_run_start = clock.call()
	for d in _defs.values():
		if d.starting:
			_grant(d, false)
	run_active = true
	run_started.emit()

func reset_run() -> void:
	run_active = false
	stage_cap = BASE_STAGE_CAP
	rechecking = false
	_ledger.clear()
	_owned.clear()
	_unlock_log.clear()
	_queue.clear()
	_ready_evolutions.clear()
	_granted.clear()

func handle_event(event_name: String, tags: Dictionary = {}) -> void:
	if not run_active:
		return
	_queue.append([event_name, tags])
	if _draining:
		return
	_drain()

func owned() -> Array:
	return _owned.keys()

func level_of(id: String) -> int:
	return int(_owned[id]["level"]) if _owned.has(id) else 0

func unlock_log() -> Array:
	return _unlock_log.duplicate(true)

func get_def(id: String) -> SkillDef:
	return _defs.get(id)

func is_evolution_ready(id: String) -> bool:
	return _ready_evolutions.has(id)

func ready_evolutions() -> Array:
	return _ready_evolutions.keys()

## EP cost to evolve: one per parent skill (Water Blade 1, Swing Thread and Jet Dash 2).
func evolution_cost(id: String) -> int:
	var d: SkillDef = _defs.get(id)
	return maxi(1, d.parent_ids().size()) if d != null else 0

## Unlocks a ready evolution. The caller has already paid its EP.
func evolve(id: String) -> bool:
	if not run_active or not _ready_evolutions.has(id) or _owned.has(id):
		return false
	_ready_evolutions.erase(id)
	_grant(_defs[id], true)
	if not _draining:
		_drain()
	return true

## Progress of an owned skill toward its next level: {current, target}; zeros at max level.
func level_progress(id: String) -> Dictionary:
	var none := {"current": 0, "target": 0}
	if not _owned.has(id):
		return none
	var d: SkillDef = _defs[id]
	var level := level_of(id)
	if d.levels_on.is_empty() or d.level_curve <= 0 or level >= d.max_level:
		return none
	var gained: int = _ledger.counter(d.levels_on["event"], d.levels_on.get("tags", {})) - int(_owned[id]["base"])
	return {"current": clampi(gained - (level - 1) * d.level_curve, 0, d.level_curve), "target": d.level_curve}

## Gives an owned skill without its unlock: a body grants its skills on arrival (announced), a rebirth
## kit grants its skills quietly (`announce` false: no skill_unlocked, so the caller reveals and slots
## them, and the skill is discovered later, when its unlock conditions are met). A no-op if the skill is
## unknown, enemy-only, or already owned.
func grant(id: String, announce := true) -> bool:
	if not run_active or not _defs.has(id) or _owned.has(id):
		return false
	_ready_evolutions.erase(id)
	_grant(_defs[id], announce)
	if not announce:
		_granted[id] = true
	if not _draining:
		_drain()
	return true

func is_granted(id: String) -> bool:
	return _granted.has(id)

func set_stage_cap(n: int) -> void:
	stage_cap = maxi(1, n)

## An owned, levelling skill sitting at the stage cap with room left below its own max.
func is_capped(id: String) -> bool:
	var d: SkillDef = _defs.get(id)
	return d != null and _owned.has(id) and not d.levels_on.is_empty() and level_of(id) >= stage_cap and level_of(id) < d.max_level

## After the cap rises: level every owned skill straight to what its counters earned, one skill at a time,
## each with its own drain, so a burst of level-ups can never pass the 64-item queue limit.
func recheck_levels() -> void:
	rechecking = true
	var gained := 0
	for id in _owned.keys():
		var d: SkillDef = _defs.get(id)
		if d == null or d.levels_on.is_empty():
			continue
		var before := level_of(id)
		_check_level(d)
		if not _draining:
			_drain()
		gained += level_of(id) - before
	rechecking = false
	rechecked.emit(gained)

## Events of this run matching `tags` (superset match), e.g. essence totals for the status screen.
func count(event_name: String, tags: Dictionary = {}) -> int:
	return _ledger.counter(event_name, tags)

## Progress of a locked skill toward unlock, for the Appraisal bands. Never shown as numbers.
func progress(id: String) -> Dictionary:
	var d: SkillDef = _defs.get(id)
	var best := {"current": 0, "target": 0}
	if d == null or d.unlock.is_empty():
		return best
	var best_ratio := INF
	for c in d.unlock:
		var target := int(c["n"])
		var current := mini(_current(c), target)
		var ratio := float(current) / target
		if ratio < best_ratio:
			best_ratio = ratio
			best = {"current": current, "target": target}
	return best

func _drain() -> void:
	_draining = true
	var iterations := 0
	var inspects: Array = []
	while not _queue.is_empty():
		iterations += 1
		if iterations > MAX_ITERATIONS:
			report_error.call("SkillRules: work queue exceeded %d iterations; dropped %d queued events" % [MAX_ITERATIONS, _queue.size()])
			_queue.clear()
			break
		var item: Array = _queue.pop_front()
		var ev: String = item[0]
		var tags: Dictionary = item[1]
		if not Events.INTERNAL.has(ev):
			_ledger.record(ev, tags)
		for d in _listeners.get(ev, []):
			_evaluate(d)
		if ev == Events.INSPECTED:
			inspects.append(tags)
	_draining = false
	for t in inspects:
		inspect_processed.emit(t, level_of(APPRAISAL_ID))

func _evaluate(d: SkillDef) -> void:
	if not _owned.has(d.id):
		if not d.starting and _conditions_met(d):
			if d.source == "evolution":
				if not _ready_evolutions.has(d.id):
					_ready_evolutions[d.id] = true
					evolution_ready.emit(d.id)
			else:
				_grant(d, true)
		return
	if _granted.has(d.id) and not d.unlock.is_empty() and _conditions_met(d):
		_granted.erase(d.id)
		skill_discovered.emit(d.id)
	_check_level(d)

## Level = 1 + (levels_on events since unlock) / level_curve, capped at max_level.
func _check_level(d: SkillDef) -> void:
	if d.levels_on.is_empty() or d.level_curve <= 0:
		return
	var entry: Dictionary = _owned[d.id]
	var gained: int = _ledger.counter(d.levels_on["event"], d.levels_on.get("tags", {})) - int(entry["base"])
	var target: int = mini(mini(d.max_level, stage_cap), 1 + int(floor(float(gained) / d.level_curve)))
	while int(entry["level"]) < target:
		entry["level"] = int(entry["level"]) + 1
		_queue.append([Events.SKILL_LEVELED, {"id": d.id, "level": entry["level"]}])
		skill_leveled.emit(d.id, entry["level"])

func _grant(d: SkillDef, announce: bool) -> void:
	var base := 0
	if not d.levels_on.is_empty():
		base = _ledger.counter(d.levels_on["event"], d.levels_on.get("tags", {}))
	_owned[d.id] = {"level": 1, "base": base}
	if announce:
		_unlock_log.append({"id": d.id, "run_time_s": clock.call() - _run_start})
		# Queue before emitting, so a child of this skill is processed before anything
		# a signal handler emits in response (parent-before-child under re-entrancy).
		_queue.append([Events.SKILL_UNLOCKED, {"id": d.id}])
		skill_unlocked.emit(d.id)

func _conditions_met(d: SkillDef) -> bool:
	for c in d.unlock:
		if _current(c) < int(c["n"]):
			return false
	return true

func _current(c: Dictionary) -> int:
	match c.get("kind", ""):
		"counter":
			return _ledger.counter(c["event"], c.get("tags", {}))
		"reset_counter":
			return _ledger.reset_counter(c["event"], c.get("tags", {}), c["reset_on"])
		"skill_level":
			return level_of(c["id"])
	return 0
