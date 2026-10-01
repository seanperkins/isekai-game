class_name ShippedRooms
extends RefCounted
## The twenty-two rooms the game shipped with. Content pins (XP totals, supplies, dressing) are about these rooms; a room the editor
## adds later is not part of them, while the rules (RoomLint's sixteen and the validator's) still run on every room.

const IDS := ["C1", "C2", "C3", "C4", "C5", "C6", "G1", "G2", "G3", "G4", "G5", "F1", "F2", "F3", "F4", "F5", "F6", "D1", "D2", "D3", "D4", "D5"]

## A spawn's first-time value is twice its xp (the down and again the eat); a water_pool pays once. The sum over the rooms `ids`.
static func first_time(rooms: Dictionary, creatures: Dictionary, ids: Array) -> int:
	var total := 0
	for id in ids:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			total += c.xp * (1 if c.id == "water_pool" else 2)
	return total

static func only(rooms: Dictionary) -> Dictionary:
	var out := {}
	for id in IDS:
		if rooms.has(id):
			out[id] = rooms[id]
	return out

static func load_all() -> Dictionary:
	return only(World.load_rooms("res://data/rooms"))
