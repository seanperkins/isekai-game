class_name PartLoader
extends RefCounted
## Loads the parts.

static func load_all(dir := "res://data/parts") -> Dictionary:
	var out := {}
	for p in DefLoader.load_dir(dir, "PartDef"):
		out[p.id] = p
	return out
