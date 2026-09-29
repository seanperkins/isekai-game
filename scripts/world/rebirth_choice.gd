class_name RebirthChoice
extends RefCounted
## Pure logic for what happens after death. With one unlocked pool the run starts there directly; with
## more, it returns the list (unlocked first, then locked ones as "???") with the last choice
## pre-selected, and accepts only an unlocked entry. The menu that renders the list ships with the second
## pool (the Grotto); nothing here draws anything.

const LOCKED_NAME := "???"

## Every rebirth pool in the room data: [{"id", "area", "room", "pos", "kit", "name"}], the default
## pool first and the rest by id, so the order never changes between runs.
static func pools(rooms: Dictionary) -> Array:
	var out: Array = []
	for room_id in rooms:
		for f in (rooms[room_id] as RoomDef).features:
			if f.get("kind", "") == "rebirth_pool":
				out.append({"id": str(f.get("id", "")), "area": str(f.get("area", "")), "room": room_id,
					"pos": f.get("pos", Vector2.ZERO), "kit": f.get("kit", {}), "name": _name(f)})
	out.sort_custom(func(a, b):
		if a["id"] == WorldProgress.DEFAULT_POOL or b["id"] == WorldProgress.DEFAULT_POOL:
			return a["id"] == WorldProgress.DEFAULT_POOL and b["id"] != WorldProgress.DEFAULT_POOL
		return a["id"] < b["id"])
	return out

static func _name(f: Dictionary) -> String:
	if f.get("id", "") == WorldProgress.DEFAULT_POOL:
		return "Cave mouth"
	var area := str(f.get("area", "")).capitalize()
	return "%s rebirth pool" % area if area != "" else str(f.get("id", ""))

## {"direct": pool_id} with at most one unlocked pool, else {"options": [...], "selected": int}.
static func decide(all_pools: Array, attuned: Array, last: String) -> Dictionary:
	var unlocked: Array = []
	var locked: Array = []
	for p in all_pools:
		if attuned.has(p["id"]):
			unlocked.append(p)
		else:
			locked.append(p)
	if unlocked.size() <= 1:
		return {"direct": unlocked[0]["id"] if not unlocked.is_empty() else WorldProgress.DEFAULT_POOL}
	var options: Array = []
	for p in unlocked:
		options.append({"id": p["id"], "name": p["name"], "locked": false})
	for _p in locked:
		options.append({"name": LOCKED_NAME, "locked": true})
	var selected := 0
	for i in unlocked.size():
		if unlocked[i]["id"] == last:
			selected = i
	return {"options": options, "selected": selected}

## The pool id for an unlocked entry; "" for a locked, missing or out-of-range one.
static func accept(decision: Dictionary, index: int) -> String:
	if decision.has("direct"):
		return decision["direct"] if index == 0 else ""
	var options: Array = decision.get("options", [])
	if index < 0 or index >= options.size() or options[index]["locked"]:
		return ""
	return options[index]["id"]
