class_name ShippedRooms
extends RefCounted
## The eleven rooms the game shipped with. Content pins (XP totals, supplies, dressing) are about these rooms; a room the editor
## adds later is not part of them, while the rules (RoomLint's sixteen and the validator's) still run on every room.

const IDS := ["C1", "C2", "C3", "C4", "C5", "C6", "G1", "G2", "G3", "G4", "G5"]

static func only(rooms: Dictionary) -> Dictionary:
	var out := {}
	for id in IDS:
		if rooms.has(id):
			out[id] = rooms[id]
	return out

static func load_all() -> Dictionary:
	return only(World.load_rooms("res://data/rooms"))
