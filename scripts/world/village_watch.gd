class_name VillageWatch
extends RefCounted
## What a life has done in the goblin village, for two deeds said on leaving it: `village_kept` (no village creature killed, and the Yard seen)
## and `village_visited_unseen` (every village room seen and no creature there alerted). Each is said at most once per life. The village is the
## rooms of the area `village`; the Sump below it is the swamp's, so dropping into it is leaving.

## The room the village is kept by seeing: the Yard.
const YARD := "VI3"
const ROOMS := ["VI1", "VI2", "VI3", "VI4"]

## Called with (event, tags): the player's deed emitter.
var emit_deed := Callable()
var _visited := {}
var _kills := 0
var _alerted := false
var _inside := false
var _kept_said := false
var _unseen_said := false

## A room was entered. Leaving the village for any other area is where the deeds are said.
func enter(room_id: String, area: String) -> void:
	if area == "village":
		_inside = true
		_visited[room_id] = true
	elif _inside:
		_inside = false
		_leave()

## A creature the player killed, while in the village.
func killed() -> void:
	if _inside:
		_kills += 1

## An enemy of the village noticed the player.
func alerted() -> void:
	if _inside:
		_alerted = true

## Looks through the room's enemies for one that is alert.
func scan(room: Node) -> void:
	if not _inside or _alerted or room == null:
		return
	for n in room.get_children():
		if n is Enemy and (n as Enemy).is_alert():
			alerted()
			return

func reset() -> void:
	_visited.clear()
	_kills = 0
	_alerted = false
	_inside = false
	_kept_said = false
	_unseen_said = false

func _leave() -> void:
	if not _kept_said and _kills == 0 and _visited.has(YARD):
		_kept_said = true
		_say(Deeds.VILLAGE_KEPT)
	if not _unseen_said and not _alerted and ROOMS.all(func(id: String) -> bool: return _visited.has(id)):
		_unseen_said = true
		_say(Deeds.VILLAGE_VISITED_UNSEEN)

func _say(event: String) -> void:
	if emit_deed.is_valid():
		emit_deed.call(event, {})
