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
## The floor it stands on is a one-way ledge (a down press then drops through it).
var on_oneway_floor := false
## The crawl's two world probes, filled by the caller (the sandbox now, the player later), both measured from the body's
## centre with its current box. `sweep(motion: Vector2) -> Dictionary` is `{}` when the box can move that far, else
## `{"travel": Vector2, "normal": Vector2}` for the first hard solid it meets. `ray(from: Vector2, to: Vector2, hard_only:
## bool) -> int` is 0 for nothing, 1 for a hard solid, 2 for a one-way ledge and 3 for a slick one, a hard solid that refuses
## grip (offsets from the centre). A sweep hit and a cast hit also carry `"slick": bool`. Without them a
## species that crawls is not on a surface and uses the ground step.
var sweep := Callable()
var ray := Callable()
## The web zip's cast, filled by the caller too: `cast(from: Vector2, to: Vector2, include_oneway: bool) -> Dictionary` is
## `{}` when the segment meets nothing, else `{"point": Vector2, "normal": Vector2, "oneway": bool}` for the first hard solid
## along it (offsets from the body's centre); a one-way ledge's top counts only when `include_oneway` and the segment goes down.
var cast := Callable()
## The resolved cast aim (a free pointer direction, else the left stick 8-way), ZERO for none; the zip then uses the facing.
var aim := Vector2.ZERO
## Which side a wall is on within 6 px (-1 left, 1 right, 0 none): the caller probes it; the step ignores it on the floor.
var wall_side := 0
## The body overlaps a hostile this tick: the caller probes it; the wolf's pounce marks the contact (MoveState.pounce_hit).
var touching_hostile := false
## The height (px) of a hard step in the direction of travel at the feet, 0 for none; a one-way ledge is never reported. The
## caller probes it; only the wolf's vault reads it.
var step_ahead := 0.0
## The biped's mantle: the displacement from the body's centre to where it would stand on the hard ledge ahead (`y` is minus the
## px from the feet up to its top), ZERO for none. The caller probes it, only where the standing box fits.
var mantle := Vector2.ZERO

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
	c.on_oneway_floor = on_oneway_floor
	c.sweep = sweep
	c.ray = ray
	c.cast = cast
	c.aim = aim
	c.touching_hostile = touching_hostile
	c.step_ahead = step_ahead
	c.mantle = mantle
	return c

## The stick as a vector (x right, y down): `dir` across and `down` minus `up` along.
func stick() -> Vector2:
	return Vector2(dir, down - up)
