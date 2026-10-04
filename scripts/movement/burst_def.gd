class_name BurstDef
extends Resource
## One burst: a verb that takes over horizontal velocity for a short while (Tackle, the puddle slide; later roll and
## pounce are more rows). VerbRunner reads the rows in a profile's `bursts`; the numbers are data, hand-edited like the
## profiles. Speeds px/s, times s.

@export var id := ""
## What starts it: "signature" (the species' button, Tackle) or "down_run" (down held while running on the floor).
@export var trigger := "signature"
## The speed along the burst's direction at the start; 0 keeps the speed the body has.
@export var speed := 0.0
## The body needs at least this horizontal speed to start it, and (when above 0) less than `max_start_speed`: the biped's roll
## is the slow one, its slide the fast one.
@export var min_start_speed := 0.0
@export var max_start_speed := 0.0
## Seconds from the start in which the body is invulnerable (the roll and the slide).
@export var iframes := 0.0
## The most seconds it lasts.
@export var duration := 0.15
## How fast the speed bleeds (px/s^2); 0 holds it.
@export var decel := 0.0
## It ends when the speed falls under this (0 for never).
@export var min_speed := 0.0
## It ends when down is released, or when the body leaves the floor.
@export var needs_down := false
@export var needs_floor := false
## The body uses the flat collision box while it runs.
@export var flat := false
## Seconds before it can start again.
@export var cooldown := 0.0
## Rows with the same group share one cooldown (a roll cannot be followed at once by a slide); empty means the row's own id.
@export var cooldown_group := ""
## An aimed burst (the wolf's pounce) goes along the aim, not just the facing: velocity is `aim * (speed + run_fraction * the
## horizontal speed the body had)`, gravity keeps acting, and the stick does not steer it.
@export var aimed := false
@export var run_fraction := 0.0
## It ends when the body meets a wall in the direction it is going (a straight-up aim goes toward no wall).
@export var ends_at_wall := false
