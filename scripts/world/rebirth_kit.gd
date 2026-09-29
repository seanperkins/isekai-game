class_name RebirthKit
extends RefCounted
## A rebirth pool's head start: {"skills": [ids], "level": int, "affinity": {essence: units}}. All keys
## are optional (the Cave mouth's kit is {}). validate() checks the data; apply() (below) gives it.

## Essences a kit may seed (the forms' lineages read these).
const ESSENCES := ["sound", "flight", "poison", "water", "armor", "earth", "thread", "spore", "shell"]

static var _skill_defs: Array = []

static func skill_defs() -> Array:
	if _skill_defs.is_empty():
		_skill_defs = DefLoader.load_dir("res://data/skills")
	return _skill_defs

static func validate(kit: Dictionary, defs: Array = []) -> PackedStringArray:
	var errs := PackedStringArray()
	var all := defs if not defs.is_empty() else skill_defs()
	var by_id := {}
	for d in all:
		by_id[d.id] = d
	var skill_ids = kit.get("skills", [])
	if typeof(skill_ids) != TYPE_ARRAY:
		errs.append("kit skills must be a list")
		skill_ids = []
	for s in skill_ids:
		if typeof(s) != TYPE_STRING or not by_id.has(s):
			errs.append("kit names unknown skill '%s'" % str(s))
		elif (by_id[s] as SkillDef).source == "enemy_only":
			errs.append("kit names enemy-only skill '%s'" % s)
		elif (by_id[s] as SkillDef).source == "evolution":
			errs.append("kit names evolution '%s' (only evolve() takes one)" % s)
	if kit.has("level"):
		var lv := int(kit["level"])
		if lv < 1 or lv > Progression.LEVEL_CAP:
			errs.append("kit level %d is outside 1..%d" % [lv, Progression.LEVEL_CAP])
	var seeds = kit.get("affinity", {})
	if typeof(seeds) != TYPE_DICTIONARY:
		errs.append("kit affinity must be a dictionary")
		seeds = {}
	for e in seeds:
		if not ESSENCES.has(e):
			errs.append("kit affinity names unknown essence '%s'" % str(e))
		elif int(seeds[e]) < 0:
			errs.append("kit affinity for '%s' has negative units" % e)
	return errs

## How many lineages a seeded affinity leaves eligible for the first evolution (the rule every pool but the
## default must meet: at least two).
static func eligible_lineages(seeds: Dictionary, p_supply: Dictionary, forms: Dictionary) -> int:
	var a := FormOffers.affinity(seeds, p_supply, forms)
	var n := 0
	for l in FormOffers.LINEAGE_ORDER:
		if float(a.get(l, 0.0)) >= FormOffers.ELIGIBLE:
			n += 1
	return n

## Gives the kit to a player at the start of a life, AFTER SkillRules.start_run() (which clears everything
## first). Skills are granted quietly, so the skill set is refreshed, actives are slotted and the Compendium
## raised to NAMED here; a starting level gives its bonuses but no EP; seeded affinity counts for the first
## evolution only.
static func apply(player: Player, rules: SkillRulesEngine, compendium: CompendiumModel, kit: Dictionary) -> void:
	var granted: Array = []
	for id in kit.get("skills", []):
		if rules.grant(id, false):
			granted.append(id)
			if compendium != null:
				compendium.raise(id, CompendiumModel.State.NAMED)
	player.skillset.refresh()
	for id in granted:
		var d: SkillDef = rules.get_def(id)
		if d != null and SkillEffects.active_scene(d) != "":
			player.skillset.slots.add(id)
	if kit.has("level"):
		player.start_at_level(int(kit["level"]))
	var seeds: Dictionary = kit.get("affinity", {})
	for e in seeds:
		player.progression.seeded[e] = int(player.progression.seeded.get(e, 0)) + int(seeds[e])
	player.refresh_stats()
	player.fill_vitals()
