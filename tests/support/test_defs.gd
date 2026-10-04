class_name TestDefs
extends RefCounted
## Builders for SkillDef/CreatureDef fixtures. Defaults produce a valid def.

static func skill(id: String, fields: Dictionary = {}) -> SkillDef:
	var d := SkillDef.new()
	d.id = id
	d.display_name = id.capitalize()
	d.source = "proficiency"
	d.effects = [{"kind": "capability", "flag": id}]
	for key in fields:
		d.set(key, fields[key])
	return d

static func counter(event: String, n: int, tags: Dictionary = {}) -> Dictionary:
	return {"kind": "counter", "event": event, "tags": tags, "n": n}

static func reset_counter(event: String, n: int, reset_on: String, tags: Dictionary = {}) -> Dictionary:
	return {"kind": "reset_counter", "event": event, "tags": tags, "reset_on": reset_on, "n": n}

static func level(id: String, n: int) -> Dictionary:
	return {"kind": "skill_level", "id": id, "n": n}

static func creature(id: String, fields: Dictionary = {}) -> CreatureDef:
	var c := CreatureDef.new()
	c.id = id
	c.display_name = id.capitalize()
	c.stats = {"max_hp": 3, "atk": 1, "def": 0, "spd": 100}
	for key in fields:
		c.set(key, fields[key])
	return c

static func all_creatures() -> Array:
	var out: Array = []
	for sid in Sources.ALL:
		if sid == Sources.SERPENT:
			out.append(creature(sid, {"predatable": false, "appraisal_target": false}))
		else:
			out.append(creature(sid))
	return out

## Fires the events that satisfy `id`'s counter unlocks, so a test need not repeat a threshold the calibration may tune.
static func satisfy(rules: SkillRulesEngine, id: String) -> void:
	var d: SkillDef = rules.get_def(id)
	for c in d.unlock:
		if c.get("kind", "") == "counter":
			for i in int(c["n"]):
				rules.handle_event(c["event"], c.get("tags", {}).duplicate())
