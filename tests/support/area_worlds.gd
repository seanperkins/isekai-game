class_name AreaWorlds
extends RefCounted
## The checked-in world with some areas taken out: the rooms whose ids start with the given letters and the exits to them. A world with
## only the earlier areas in it is a world of its own, so each area's tests check it without the ones built after.

## A module that builds nothing: given to AreaBuilder.build_with it takes its prefix's rooms out.
class Without extends AreaModule:
	var _prefix := ""

	func _init(p: String) -> void:
		_prefix = p

	func prefix() -> String:
		return _prefix

static func without(prefixes: Array) -> Dictionary:
	var mods: Array = []
	for p: String in prefixes:
		mods.append(Without.new(p))
	return AreaBuilder.build_with(mods)
