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
## The vertical velocity the step handed the body on the previous tick: a landing's impact speed (the caller's physics
## zeroes the body's own velocity on landing).
var last_vy := 0.0
## Consecutive timed rebounds (a press at landing); a landing without one resets it.
var chain := 0
## Seconds left in which a floor press still counts as the last hard landing's timed rebound.
var rebound_left := 0.0
## The way the body faces (1 right, -1 left): the last direction pressed.
var facing := 1
## The slime is flat (Ooze): half speed, the low box.
var spread := false
## The burst running ("" for none), the seconds it has left, the way it goes, and the cooldowns still running (id to s).
var verb := ""
var verb_left := 0.0
var verb_dir := 1.0
var cooldowns := {}
## A burst has started in this airtime: no second one until the body lands (one air verb per airtime).
var air_verb_used := false
## An aimed burst (the pounce) has touched a hostile since it began: the caller marks the first one it hit.
var pounce_hit := false
## Wall verbs. Steering is locked for `lock` seconds after a wall jump or bounce; `wall_touch` says the body touched a wall last
## tick; `wall_stick` is the sticky time left; `wall_grace` the time a wall jump still works after leaving; `wall_side` the last
## wall touched; `clinging` that it is stuck or sliding this tick; `wall_bounced` that it bounced this tick; `last_vx` the x
## velocity the step handed the body last tick (a wall impact, since the physics zeroes the body's own).
var lock := 0.0
var wall_touch := false
var wall_stick := 0.0
var wall_grace := 0.0
var wall_side := 0
var clinging := false
var wall_bounced := false
var last_vx := 0.0
## The crawl (SurfaceStep). `surface_n` is the outward normal of the surface under the feet, ZERO when not on one;
## `surface_sigma` the sense along the clockwise tangent (1 or -1); `surface_latch` the direction held at the last corner
## and `surface_prev` the way it was moving before it; `surface_since` the seconds since that corner; `surface_lock` the
## corner lockout (and the re-attach lock after a hop) left; `surface_oneway` that the surface is a one-way ledge;
## `surface_shift` the displacement the caller applies this tick; `surface_event` what happened.
var surface_n := Vector2.ZERO
var surface_sigma := 1.0
var surface_latch := Vector2.ZERO
var surface_prev := Vector2.ZERO
var surface_since := 99.0
var surface_lock := 0.0
var surface_oneway := false
var surface_shift := Vector2.ZERO
var surface_event := ""
## The web zip (ZipStep). `zip_dir` is the unit direction while a thread pulls (ZERO otherwise), `zip_left` the px of thread
## still to pull, `zip_cooldown` the seconds before the next, `zip_target` the anchor as an offset from the body's centre at
## the start (for the caller's thread), `zip_event` what happened this tick ("", "start", "fizzle", "grip", "arrive", "cancel").
var zip_dir := Vector2.ZERO
var zip_left := 0.0
var zip_cooldown := 0.0
var zip_target := Vector2.ZERO
var zip_event := ""
## The silk drop (DropStep). `down_prev` is the raw down input last tick and `down_pressed` that it crossed 0.6 from below
## this tick (VerbRunner sets both); `drop_up` is the px from the body's centre up to the anchor while a drop runs (0.0
## when none), `drop_vx` the sideways speed, `drop_target` the anchor as an offset from the centre at the start (for the
## caller's thread) and `drop_event` what happened this tick ("", "start", "fizzle", "land", "release").
var down_prev := 0.0
var down_pressed := false
var drop_up := 0.0
var drop_vx := 0.0
var drop_target := Vector2.ZERO
var drop_event := ""
## Seconds left in which the caller ignores one-way ledges: a press of down on one starts it (VerbRunner), every species.
var fall_through := 0.0
