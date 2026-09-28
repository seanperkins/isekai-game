class_name ActiveSlots
extends RefCounted
## Two active-skill slots. A new active fills an empty slot, else replaces the least
## recently used one. Cycle rotates the last-used slot through owned actives that are not
## in the other slot; it updates the LRU stamp only and never counts as using a skill.

signal slot_replaced(new_id: String, old_id: String)

var slots: Array = ["", ""]
var owned: Array = []
var last_used := 0
var _stamps: Array = [0, 0]
var _clock := 0

func add(id: String) -> void:
	if owned.has(id):
		return
	owned.append(id)
	for i in 2:
		if slots[i] == "":
			slots[i] = id
			_touch(i)
			return
	var lru := 0 if _stamps[0] <= _stamps[1] else 1
	var old: String = slots[lru]
	slots[lru] = id
	_touch(lru)
	slot_replaced.emit(id, old)

func use(i: int) -> String:
	if slots[i] == "":
		return ""
	last_used = i
	_touch(i)
	return slots[i]

func cycle() -> void:
	var other: String = slots[1 - last_used]
	var candidates := owned.filter(func(x): return x != other)
	if candidates.is_empty():
		return
	var current := candidates.find(slots[last_used])
	var next: String = candidates[(current + 1) % candidates.size()]
	if next == slots[last_used]:
		return
	slots[last_used] = next
	_touch(last_used)

## Puts an owned active into slot `i` (from the skill screen). If it was already in the
## other slot, the two slots swap.
func assign(i: int, id: String) -> void:
	if not owned.has(id):
		return
	var other := 1 - i
	if slots[other] == id:
		slots[other] = slots[i]
	slots[i] = id
	_touch(i)

func reset() -> void:
	slots = ["", ""]
	owned = []
	last_used = 0
	_stamps = [0, 0]
	_clock = 0

func _touch(i: int) -> void:
	_clock += 1
	_stamps[i] = _clock
