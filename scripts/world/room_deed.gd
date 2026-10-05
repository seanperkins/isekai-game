class_name RoomDeed
extends Node2D
## The base of the room features that earn a deed at most once per life, by id (a gap, a lamp, a vigil). The rules ledger knows what this life
## has already earned, so a room built again (a second visit) does not pay twice.

var id := ""
## Anything with `count(event, tags)`: the run's rules engine. The SkillRules autoload when null.
var ledger = null
var _done := false

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f["pos"]

## Says `event` on the event bus with this feature's id, unless it has been said this life (by this node or an earlier one).
func report(event: String) -> void:
	if _done:
		return
	_done = true
	var l = ledger if ledger != null else get_node_or_null("/root/SkillRules")
	if l != null and l.count(event, {"id": id}) > 0:
		return
	EventBus.game_event.emit(event, {"id": id})
