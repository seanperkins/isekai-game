class_name RoomHold
extends RoomDeed
## Added to a room tagged `hold`: twenty seconds in the room with a threat alive in it is `room_held`, once per life per room. Seconds with
## nothing left to fight count for nothing.

const SECONDS := 20.0

var _held := 0.0

func _physics_process(delta: float) -> void:
	step(delta, threat_alive())

## True when an enemy of the room this hangs in is alive and able to fight.
func threat_alive() -> bool:
	var room := get_parent()
	if room == null:
		return false
	for n in room.get_children():
		if n is Enemy and (n as Enemy).is_threat():
			return true
	return false

func step(delta: float, threat: bool) -> void:
	if _done or not threat:
		return
	_held += delta
	if _held >= SECONDS:
		report(Deeds.ROOM_HELD, {"room": id})
