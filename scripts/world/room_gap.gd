class_name RoomGap
extends RoomDeed
## A gap in the way (between two branches, two planks): crossing it from one side to the other in the air, above the surface it opens in, the whole
## way across, is `gap_crossed`. `pos` is the middle of the gap at the height of the lower surface; a walk below it, a jump up through it from
## below, or a crossing on a floor is not one.

## How far below the surface the player's feet may be and still count as above it.
const AIR_SLACK := 6.0

var width := 50.0
var _side := 0  # which side of the gap the player was last on (-1 left, 1 right, 0 not yet)
var _inside := false  # the last sample was in the gap
var _clean := false  # the player came into the gap above its surface and has stayed above it

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
	var above: bool = not p.is_on_floor() and p.global_position.y + BodyConfig.BOTTOM <= global_position.y + AIR_SLACK
	if absf(dx) <= width / 2.0:
		if _side != 0:
			if not _inside:
				_clean = above
			elif not above:
				_clean = false
		_inside = true
		return
	var side := 1 if dx > 0.0 else -1
	if _clean and above and _side != 0 and side != _side:
		report(Deeds.GAP_CROSSED)
	_clean = false
	_inside = false
	_side = side
