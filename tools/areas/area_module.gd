class_name AreaModule
extends RefCounted
## One area of the world, built in code (tools/areas/). `build` adds the area's rooms to `world` (room id -> RoomDef, the shipped rooms
## and the earlier modules' included) and attaches them by adding the exits it names to existing rooms.

func area() -> String:
	return ""

func build(_world: Dictionary) -> void:
	pass
