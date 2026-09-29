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
}
const THREAD_SKILLS := ["sticky_thread", "swing_thread"]
const WATER_SKILLS := ["hydraulic_propulsion", "water_blade", "jet_dash"]
const VENOM_PERCENT := 30
const SHELL_FLAT := 1

## The `form` modifier list for a form: its stat changes as additive modifiers.
static func modifiers(def: FormDef) -> Array:
	var out: Array = []
	if def == null:
		return out
	for stat in def.stats:
		out.append({"stat": stat, "op": "add", "value": int(def.stats[stat])})
	return out

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
