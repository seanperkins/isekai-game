class_name Glimpse
extends Sprite2D
## A dark silhouette of a creature behind a room's solids (RoomDef.glimpse): the creature's own sheet frame, near black, scaled up and
## drifting slowly, so the player half sees what is waiting before they meet it. RoomBuilder puts it before the water and the solids.

const COLOR := Color(0.04, 0.03, 0.07, 0.7)
## How far it wanders from its place (px): slow and small, a thing moving behind a gap.
const DRIFT := 24.0

var _base := Vector2.ZERO
var _t := 0.0

## `g` is a RoomDef.glimpse ({"creature", "pos", "scale", optional "frame"}); null when the creature has no sheet.
static func make(g: Dictionary) -> Glimpse:
	var id := str(g.get("creature", ""))
	if not SpriteSheet.available(id):
		return null
	var sheet := SpriteSheet.load_set(id)
	var out := Glimpse.new()
	out.name = "Glimpse"
	out.texture = sheet.frame_texture(str(g.get("frame", sheet.frame_names()[0])))
	out.position = g["pos"]
	out._base = g["pos"]
	out.scale = Vector2.ONE * float(g.get("scale", 1.0))
	out.modulate = COLOR
	return out

func _process(delta: float) -> void:
	_t += delta
	position = _base + Vector2(sin(_t * 0.31) * DRIFT, cos(_t * 0.23) * DRIFT * 0.5)
