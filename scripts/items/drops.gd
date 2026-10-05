class_name Drops
extends RefCounted
## What a creature leaves when it goes down. Pure: the caller supplies the rng.

## The chance a large creature leaves each of ribs and flesh, when its own drops do not already say.
const LARGE_CHANCE := 0.2
const LARGE_PARTS := ["ribs", "flesh"]

## The def's own drops plus the large-corpse rule: a creature that can be eaten and has at least DeedTags.HEAVY_HP of HP leaves ribs
## and flesh at LARGE_CHANCE unless its own list names that part.
static func for_def(def: CreatureDef) -> Array:
	var out: Array = def.drops.duplicate(true)
	if def.predatable and int(def.stats.get("max_hp", 0)) >= DeedTags.HEAVY_HP:
		for part in LARGE_PARTS:
			if not out.any(func(e: Dictionary) -> bool: return e.get("part", "") == part):
				out.append({"part": part, "chance": LARGE_CHANCE})
	return out

## The part ids left, each entry rolled once.
static func roll(def: CreatureDef, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for entry in for_def(def):
		if rng.randf() < float(entry["chance"]):
			out.append(entry["part"])
	return out
