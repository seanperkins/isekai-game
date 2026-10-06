class_name SpeciesCatalog
extends RefCounted
## Every species in the data, and the ones the player has unlocked.

const DIR := "res://data/species"

## id -> SpeciesDef.
static func load_all(dir := DIR) -> Dictionary:
	var out := {}
	for d in DefLoader.load_dir(dir, "SpeciesDef"):
		out[d.id] = d
	return out

static var _verbs := {}

## The form_verb skill a species starts a life with, "" for none or an unknown species (the data is read once).
static func verb_of(species: String) -> String:
	if _verbs.is_empty():
		for id in load_all():
			_verbs[id] = load_all()[id].verb
	return str(_verbs.get(species, ""))

## The unlocked species for the Bestiary `records`: the default kind first, then by id.
static func unlocked(catalog: Dictionary, records: Dictionary) -> Array:
	var out: Array = catalog.values().filter(func(d: SpeciesDef) -> bool: return SpeciesUnlocks.is_unlocked(d, records))
	out.sort_custom(func(a: SpeciesDef, b: SpeciesDef) -> bool:
		var a_default: bool = a.unlock.get("kind", "") == "default"
		var b_default: bool = b.unlock.get("kind", "") == "default"
		if a_default != b_default:
			return a_default
		return a.id < b.id)
	return out
