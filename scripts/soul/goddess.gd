class_name Goddess
extends RefCounted
## What the goddess's scene needs, bundled: the soul, the rules, her lines, the species catalog, the perks and the Compendium.
## It builds the scene's model for a death and her line for what killed you. Run and Game hold one.

var soul: SoulProgress
## PerkDefs, applied to the body at the start of a life (SoulPerks).
var perks: Array

var _rules: SoulRules
var _lines: GoddessLines
var _catalog: Dictionary  # species id -> SpeciesDef
var _compendium: CompendiumModel
var _skill_defs: Array

func _init(p_soul: SoulProgress, p_rules: SoulRules, p_lines: GoddessLines, p_catalog: Dictionary, p_perks: Array,
		p_compendium: CompendiumModel, p_skill_defs: Array) -> void:
	soul = p_soul
	_rules = p_rules
	_lines = p_lines
	_catalog = p_catalog
	perks = p_perks
	_compendium = p_compendium
	_skill_defs = p_skill_defs

## The shipped data: rules, lines, every species and perk.
static func load_default(p_soul: SoulProgress, p_compendium: CompendiumModel, p_skill_defs: Array) -> Goddess:
	return Goddess.new(p_soul, load("res://data/soul/soul_rules.tres"), load("res://data/goddess/lines.tres"),
		SpeciesCatalog.load_all(), DefLoader.load_dir("res://data/perks", "PerkDef"), p_compendium, p_skill_defs)

## Counts this death, then her line for `cause` (a creature id, "spear", or a damage type). Call once per death.
func line_for_death(cause: String) -> String:
	soul.note_death()
	return _lines.line_for(cause, soul.deaths, _rules.many_deaths)

## The scene's state: the attuned places (the default when none), the species the Bestiary has unlocked, the powers worth a head
## start, and the last choice pre-selected.
func model(progress: WorldProgress, altars: Array) -> GoddessModel:
	var places: Array = []
	for p in altars:
		if progress.is_attuned(str(p["id"])):
			places.append({"id": str(p["id"]), "name": str(p["name"])})
	if places.is_empty():
		places.append({"id": WorldProgress.DEFAULT_ALTAR, "name": "Cave mouth"})
	var records := {}
	for id in _compendium.bestiary_ids():
		records[id] = _compendium.creature_record(id)
	var species: Array = []
	for d: SpeciesDef in SpeciesCatalog.unlocked(_catalog, records):
		species.append({"id": d.id, "name": d.display_name})
	var powers: Array = []
	for id in HeadStart.eligible_powers(_compendium, _skill_defs):
		powers.append({"id": id, "name": _compendium.skill_name(id)})
	return GoddessModel.new(places, species, powers, soul, _rules, progress.last_choice())
