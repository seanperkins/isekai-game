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
