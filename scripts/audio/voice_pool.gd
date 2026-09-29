class_name VoicePool
extends RefCounted
## Which of a fixed set of voices plays the next sound: a per-cue cooldown, and when every voice is
## busy the quietest one is stolen (ties go to the oldest). Pure logic; Audio owns the players.

var capacity: int
var _clock: Callable
var _slots: Array = []
var _last_played := {}  # cue id -> clock time

func _init(p_capacity: int, p_clock: Callable) -> void:
	capacity = p_capacity
	_clock = p_clock
	for i in capacity:
		_slots.append({"cue": "", "volume_db": 0.0, "since": 0.0, "busy": false})

## A slot for the cue, or -1 while its cooldown has not passed.
func acquire(cue: String, volume_db: float, cooldown: float) -> int:
	var now: float = _clock.call()
	if cooldown > 0.0 and _last_played.has(cue) and now - float(_last_played[cue]) < cooldown:
		return -1
	var slot := _free_slot()
	if slot == -1:
		slot = _quietest()
	_last_played[cue] = now
	_slots[slot] = {"cue": cue, "volume_db": volume_db, "since": now, "busy": true}
	return slot

func release(slot: int) -> void:
	_slots[slot]["busy"] = false

func busy_count() -> int:
	return _slots.filter(func(s: Dictionary) -> bool: return s["busy"]).size()

func cue_at(slot: int) -> String:
	return _slots[slot]["cue"]

func _free_slot() -> int:
	for i in capacity:
		if not _slots[i]["busy"]:
			return i
	return -1

func _quietest() -> int:
	var best := 0
	for i in range(1, capacity):
		var s: Dictionary = _slots[i]
		var b: Dictionary = _slots[best]
		if s["volume_db"] < b["volume_db"] or (s["volume_db"] == b["volume_db"] and s["since"] < b["since"]):
			best = i
	return best
