class_name SoulValidator
extends RefCounted
## Checks the soul data: species and their unlock rules, perks, the rules numbers and the goddess's lines. An empty result
## means the data is safe to run. A test runs it over the shipped files.

const UNLOCK_KINDS := ["default", "count", "defeat"]
## Causes of death that are not a creature: the spear, and poison from a blob or a puff.
const EXTRA_CAUSES := ["poison", "spear"]

## `creature_ids` are the ids in data/creatures; `movement_dir` is where a species' movement profile must exist (read only).
static func validate(species: Array, perks: Array, rules: SoulRules, lines: GoddessLines, creature_ids: Array,
		movement_dir := "res://data/movement") -> PackedStringArray:
	var out := PackedStringArray()
	out.append_array(_species_errors(species, creature_ids, movement_dir))
	out.append_array(_perk_errors(perks))
	out.append_array(_rules_errors(rules))
	out.append_array(_line_errors(lines, creature_ids))
	return out

static func _species_errors(species: Array, creature_ids: Array, movement_dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var has_default := false
	for d: SpeciesDef in species:
		if seen.has(d.id):
			out.append("duplicate species id '%s'" % d.id)
		seen[d.id] = true
		var kind = d.unlock.get("kind", "")
		if not UNLOCK_KINDS.has(kind):
			out.append("species '%s': unknown unlock kind '%s'" % [d.id, str(kind)])
		elif kind == "default":
			has_default = true
		else:
			var creature = d.unlock.get("creature", "")
			if not creature_ids.has(creature):
				out.append("species '%s': unlock names unknown creature '%s'" % [d.id, str(creature)])
			if kind == "count" and int(d.unlock.get("n", 0)) <= 0:
				out.append("species '%s': a count unlock needs a positive n" % d.id)
		if d.movement_profile != "" and not FileAccess.file_exists(movement_dir.path_join(d.movement_profile + ".tres")):
			out.append("species '%s': movement profile '%s' has no file in %s" % [d.id, d.movement_profile, movement_dir])
	if not has_default:
		out.append("no species has the default unlock")
	return out

static func _perk_errors(perks: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for p: PerkDef in perks:
		if seen.has(p.id):
			out.append("duplicate perk id '%s'" % p.id)
		seen[p.id] = true
		if p.price_base <= 0:
			out.append("perk '%s': price_base must be above 0" % p.id)
		if p.price_step < 0:
			out.append("perk '%s': price_step must not be negative" % p.id)
		for effect in p.effects:
			if typeof(effect) != TYPE_DICTIONARY:
				out.append("perk '%s': effect is not a dictionary: %s" % [p.id, str(effect)])
				continue
			if not Stats.DEFAULTS.has(str(effect.get("stat", ""))):
				out.append("perk '%s': effect names unknown stat '%s'" % [p.id, str(effect.get("stat", ""))])
			if int(effect.get("amount", 0)) == 0:
				out.append("perk '%s': effect amount must not be 0" % p.id)
	return out

static func _rules_errors(rules: SoulRules) -> PackedStringArray:
	var out := PackedStringArray()
	if rules.bank_rate <= 0:
		out.append("rules: bank_rate must be above 0")
	if rules.level_prices.is_empty():
		out.append("rules: level_prices must not be empty")
	elif rules.level_prices.any(func(price) -> bool: return int(price) <= 0):
		out.append("rules: every level price must be above 0")
	if rules.power_price <= 0:
		out.append("rules: power_price must be above 0")
	if rules.many_deaths < 2:
		out.append("rules: many_deaths must be at least 2")
	return out

static func _line_errors(lines: GoddessLines, creature_ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var causes := creature_ids.filter(func(id: String) -> bool: return id != Sources.WATER_POOL)
	causes.append_array(EXTRA_CAUSES)
	for cause in lines.by_cause:
		if not causes.has(cause):
			out.append("lines: '%s' is not a cause (a creature id, 'poison' or 'spear')" % str(cause))
		var list = lines.by_cause[cause]
		if typeof(list) != TYPE_ARRAY or list.is_empty():
			out.append("lines: cause '%s' has no lines" % str(cause))
		elif _any_blank(list):
			out.append("lines: cause '%s' has a blank line" % str(cause))
	if lines.many_deaths.is_empty():
		out.append("lines: many_deaths has no lines")
	elif _any_blank(lines.many_deaths):
		out.append("lines: many_deaths has a blank line")
	if lines.fallback.strip_edges() == "":
		out.append("lines: fallback is blank")
	return out

static func _any_blank(list: Array) -> bool:
	return list.any(func(line) -> bool: return str(line).strip_edges() == "")
