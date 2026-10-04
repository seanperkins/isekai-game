class_name MoveInput
extends RefCounted
## What the body wants this tick, and what it stands on. The caller rebuilds it every tick (player.gd reads Input and
## the physics body; the sandbox and tests fill it by hand).

## Left (-1) to right (1); an analog stick gives a fraction.
var dir := 0.0
var on_floor := true
## True only on the tick the jump button went down; held is true for as long as it stays down.
var jump_pressed := false
var jump_held := false
## The raw down input, 0 to 1 (a key gives 0 or 1, a stick a fraction).
var down := 0.0
## True only on the tick the species' signature button (Tackle) went down.
var signature_pressed := false
## Free pixels above a flat body: the caller probes it (a slime may only stand up with STAND_RISE free).
var clearance_above := 1000.0
## The raw up input, 0 to 1 (a crawler climbs and hangs, so it needs both vertical directions).
var up := 0.0
## The body touches a ceiling.
var on_ceiling := false
## The crawl's two world probes, filled by the caller (the sandbox now, the player later), both measured from the body's
## centre with its current box. `sweep(motion: Vector2) -> Dictionary` is `{}` when the box can move that far, else
## `{"travel": Vector2, "normal": Vector2}` for the first hard solid it meets. `ray(from: Vector2, to: Vector2, hard_only:
## bool) -> int` is 0 for nothing, 1 for a hard solid and 2 for a one-way ledge (offsets from the centre). Without them a
## species that crawls is not on a surface and uses the ground step.
var sweep := Callable()
var ray := Callable()
## Which side a wall is on within 6 px (-1 left, 1 right, 0 none): the caller probes it; the step ignores it on the floor.
var wall_side := 0

func copy() -> MoveInput:
	var c := MoveInput.new()
	c.dir = dir
	c.on_floor = on_floor
	c.jump_pressed = jump_pressed
	c.jump_held = jump_held
	c.down = down
	c.signature_pressed = signature_pressed
	c.clearance_above = clearance_above
	c.wall_side = wall_side
	c.up = up
	c.on_ceiling = on_ceiling
	c.sweep = sweep
	c.ray = ray
	return c

## The stick as a vector (x right, y down): `dir` across and `down` minus `up` along.
func stick() -> Vector2:
	return Vector2(dir, down - up)
