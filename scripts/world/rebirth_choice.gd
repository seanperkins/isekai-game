class_name RebirthChoice
extends RefCounted
## The places a rebirth can start at: the pools in the room data. The goddess's scene lists the attuned ones and the player
## picks; nothing here draws or decides anything.

## Every rebirth pool in the room data: [{"id", "area", "room", "pos", "kit", "name"}], the default
## pool first and the rest by id, so the order never changes between runs. The pool's own kit is ignored
## until pools become altars: the head start is bought in the goddess's menu.
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
