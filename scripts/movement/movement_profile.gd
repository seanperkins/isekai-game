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
## A buffered jump that fires after at least 0.12 s of air launches this much higher (rise, so speed x sqrt(1 + it)).
@export var rebound_rise := 0.0

## The profile with this id, or null for an unknown one (never loads a path that does not exist).
static func of(profile_id: String) -> MovementProfile:
	var path := "res://data/movement/%s.tres" % profile_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MovementProfile
