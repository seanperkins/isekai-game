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

const MAX_ITERATIONS := 64
const APPRAISAL_ID := "appraisal"

var run_active := false
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
	_ledger.clear()
	_owned.clear()
	_unlock_log.clear()
	_queue.clear()

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
			_grant(d, true)
		return
	_check_level(d)

## Level = 1 + (levels_on events since unlock) / level_curve, capped at max_level.
func _check_level(d: SkillDef) -> void:
	if d.levels_on.is_empty() or d.level_curve <= 0:
		return
	var entry: Dictionary = _owned[d.id]
	var gained: int = _ledger.counter(d.levels_on["event"], d.levels_on.get("tags", {})) - int(entry["base"])
	var target: int = mini(d.max_level, 1 + int(floor(float(gained) / d.level_curve)))
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
