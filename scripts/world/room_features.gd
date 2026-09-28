class_name RoomFeatures
extends RefCounted
## Builds a room feature (Glow Pool, tablet, shortcut switch) from its data. Unknown kinds
## return null.

static func make(f: Dictionary, ctx: Dictionary) -> Node2D:
	match f.get("kind", ""):
		"glow_pool":
			var pool := GlowPool.new()
			pool.setup(f, ctx)
			return pool
		"tablet":
			var tablet := Tablet.new()
			tablet.setup(f, ctx)
			return tablet
	return null
