class_name RebirthKit
extends RefCounted
## A rebirth pool's head start: {"skills": [ids], "level": int}. Both keys are optional (the Cave mouth's
## kit is {}). validate() checks the data; apply() (below) gives it.

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
	return errs

## Gives the kit to a player at the start of a life, AFTER SkillRules.start_run() (which clears everything
## first). Skills are granted quietly, so the skill set is refreshed, actives are slotted and the Compendium
## raised to NAMED here; a starting level gives its bonuses but no EP.
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
	player.refresh_stats()
	player.fill_vitals()
