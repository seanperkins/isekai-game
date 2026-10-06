class_name RoomFeatures
extends RefCounted
## Builds a room feature (Glow Pool, altar, tablet, shortcut switch, and the five the deeds read: barrier, hidden door, gap, lamp, vigil; and a talisman)
## from its data. Unknown kinds return null.

static func make(f: Dictionary, ctx: Dictionary) -> Node2D:
	var made := _make(f, ctx)
	if made is RoomDeed:
		(made as RoomDeed).ledger = ctx.get("ledger", null)
	return made

## Whether `ledger` (the run's rules engine, the autoload when null) has `event` for this feature's id already: a barrier broken or a door found
## this life is not built again.
static func _said(f: Dictionary, event: String, ctx: Dictionary) -> bool:
	var l = ctx.get("ledger", null)
	if l == null:
		var loop := Engine.get_main_loop()
		l = (loop as SceneTree).root.get_node_or_null("SkillRules") if loop is SceneTree else null
	return l != null and l.count(event, {"id": f.get("id", "")}) > 0

static func _make(f: Dictionary, ctx: Dictionary) -> Node2D:
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
			if _said(f, Deeds.BARRIER_BROKEN, ctx):
				return null
			var barrier := RoomBarrier.new()
			barrier.setup(f, ctx)
			return barrier
		"hidden":
			if _said(f, Deeds.HIDDEN_FOUND, ctx):
				return null
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
		"talisman":
			var talisman := RoomTalisman.new()
			talisman.setup(f, ctx)
			return talisman
	return null
