class_name RoomFeatures
extends RefCounted
## Builds a room feature (Glow Pool, altar, tablet, shortcut switch, and the five the deeds read: barrier, hidden door, gap, lamp, vigil)
## from its data. Unknown kinds return null.

static func make(f: Dictionary, ctx: Dictionary) -> Node2D:
	match f.get("kind", ""):
		"glow_pool":
			var pool := GlowPool.new()
			pool.setup(f, ctx)
			return pool
		"altar":
			var altar := Altar.new()
			altar.setup(f, ctx)
			return altar
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
		"barrier":
			var barrier := RoomBarrier.new()
			barrier.setup(f, ctx)
			return barrier
		"hidden":
			var hidden := RoomHidden.new()
			hidden.setup(f, ctx)
			return hidden
		"gap":
			var gap := RoomGap.new()
			gap.setup(f, ctx)
			return gap
		"lamp":
			var lamp := RoomLamp.new()
			lamp.setup(f, ctx)
			return lamp
		"vigil":
			var vigil := RoomVigil.new()
			vigil.setup(f, ctx)
			return vigil
	return null
