class_name DefValidator
extends RefCounted
## Startup validation for skill and creature data. Returns every problem found; empty = valid.

const SOURCES := ["proficiency", "essence", "evolution", "enemy_only"]
const EFFECT_KINDS := ["modifier", "conditional_modifier", "capability", "active"]
const DAMAGE_TAKEN := "damage_taken"

static func validate(skills: Array, creatures: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if skills.is_empty():
		errors.append("no skill defs found")
		return errors
	var by_id := {}
	for d in skills:
		if not (d is SkillDef):
			errors.append("%s: is not a SkillDef" % _where(d))
			continue
		if d.id == "":
			errors.append("%s: missing id" % _where(d))
			continue
		if by_id.has(d.id):
			errors.append("%s: duplicate skill id '%s'" % [_where(d), d.id])
		by_id[d.id] = d
	for d in by_id.values():
		_check_skill(d, by_id, errors)
	_check_cycles(by_id, errors)
	_check_creatures(creatures, by_id, errors)
	return errors

static func _where(res: Resource) -> String:
	if res.resource_path != "":
		return res.resource_path
	return "<%s>" % str(res.get("id"))

static func _check_skill(d: SkillDef, by_id: Dictionary, errors: PackedStringArray) -> void:
	var w := _where(d)
	if d.display_name == "":
		errors.append("%s: missing display_name" % w)
	if not SOURCES.has(d.source):
		errors.append("%s: unknown source '%s'" % [w, d.source])
	if d.max_level < 1:
		errors.append("%s: max_level must be at least 1" % w)
	if d.effects.is_empty():
		errors.append("%s: needs at least one effect" % w)
	if d.source == "enemy_only":
		if not d.unlock.is_empty():
			errors.append("%s: enemy_only skill must not have an unlock" % w)
		if d.max_level != 1:
			errors.append("%s: enemy_only skill must have max_level 1" % w)
	elif not d.starting and d.unlock.is_empty():
		errors.append("%s: needs at least one unlock condition" % w)
	if d.max_level > 1 and (d.levels_on.is_empty() or d.level_curve <= 0):
		errors.append("%s: max_level > 1 needs levels_on and a positive level_curve" % w)
	if not d.levels_on.is_empty():
		_check_event_ref(w, "levels_on", d.levels_on.get("event", ""), d.levels_on.get("tags", {}), errors)
	for c in d.unlock:
		var kind: String = c.get("kind", "")
		match kind:
			"counter", "reset_counter":
				_check_event_ref(w, "unlock", c.get("event", ""), c.get("tags", {}), errors)
				if int(c.get("n", 0)) <= 0:
					errors.append("%s: unlock n must be positive" % w)
				if kind == "reset_counter" and not Events.ALL.has(c.get("reset_on", "")):
					errors.append("%s: unknown reset_on event '%s'" % [w, c.get("reset_on", "")])
			"skill_level":
				var pid: String = c.get("id", "")
				if not by_id.has(pid):
					errors.append("%s: skill_level references unknown skill '%s'" % [w, pid])
				elif by_id[pid].source == "enemy_only":
					errors.append("%s: skill_level references enemy_only skill '%s'" % [w, pid])
			_:
				errors.append("%s: unknown condition kind '%s'" % [w, kind])
	for e in d.effects:
		_check_effect(w, d, e, errors)
	if d.source != "enemy_only" and SkillEffects.active_scene(d) != "" and d.mp_cost <= 0:
		errors.append("%s: player active skill needs a positive mp_cost" % w)

static func _check_event_ref(w: String, field: String, event: String, tags: Dictionary, errors: PackedStringArray) -> void:
	if not Events.ALL.has(event):
		errors.append("%s: %s uses unknown event '%s'" % [w, field, event])
		return
	if Events.INTERNAL.has(event):
		errors.append("%s: %s must not count internal event '%s'" % [w, field, event])
	if tags.has("source") and not Sources.ALL.has(tags["source"]):
		errors.append("%s: %s uses unknown source '%s'" % [w, field, tags["source"]])
	if tags.has("essence") and not Essences.ALL.has(tags["essence"]):
		errors.append("%s: %s uses unknown essence '%s'" % [w, field, tags["essence"]])

static func _check_effect(w: String, d: SkillDef, e: Dictionary, errors: PackedStringArray) -> void:
	var kind: String = e.get("kind", "")
	if not EFFECT_KINDS.has(kind):
		errors.append("%s: unknown effect kind '%s'" % [w, kind])
		return
	if e.has("values") and e["values"].size() != d.max_level:
		errors.append("%s: effect values has %d entries but max_level is %d" % [w, e["values"].size(), d.max_level])
	if kind == "modifier" or kind == "conditional_modifier":
		var stat: String = e.get("stat", "")
		if stat != DAMAGE_TAKEN and not StatKeys.ALL.has(stat):
			errors.append("%s: modifier target '%s' is not in StatKeys" % [w, stat])
	if kind == "active":
		var scene: String = e.get("scene", "")
		if scene == "" or not ResourceLoader.exists(scene):
			errors.append("%s: active scene '%s' does not exist" % [w, scene])

static func _check_cycles(by_id: Dictionary, errors: PackedStringArray) -> void:
	var state := {}  # id -> 1 visiting, 2 done
	for id in by_id:
		if _visit(id, by_id, state):
			errors.append("%s: skill_level dependency cycle through '%s'" % [_where(by_id[id]), id])
			return

static func _visit(id: String, by_id: Dictionary, state: Dictionary) -> bool:
	if state.get(id, 0) == 1:
		return true
	if state.get(id, 0) == 2 or not by_id.has(id):
		return false
	state[id] = 1
	for pid in by_id[id].parent_ids():
		if _visit(pid, by_id, state):
			return true
	state[id] = 2
	return false

static func _check_creatures(creatures: Array, by_id: Dictionary, errors: PackedStringArray) -> void:
	var seen := {}
	for c in creatures:
		var w := _where(c)
		if not (c is CreatureDef):
			errors.append("%s: is not a CreatureDef" % w)
			continue
		if not Sources.ALL.has(c.id):
			errors.append("%s: unknown source id '%s'" % [w, c.id])
			continue
		if seen.has(c.id):
			errors.append("%s: duplicate CreatureDef for '%s'" % [w, c.id])
		seen[c.id] = true
		for ess in c.essences:
			if not Essences.ALL.has(ess):
				errors.append("%s: unknown essence '%s'" % [w, ess])
		for s in c.skills:
			var sid: String = s.get("id", "")
			var lv := int(s.get("level", 1))
			if not by_id.has(sid):
				errors.append("%s: unknown skill id '%s'" % [w, sid])
			elif lv < 1 or lv > by_id[sid].max_level:
				errors.append("%s: skill '%s' level %d is outside 1..%d" % [w, sid, lv, by_id[sid].max_level])
		if not c.eat_bonus.is_empty() and not StatKeys.ALL.has(c.eat_bonus.get("stat", "")):
			errors.append("%s: eat_bonus stat '%s' is not in StatKeys" % [w, c.eat_bonus.get("stat", "")])
		if not c.appraisal_target and c.predatable:
			errors.append("%s: appraisal_target may be false only on non-predatable sources" % w)
	for sid in Sources.ALL:
		if not seen.has(sid):
			errors.append("missing CreatureDef for source '%s'" % sid)
