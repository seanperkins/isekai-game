class_name AnnouncerQueue
extends RefCounted
## Great Sage pop-ups (unlocks only) and the level/slot ticker. Pure logic; UI reads it.
## At most MAX_POPUPS entries. Overflow merges the last entry into "+N more", so nothing
## is silently dropped and parents (queued first) still show before children.

const MAX_POPUPS := 4
const POPUP_SECONDS := 2.5

var _popups: Array = []
var _ticker: Array = []
var _shown_for := 0.0

func push_unlock(id: String, text: String) -> void:
	if _popups.size() < MAX_POPUPS:
		_popups.append({"kind": "unlock", "id": id, "text": text})
		return
	var last: Dictionary = _popups[-1]
	var count: int = int(last["count"]) + 1 if last["kind"] == "more" else 2
	_popups[-1] = {"kind": "more", "count": count, "text": "+%d more (see Compendium)" % count}

func push_level(id: String, level: int) -> void:
	_ticker.append({"kind": "level", "id": id, "level": level})

## A one-line note for the ticker (for example "Your skills grew.").
func push_note(text: String) -> void:
	_ticker.append({"kind": "note", "text": text})

func push_slot_replaced(new_id: String, old_id: String) -> void:
	_ticker.append({"kind": "slot_replaced", "new_id": new_id, "old_id": old_id})

func advance(delta: float) -> void:
	if _popups.is_empty():
		return
	_shown_for += delta
	if _shown_for >= POPUP_SECONDS - 0.0001:
		_popups.pop_front()
		_shown_for = 0.0

func current() -> Dictionary:
	return _popups[0] if not _popups.is_empty() else {}

func pending() -> Array:
	return _popups.duplicate(true)

func pop_ticker() -> Dictionary:
	return _ticker.pop_front() if not _ticker.is_empty() else {}

func clear() -> void:
	_popups.clear()
	_ticker.clear()
	_shown_for = 0.0
