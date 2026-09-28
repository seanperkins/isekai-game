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
		"switch":
			var progress = ctx.get("progress")
			if progress != null and progress.is_open(f["shortcut"]):
				return null  # already broken open
			var sw := ShortcutSwitch.new()
			sw.setup(f, ctx)
			return sw
	return null
