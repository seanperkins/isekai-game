class_name CompendiumModel
extends RefCounted
## Persistent skill knowledge. One slot per non-enemy_only skill; slot states only rise.
## Exact unlock conditions are shown only on owned-once slots (the UI's job).

signal slot_changed(id: String, state: int)

enum State { UNKNOWN, NAMED, HINTED, OWNED_ONCE }
const STATE_NAMES := ["unknown", "named", "hinted", "owned-once"]
const BAND_STIRS := "stirs"
const BAND_CLOSE := "close"

var store: CompendiumStore
var _defs := {}       # id -> SkillDef (enemy_only excluded)
var _creatures := {}  # id -> CreatureDef
var _states := {}     # id -> State

func _init(skill_defs: Array, creature_defs: Array, p_store: CompendiumStore = null) -> void:
	for d in skill_defs:
		if d.source != "enemy_only":
			_defs[d.id] = d
			_states[d.id] = State.UNKNOWN
	for c in creature_defs:
		_creatures[c.id] = c
	store = p_store
	if store != null:
		var saved: Dictionary = store.load_states(STATE_NAMES)
		for id in saved:
			if _states.has(id):
				_states[id] = maxi(_states[id], int(saved[id]))

func state(id: String) -> int:
	return _states.get(id, State.UNKNOWN)

func states() -> Dictionary:
	return _states.duplicate()

func raise(id: String, new_state: int) -> bool:
	if not _states.has(id) or _states[id] >= new_state:
		return false
	_states[id] = new_state
	slot_changed.emit(id, new_state)
	if store != null:
		store.save_states(_states, STATE_NAMES)
	return true

func on_skill_unlocked(id: String) -> void:
	raise(id, State.OWNED_ONCE)

func on_run_started(rules) -> void:
	for id in rules.owned():
		var d: SkillDef = _defs.get(id)
		if d != null and d.starting:
			raise(id, State.OWNED_ONCE)

func on_inspect_processed(tags: Dictionary, appraisal_level: int, rules) -> void:
	if not tags.get("appraisal_target", false):
		return
	var target: String = tags.get("target", "")
	if target == "self":
		self_report(appraisal_level, rules, true)
	else:
		creature_report(target, appraisal_level, true)

## Status-screen hints. Lv2: locked, non-secret proficiency/essence skills at >= half,
## as bands. Lv3: plus hints. Lv4: evolutions whose parents are all owned.
func self_report(level: int, rules, apply: bool = false) -> Dictionary:
	var hints: Array = []
	var evolutions: Array = []
	for id in _sorted_ids():
		var d: SkillDef = _defs[id]
		if rules.level_of(id) > 0:
			continue
		if level >= 2 and not d.secret and (d.source == "proficiency" or d.source == "essence"):
			var p: Dictionary = rules.progress(id)
			var cur: int = p["current"]
			var target: int = p["target"]
			if target > 0 and cur * 2 >= target:  # current >= ceil(target / 2)
				var entry := {"id": id, "name": d.display_name,
					"band": BAND_CLOSE if cur * 5 >= target * 4 else BAND_STIRS}
				if level >= 3:
					entry["hint"] = d.hint
				hints.append(entry)
				if apply:
					raise(id, State.HINTED if level >= 3 else State.NAMED)
		if level >= 4 and d.source == "evolution":
			var parents: Array = d.parent_ids()
			var all_owned := not parents.is_empty()
			for pid in parents:
				if rules.level_of(pid) == 0:
					all_owned = false
			if all_owned:
				evolutions.append({"id": id, "name": d.display_name})
				if apply:
					raise(id, State.NAMED)
	return {"hints": hints, "evolutions": evolutions}

## Creature inspect info. Lv1 name+HP; Lv2 stats, essences, eat bonus; Lv3 skill list.
## `apply` names Compendium slots (callers pass it only for appraisal targets).
func creature_report(source: String, level: int, apply: bool = false) -> Dictionary:
	var c: CreatureDef = _creatures.get(source)
	if c == null or level < 1:
		return {}
	var r := {"id": c.id, "name": c.display_name, "hp": int(c.stats.get("max_hp", 0))}
	if level >= 2:
		r["stats"] = c.stats.duplicate()
		r["essences"] = c.essences.duplicate()
		r["eat_bonus"] = c.eat_bonus.duplicate()
		if apply:
			for id in _sorted_ids():
				var d: SkillDef = _defs[id]
				if d.source != "essence":
					continue
				for ess in d.essences_used():
					if c.essences.has(ess):
						raise(id, State.NAMED)
	if level >= 3:
		r["skills"] = c.skills.duplicate(true)
		if apply:
			for s in c.skills:
				var d: SkillDef = _defs.get(s.get("id", ""))
				if d != null and not d.secret:
					raise(d.id, State.NAMED)
	return r

func _sorted_ids() -> Array:
	var ids := _defs.keys()
	ids.sort()
	return ids
