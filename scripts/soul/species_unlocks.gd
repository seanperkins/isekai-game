class_name SpeciesUnlocks
extends RefCounted
## Whether a species is unlocked, from the Bestiary: `records` is {creature_id: {"eaten", "defeated", ...}}.

static func is_unlocked(def: SpeciesDef, records: Dictionary) -> bool:
	var rule: Dictionary = def.unlock
	var record: Dictionary = records.get(rule.get("creature", ""), {})
	match rule.get("kind", ""):
		"default":
			return true
		"count":
			# The larger of the two, not the sum: a defeat raises `defeated` and eating that body raises `eaten`, so a sum
			# would count one creature twice.
			var n := int(rule.get("n", 0))
			return n > 0 and maxi(int(record.get("eaten", 0)), int(record.get("defeated", 0))) >= n
		"defeat":
			return int(record.get("defeated", 0)) >= 1
	return false
