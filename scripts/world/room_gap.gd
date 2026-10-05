class_name RoomGap
extends RoomDeed
## A gap in the way (between two branches, two planks): crossing it from one side to the other in the air, above the surface it opens in, is
## `gap_crossed`. `pos` is the middle of the gap at the height of the surface either side; a walk below it, or a crossing on a floor, is not one.

## How far below the surface the player's feet may be and still count as above it.
const AIR_SLACK := 6.0

var width := 50.0
var _side := 0

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	width = float(f.get("width", width))

func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		step(p)

## One look at the player (a test calls it with a double).
func step(p: Node2D) -> void:
	var dx := p.global_position.x - global_position.x
	if absf(dx) <= width / 2.0:
		return
	var side := 1 if dx > 0.0 else -1
	var airborne: bool = not p.is_on_floor() and p.global_position.y + BodyConfig.BOTTOM <= global_position.y + AIR_SLACK
	if airborne and _side != 0 and side != _side:
		report(Deeds.GAP_CROSSED)
	_side = side
