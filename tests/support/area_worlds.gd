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

## The areas' prefixes in the order the builder builds them (tools/areas/areas.gd): a new area adds its prefix at the end.
const ORDER := ["FO", "SW", "VI", "CM", "CA", "CR", "VO", "DM", "PL"]

## The world as it was once the area with prefix `last` was built: every area after it taken out. "" is the hand-authored world.
static func upto(last: String) -> Dictionary:
	return without(ORDER.slice(ORDER.find(last) + 1))

static func without(prefixes: Array) -> Dictionary:
	var mods: Array = []
	for p: String in prefixes:
		mods.append(Without.new(p))
	return AreaBuilder.build_with(mods)
