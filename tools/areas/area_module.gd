class_name AreaModule
extends RefCounted
## One area of the world, built in code (tools/areas/). `build` adds the area's rooms to `world` (room id -> RoomDef, the shipped rooms
## and the earlier modules' included) and attaches them by adding the exits it names to existing rooms.

func area() -> String:
	return ""

## The letters its room ids start with ("FO" for FO1, FO2 ...): the rooms the builder makes afresh on every run, and the exits to such rooms
## it strips from the hand-authored rooms before the module attaches them again.
func prefix() -> String:
	return ""

func build(_world: Dictionary) -> void:
	pass

## AreaKit.link, reporting a join that does not hold (a module's layout is wrong, not the player's input).
func link(a: RoomDef, b: RoomDef, edge: String, from_world: float, to_world: float, extra := {}) -> void:
	if not AreaKit.link(a, b, edge, from_world, to_world, extra):
		push_error("%s: %s to %s on %s %s..%s does not link" % [area(), a.id, b.id, edge, from_world, to_world])

## A feature the module puts in an existing room (a shipped one). It is marked with the module's prefix (`by`) so that the next run strips it
## from the room before the module builds again, as it strips the exits to the module's rooms.
func attach_feature(r: RoomDef, kind: String, id: String, x: float, surface_y: float, extra := {}) -> void:
	var f := extra.duplicate()
	f["by"] = prefix()
	AreaKit.feature(r, kind, id, x, surface_y, f)

## What this module could not do (a creature no room can hold): the builder reports it and refuses to write the world. Empty when all is well.
func problems() -> PackedStringArray:
	return PackedStringArray()
