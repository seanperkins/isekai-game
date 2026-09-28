class_name ActiveSlots
extends RefCounted
## Four active-skill slots (LB, RB, LT, RT / U, O, H, L). A new active fills the first empty
## slot, else replaces the least recently used one. The skill screen reassigns slots.

signal slot_replaced(new_id: String, old_id: String)

const SLOT_COUNT := 4

var slots: Array = ["", "", "", ""]
var owned: Array = []
var _stamps: Array = [0, 0, 0, 0]
var _clock := 0

func add(id: String) -> void:
	if owned.has(id):
		return
	owned.append(id)
	for i in SLOT_COUNT:
		if slots[i] == "":
			slots[i] = id
			_touch(i)
			return
	var lru := 0
	for i in SLOT_COUNT:
		if _stamps[i] < _stamps[lru]:
			lru = i
	var old: String = slots[lru]
	slots[lru] = id
	_touch(lru)
	slot_replaced.emit(id, old)

func use(i: int) -> String:
	if slots[i] == "":
		return ""
	_touch(i)
	return slots[i]

## Puts an owned active into slot `i`; if it was in another slot, the two swap.
func assign(i: int, id: String) -> void:
	if not owned.has(id):
		return
	var current := slots.find(id)
	if current >= 0 and current != i:
		slots[current] = slots[i]
	slots[i] = id
	_touch(i)

## The slot the skill screen moves `id` to next: the one after its current slot.
func next_slot_for(id: String) -> int:
	var current := slots.find(id)
	return 0 if current < 0 else (current + 1) % SLOT_COUNT

func reset() -> void:
	slots = ["", "", "", ""]
	owned = []
	_stamps = [0, 0, 0, 0]
	_clock = 0

func _touch(i: int) -> void:
	_clock += 1
	_stamps[i] = _clock
