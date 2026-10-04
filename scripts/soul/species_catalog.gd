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
