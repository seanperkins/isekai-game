class_name SpeciesLook
extends RefCounted
## How each species is drawn in the movement sandbox: which sheet, which clips, and which clip fits what the body is
## doing. A species with no entry (the biped, which has no art yet) is drawn as a placeholder. Pure statics, so a test
## can ask what a given movement looks like without a scene.

const LOOKS := {
	"slime": {"sheet": "slime", "clips": "res://data/slime_clips.json", "key": ""},
	"spider": {"sheet": "spider", "clips": "res://data/enemy_clips.json", "key": "spider"},
	"wolf": {"sheet": "gloom_wolf", "clips": "res://data/enemy_clips.json", "key": "gloom_wolf"},
}
## Horizontal speed (px/s) above which the spider crawls and the wolf walks, and from which the wolf gallops.
const MOVING_SPEED := 8.0
const GALLOP_SPEED := 150.0

static func has_look(species: String) -> bool:
	return LOOKS.has(species)

## The species' sheet, or null when it has no look or the sheet is missing (not imported).
static func sheet_for(species: String) -> SpriteSheet:
	if not LOOKS.has(species):
		return null
	return SpriteSheet.load_set(LOOKS[species]["sheet"])

## The species' clips (name -> {"frames", "fps", "loop"}), `{}` when it has no look.
static func clips_for(species: String) -> Dictionary:
	if not LOOKS.has(species):
		return {}
	var all := SlimeAnimator.load_clips(LOOKS[species]["clips"])
	var key: String = LOOKS[species]["key"]
	return all if key == "" else all.get(key, {})

## The clip for a body that is on the floor or not, moving at `vx` and falling at `vy`, `land_timer` seconds after
## landing, running burst `verb` ("tackle", "puddle") and `flat` (spread or sliding). Only the slime has poses for the
## verbs so far. "" when the species has no look.
static func clip_for(species: String, on_floor: bool, vy: float, vx: float, land_timer: float, verb := "", flat := false) -> String:
	match species:
		"slime":
			return SlimeState.pick(false, false, false, false, verb == "tackle", flat, on_floor, vy, land_timer, vx)
		"spider":
			if not on_floor:
				return "drop"
			return "crawl" if absf(vx) > MOVING_SPEED else "hang"
		"wolf":
			if not on_floor:
				return "windup"
			if absf(vx) >= GALLOP_SPEED:
				return "charge"
			return "walk" if absf(vx) > MOVING_SPEED else "idle"
	return ""
