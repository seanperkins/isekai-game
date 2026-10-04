class_name MovementProfile
extends Resource
## One body's ground and air feel, as data: how fast it starts, stops and turns, how its jump is shaped, and what
## releasing the jump button does. GroundAirStep reads it; nothing else needs to know a species exists. Content lives
## in res://data/movement/ and is edited by hand (three profiles do not need a generator). Defaults are the biped's.
## Times are seconds, speeds px/s, accelerations are derived by the step as top speed over time.

enum ReleaseStyle { CUT, SOFT }

const IDS := ["biped", "slime", "wolf", "spider"]

@export var id := ""
@export var top_speed := 140.0
## Seconds from rest to top speed on the floor, from top speed to rest with no input, and to brake from top speed
## when the input opposes the velocity (it accelerates from rest on the next tick).
@export var ground_accel_time := 0.04
@export var ground_stop_time := 0.03
@export var ground_turn_time := 0.03
## In the air the ground accel is scaled by this; with no input the speed bleeds to rest over air_stop_time unless
## air_keeps_momentum.
@export var air_accel_mult := 1.0
@export var air_stop_time := 0.03
@export var air_keeps_momentum := false
@export var jump_velocity := 330.0
@export var gravity := 900.0
## Multiplies gravity while falling (vy > 0). The apex float multiplies it too while jump is held and |vy| < apex_band
## (a band of 0 never matches).
@export var fall_mult := 1.0
@export var apex_band := 0.0
@export var apex_gravity_mult := 0.5
## CUT caps the rise speed at launch_speed * release_factor once; SOFT multiplies gravity by release_factor until the
## apex.
@export var release_style := ReleaseStyle.CUT
@export var release_factor := 0.35
@export var coyote := 0.1
@export var buffer := 0.1
## A buffered jump that fires after at least 0.12 s of air (a timed rebound) launches this much higher per link of a chain
## (rise, so speed x sqrt(1 + it)), up to rebound_cap in total (0 caps the chain at one link).
@export var rebound_rise := 0.0
@export var rebound_cap := 0.0
## A press this many seconds after a hard landing still counts as that landing's timed rebound (0 for none).
@export var rebound_grace := 0.0
## Hold bounce: landing with jump held and an impact of at least bounce_min_impact relaunches at bounce_keep times the
## last launch speed (0 for none).
@export var bounce_keep := 0.0
@export var bounce_min_impact := 250.0
## Wall verbs. The cling and the wall jump need the "wall" verb: stick at `wall_stick_speed` for `wall_stick_time`, then slide
## at `wall_slide_speed`; a wall jump pushes off at `wall_jump_push` with the full jump speed upward and locks steering for
## `wall_lock`; a wall jump still works `wall_grace` after leaving the wall. The bounce needs only `wall_bounce_keep` above 0:
## holding jump into a wall at `wall_bounce_min` or more reflects that speed times `wall_bounce_keep`.
@export var wall_stick_time := 0.2
@export var wall_stick_speed := 15.0
@export var wall_slide_speed := 90.0
@export var wall_jump_push := 180.0
@export var wall_lock := 0.15
@export var wall_grace := 0.1
@export var wall_bounce_keep := 0.0
@export var wall_bounce_min := 100.0
## Crawl: seconds after rounding a corner before another may start (a stick wiggled at a corner would otherwise round it
## every few frames), and how long after a corner pressing back the way it came goes back round it.
@export var corner_lock := 0.10
@export var crawl_back_window := 0.6
## Web zip: the farthest solid it will fire at (px), the pull speed (px/s), the fraction of that speed a jump cancel keeps, and
## the seconds before the next zip (from the end of the last).
@export var zip_range := 160.0
@export var zip_speed := 400.0
@export var zip_keep := 0.6
@export var zip_cooldown := 0.4
## Silk drop: the farthest solid above it will spin a thread from (px), how fast down reels and up climbs (px/s), and the
## fraction of the usual air control it keeps while hanging.
@export var drop_range := 200.0
@export var drop_reel := 90.0
@export var drop_climb := 60.0
@export var drop_air := 0.5
## How long (s) a press of down on a one-way ledge makes the caller ignore one-way ledges, so the body drops through: long
## enough to clear the ledge's margin, short enough to land on the next floor.
@export var fall_through := 0.2
## Vault (the wolf): the horizontal speed it needs to hop a step on its own, the tallest step it clears (px), and how far above
## the step the feet end up (px).
@export var vault_speed := 150.0
@export var vault_step := 24.0
@export var vault_margin := 6.0
## The speed (px/s) from which reversing on the floor counts as a skid (a flag only: the brake is the turn time).
@export var skid_speed := 150.0
## Mantle (the biped): how far under a ledge's top (px) the feet may be and still grab it (plus the fall this tick; the hands
## reach a little over the head, so a ledge hit half way up a jump is grabbed, rising or falling), and the seconds the pull takes.
@export var mantle_reach := 32.0
@export var mantle_time := 0.25
## The extra verbs this species has ("ooze"), and its burst rows (BurstDef: Tackle, the puddle slide, later roll and pounce).
@export var verbs := PackedStringArray()
@export var bursts: Array = []

## The profile with this id, or null for an unknown one (never loads a path that does not exist).
static func of(profile_id: String) -> MovementProfile:
	var path := "res://data/movement/%s.tres" % profile_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MovementProfile
