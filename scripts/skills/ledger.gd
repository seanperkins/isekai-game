class_name Ledger
extends RefCounted
## Per-run event log. Counts use superset tag matching: an entry matches when it has
## every key in the query with an equal value. Extra entry tags are ignored.
## Linear scans are fine at prototype scale (a run logs a few thousand events).

var _log: Array = []  # [[event_name: String, tags: Dictionary], ...] in arrival order

func record(event_name: String, tags: Dictionary) -> void:
	_log.append([event_name, tags.duplicate()])

func counter(event_name: String, query: Dictionary) -> int:
	var n := 0
	for entry in _log:
		if entry[0] == event_name and _matches(entry[1], query):
			n += 1
	return n

## Matching entries since the most recent `reset_on` event (any tags).
func reset_counter(event_name: String, query: Dictionary, reset_on: String) -> int:
	var n := 0
	for i in range(_log.size() - 1, -1, -1):
		var entry: Array = _log[i]
		if entry[0] == reset_on:
			break
		if entry[0] == event_name and _matches(entry[1], query):
			n += 1
	return n

func clear() -> void:
	_log.clear()

## How many entries the log holds (a cheap fingerprint for memoizing answers that read the whole log).
func size() -> int:
	return _log.size()

static func _matches(tags: Dictionary, query: Dictionary) -> bool:
	for key in query:
		if not tags.has(key) or tags[key] != query[key]:
			return false
	return true
