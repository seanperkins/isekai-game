class_name FormEffects
extends RefCounted
## What a form changes about the player: stat modifiers (the "form" source), and trait flags, which
## are capabilities that skills and damage code look for.

const SOURCE := "form"
## trait id -> what it does
const TRAITS := {
	"spinner": "Thread skills cost 1 less MP.",
	"water_thrift": "Water skills cost 1 less MP.",
	"venom_blood": "Take 30% less poison damage.",
	"hard_shell": "Take 1 less damage from every hit.",
	"sonar": "Echolocation reads one level stronger.",
	"adaptable": "Eat and recover faster.",
	"ranged_proof": "Take 60% less damage from hits that come from afar.",
	"knockback_proof": "Blows do not shove you.",
	"hazard_proof": "Poison clouds and thrown spears do nothing to you.",
	"hoard_armour": "Take 1 less damage from every hit for each part you carry, up to 4.",
	"extra_grafts": "Wear two more grafts.",
	"stench": "Enemies close to you are slowed.",
	"no_bond": "You cannot bond or tame.",
	"light_frail": "Take half again as much from holy light.",
	"no_drain": "Your blows do not drain life.",
	"dark_weak": "Dark powers hit half as hard.",
	"needs_hands": "Items and tools can only be used with your hands up.",
	"miasma_death": "A poison cloud spreads where you die.",
	"fire_frail": "Take half again as much from fire.",
	"weak_alone": "Weaker with no packmate, companion or ally beside you.",
	"no_stand": "No stand-and-fight tools: you cannot guard, ward or set a trap.",
	"loud": "Loud steps: a veil lasts half as long.",
}
const THREAD_SKILLS := ["sticky_thread", "swing_thread", "binding_web"]
const WATER_SKILLS := ["hydraulic_propulsion", "water_blade", "jet_dash"]
const ADAPTABLE_HEAL := 2  # extra HP from every creature eaten
const VENOM_PERCENT := 30
const SHELL_FLAT := 1
const RANGED_PERCENT := 60
const HOARD_MAX := 4
const LIGHT_FRAIL := 1.5
const FIRE_FRAIL := 1.5
const WEAK_ALONE := -2
const NO_STAND_KINDS := ["ward", "stone", "trap"]
## The ring a transmute's aim picks an element from, going round from the right.
const ELEMENT_WHEEL := ["water", "earth", "air", "light", "dark", "fire", "mind", "blood"]
const STENCH_RANGE := 48.0
const STENCH_SLOW := 0.6
const EXTRA_GRAFTS := 2
## A hit from farther than this counts as a ranged one.
const RANGED_FROM := 64.0

## The `form` modifier list for a form: its stat changes as additive modifiers.
static func modifiers(def: FormDef) -> Array:
	var out: Array = []
	if def == null:
		return out
	for stat in def.stats:
		out.append({"stat": stat, "op": "add", "value": int(def.stats[stat])})
	return out

const STAT_LABEL := {"max_hp": "Max HP", "atk": "ATK", "def": "DEF", "spd": "SPD", "jump_height": "Jump height",
	"slide_speed": "Slide speed", "predation_time": "Eat time", "max_mp": "Max MP", "mp_regen": "MP regen"}

## Readable lines for a form's stat changes: "+5 Max HP", "-10 Eat time".
static func stat_lines(def: FormDef) -> Array:
	var out: Array = []
	for stat in def.stats:
		var v := int(def.stats[stat])
		out.append("%s%d %s" % ["+" if v >= 0 else "", v, STAT_LABEL.get(stat, stat)])
	return out

## What a form looks like: its own sheet's still (or idle frame), or the base sheet's idle frame with the form's tint (also when
## the still it names is not in the sheet).
## With no base sheet at all the texture is null (callers draw nothing rather than crash).
static func look(def: FormDef, base_sheet: SpriteSheet) -> Dictionary:
	if def.sprite_set != "" and SpriteSheet.available(def.sprite_set):
		var sheet := SpriteSheet.load_set(def.sprite_set)
		if def.sprite_frame == "":
			return {"texture": sheet.frame_texture("idle_1"), "tint": Color.WHITE}
		if sheet.has_frame(def.sprite_frame):
			return {"texture": sheet.frame_texture(def.sprite_frame), "tint": Color.WHITE}
	return {"texture": base_sheet.frame_texture("idle_1") if base_sheet != null else null, "tint": def.tint}

## Extra HP from eating, from traits (adaptable).
static func eat_heal(capabilities: Dictionary) -> int:
	return ADAPTABLE_HEAL if capabilities.has("trait_adaptable") else 0

## The trait flags a form turns on.
static func flags(def: FormDef) -> Dictionary:
	var out := {}
	if def != null:
		for t in def.traits:
			out["trait_" + str(t)] = 1
	return out

## An MP cost after traits: thread skills (spinner) and water skills (water_thrift) cost 1 less, never below 1.
static func mp_cost(capabilities: Dictionary, skill_id: String, base_cost: int) -> int:
	if base_cost <= 1:
		return base_cost
	if capabilities.has("trait_spinner") and THREAD_SKILLS.has(skill_id):
		return base_cost - 1
	if capabilities.has("trait_water_thrift") and WATER_SKILLS.has(skill_id):
		return base_cost - 1
	return base_cost
