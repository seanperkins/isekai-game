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

## Says `event` on the event bus, with `tags` ({"id": this feature's id} when none are given), unless it has been said this life with them (by this
## node or an earlier one).
func report(event: String, tags := {}) -> void:
	if _done:
		return
	_done = true
	var said: Dictionary = tags if not tags.is_empty() else {"id": id}
	var l = ledger if ledger != null else get_node_or_null("/root/SkillRules")
	if l != null and l.count(event, said) > 0:
		return
	EventBus.game_event.emit(event, said)
