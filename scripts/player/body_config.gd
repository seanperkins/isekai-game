class_name BodyConfig
extends RefCounted
## The slime's body scale, in one place. SCALE 1 is the original 22x18 px slime; 2 makes it twice as
## big in the world. The collision boxes and the floor line derive from it.

const SCALE := 2
## Collision boxes at SCALE 1.
const COLLISION := Vector2(14, 12)
const SPREAD_COLLISION := Vector2(14, 5)
## Where the body's bottom sits below its origin (half the standing box), so it stands on the floor.
const BOTTOM := COLLISION.y / 2.0 * SCALE

static func size() -> Vector2:
	return COLLISION * float(SCALE)

static func spread_size() -> Vector2:
	return SPREAD_COLLISION * float(SCALE)
