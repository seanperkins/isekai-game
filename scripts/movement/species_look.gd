class_name SpeciesLook
extends RefCounted
## How each species is drawn in the movement sandbox: which sheet, which clips, and which clip fits what the body is
## doing. A species with no entry (or whose sheet is missing) is drawn as a placeholder. Pure statics, so a test
## can ask what a given movement looks like without a scene.

const LOOKS := {
	"slime": {"sheet": "slime", "clips": "res://data/slime_clips.json", "key": ""},
	"spider": {"sheet": "spider", "clips": "res://data/enemy_clips.json", "key": "spider"},
	"wolf": {"sheet": "gloom_wolf", "clips": "res://data/enemy_clips.json", "key": "gloom_wolf"},
	"biped": {"sheet": "goblin", "clips": "res://data/enemy_clips.json", "key": "goblin"},
}
## Horizontal speed (px/s) above which the spider crawls and the wolf walks, and from which the wolf gallops.
const MOVING_SPEED := 8.0
const GALLOP_SPEED := 150.0
## The flat slime's crawl wobble: how far it stretches (a fraction) and how fast the phase turns per px travelled (radians).
const CRAWL_AMPLITUDE := 0.15
const CRAWL_RATE := 0.2
## Pixels the spider travels in one full 4-frame leg cycle: about 6 cycles a second at full speed, the stride rate of a
## fast-running spider (docs/research/spider-locomotion.md). Legs follow distance, so feet never slide and stop when it stops.
const STRIDE_PX := 24.0
## The slime's ball: a clip name for the animator (frame `fall`); the sandbox draws the ball itself with SlimeBall, since no
## sheet frame is round.
const BALL_CLIP := {"frames": ["fall"], "fps": 1.0, "loop": false}

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
	if species == "slime":
		return all.merged({"ball": BALL_CLIP})
	return all if key == "" else all.get(key, {})

## The clip for a body that is on the floor or not, moving at `vx` and falling at `vy`, `land_timer` seconds after
## landing, running burst `verb` ("tackle", "puddle"), `flat` (spread or sliding), clinging to a wall (`wall`) and bouncing
## (`ball`, which only replaces the rise, fall and landing poses). The slime, the wolf (its leaping frame, `windup`, for a
## pounce) and the goblin (roll, slide, mantle, wall) have poses for these. `verb` also carries "mantle" for the biped's pull-up.
## "" when the species has no look.
static func clip_for(species: String, on_floor: bool, vy: float, vx: float, land_timer: float, verb := "", flat := false, wall := false, ball := false) -> String:
	match species:
		"slime":
			var pose := SlimeState.pick(false, false, false, wall, verb == "tackle", flat, on_floor, vy, land_timer, vx)
			return "ball" if ball and (pose == "rise" or pose == "fall" or pose == "land") else pose
		"spider":
			if not on_floor:
				return "drop"
			return "crawl" if absf(vx) > MOVING_SPEED else "hang"
		"biped":
			if verb == "roll" or verb == "slide" or verb == "mantle":
				return verb  # a verb beats the wall pose and the air poses
			if wall:
				return "wall"
			if not on_floor:
				return "rise" if vy < 0.0 else "fall"
			return "run" if absf(vx) > MOVING_SPEED else "idle"
		"wolf":
			if verb == "pounce" or not on_floor:
				return "windup"
			if absf(vx) >= GALLOP_SPEED:
				return "charge"
			return "walk" if absf(vx) > MOVING_SPEED else "idle"
	return ""

## The crawl wobble at `phase`: it stretches out along the ground and squeezes back, keeping its volume.
static func crawl_scale(phase: float) -> Vector2:
	var a := CRAWL_AMPLITUDE * sin(phase)
	return Vector2(1.0 + a, 1.0 / (1.0 + a))

## The wobble's phase after `dt` seconds at horizontal speed `vx`: it turns with the distance crawled.
static func crawl_advance(phase: float, vx: float, dt: float) -> float:
	return phase + absf(vx) * dt * CRAWL_RATE

## The leg cycle's phase (1.0 per cycle) after moving `moved` px.
static func stride_advance(phase: float, moved: float) -> float:
	return phase + absf(moved) / STRIDE_PX

## Which of the 4 crawl frames (0 to 3) a phase shows.
static func stride_frame(phase: float) -> int:
	return int(floorf(fposmod(phase, 1.0) * 4.0)) % 4

## The sprite's rotation for a surface with normal `n`: a quarter turn per face, 0 on a floor.
static func surface_angle(n: Vector2) -> float:
	return wrapf(n.angle() + PI / 2.0, -PI, PI)
