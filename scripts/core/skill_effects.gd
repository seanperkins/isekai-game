class_name SkillEffects
extends RefCounted
## Effect math shared by the player's and enemies' skill sets. Pure functions over SkillDefs.

const DAMAGE_TAKEN := "damage_taken"
const KNOCKBACK_TAKEN := "knockback_taken"

static func value_at(effect: Dictionary, level: int):
	var values: Array = effect.get("values", [])
	if values.is_empty():
		return 0
	return values[clampi(level, 1, values.size()) - 1]

static func stat_modifiers(def: SkillDef, level: int) -> Array:
	var out: Array = []
	for e in def.effects:
		if e.get("kind", "") == "modifier" and StatKeys.ALL.has(e.get("stat", "")):
			out.append({"stat": e["stat"], "op": e.get("op", "add"), "value": int(value_at(e, level))})
	return out

static func capabilities(def: SkillDef, level: int) -> Dictionary:
	var out := {}
	for e in def.effects:
		if e.get("kind", "") == "capability" and level >= int(e.get("min_level", 1)):
			out[e["flag"]] = level
	return out

## Incoming-damage reductions from owned skills. pairs = [[SkillDef, level], ...].
static func damage_reduction(pairs: Array, damage_type: String, hp: int, max_hp: int) -> Dictionary:
	var percent := 0
	var flat := 0
	for pair in pairs:
		var d: SkillDef = pair[0]
		var level: int = pair[1]
		for e in d.effects:
			if e.get("stat", "") != DAMAGE_TAKEN:
				continue
			var kind: String = e.get("kind", "")
			if kind == "conditional_modifier":
				var cond: Dictionary = e.get("condition", {})
				if cond.has("hp_below_percent") and not (hp * 100 < max_hp * int(cond["hp_below_percent"])):
					continue
			elif kind != "modifier":
				continue
			var scope: Dictionary = e.get("scope", {})
			if scope.has("damage_type") and scope["damage_type"] != damage_type:
				continue
			var v := int(value_at(e, level))
			match e.get("op", ""):
				"percent_off":
					percent += v
				"flat_off":
					flat += v
	return {"percent_off": mini(percent, 100), "flat_off": flat}

static func active_scene(def: SkillDef) -> String:
	for e in def.effects:
		if e.get("kind", "") == "active":
			return e.get("scene", "")
	return ""

static func active_values(def: SkillDef) -> Array:
	for e in def.effects:
		if e.get("kind", "") == "active":
			return e.get("values", [])
	return []

## Scales the knockback a hit gives the player: 1.0 with no skill, down to 0.36. pairs = [[SkillDef, level], ...].
static func knockback_factor(pairs: Array) -> float:
	var sum := 0
	for pair in pairs:
		var d: SkillDef = pair[0]
		for e in d.effects:
			if e.get("stat", "") == KNOCKBACK_TAKEN and e.get("kind", "") == "modifier":
				sum += int(value_at(e, pair[1]))
	return maxf(0.36, 1.0 + float(sum) / 100.0)
