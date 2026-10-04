class_name MoveState
extends RefCounted
## What GroundAirStep remembers between ticks: the velocity it integrates and the timers behind coyote time, the jump
## buffer, release and the rebound.

var velocity := Vector2.ZERO
## Seconds of coyote time and of jump buffer left.
var coyote := 0.0
var buffer := 0.0
## Seconds airborne so far, kept through the first floor tick so a landing can tell a real fall from a step down.
var air_time := 0.0
## A jump's rise is in progress (set at launch; cleared at the apex, on release with CUT, and on the floor).
var jumping := false
## The speed of the last launch, which a CUT release takes its fraction of.
var launch_speed := 0.0
## What the step launched this tick: "" (nothing), "ground", "coyote" or "rebound".
var launched := ""
## The way the body faces (1 right, -1 left): the last direction pressed.
var facing := 1
## The slime is flat (Ooze): half speed, the low box.
var spread := false
## The burst running ("" for none), the seconds it has left, the way it goes, and the cooldowns still running (id to s).
var verb := ""
var verb_left := 0.0
var verb_dir := 1.0
var cooldowns := {}
