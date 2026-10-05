class_name DeedTags
extends RefCounted
## The tags of a `defeated` deed: how a kill was made, from what the enemy recorded of the last blow (Enemy.last_blow) and the
## player's surroundings. Tags are true or absent, so a gate asks for `{"behind": true}`.

## A blow struck from at least this far away was ranged: a bolt, a thrown thing, a mark landing from a distance.
const RANGED_PX := 48.0
## A foe with at least this much HP is heavy.
const HEAVY_HP := 20
## An enemy moving away from the player faster than this is fleeing.
const FLEE_SPEED := 20.0
## The areas that are dark: kills there are kills in the dark.
const DARK_AREAS := ["deep", "swamp", "cemetery", "crypt", "demon"]

static func is_dark_area(area: String) -> bool:
	return DARK_AREAS.has(area)

## `blow` is Enemy.last_blow ({} when none was recorded): from_behind, distance, damage_type, marked, alert, fleeing. `ctx` is what the
## player knows: ceiling (hanging from one, or just dropped from one), dark (in a dark area), moonlit (in a room tagged `moonlit`) and avenged (it killed the last life).
static func for_defeat(def: CreatureDef, blow: Dictionary, ctx: Dictionary) -> Dictionary:
	var tags := {"source": def.id}
	if def.species != "":
		tags["species"] = def.species
	if blow.get("from_behind", false):
		tags["behind"] = true
	if float(blow.get("distance", 0.0)) >= RANGED_PX:
		tags["ranged"] = true
	if blow.get("damage_type", "") == "poison":
		tags["poison"] = true
	if int(def.stats.get("max_hp", 0)) >= HEAVY_HP:
		tags["heavy"] = true
	if blow.get("marked", false):
		tags["marked"] = true
	if not blow.is_empty() and not blow.get("alert", true):
		tags["unseen"] = true
	if blow.get("fleeing", false):
		tags["fleeing"] = true
	if ctx.get("ceiling", false):
		tags["ceiling"] = true
	if ctx.get("dark", false):
		tags["dark"] = true
	if ctx.get("moonlit", false):
		tags["moonlit"] = true
	if ctx.get("avenged", false):
		tags["avenged"] = true
	return tags
