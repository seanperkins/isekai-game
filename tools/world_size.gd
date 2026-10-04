extends SceneTree
## Prints how big the shipped world is next to Super Metroid: rooms, screens (640x360 each), the shape of a room, and rooms per area against the
## room budget in docs/research/area-level-design.md section 17. The numbers and the budget live in WorldSize, which the room editor's World view
## also shows. Informational only: it exits 0 whatever the numbers are and no test reads it.
##   tools/world_size.sh

const BAR := 30

func _init() -> void:
	var rooms := {}
	for r in DefLoader.load_dir("res://data/rooms", "RoomDef"):
		rooms[r.id] = r
	var m := WorldSize.measure(rooms)
	print("WORLD SIZE (informational, not a gate)")
	print("")
	print("%d rooms, %d screens (%.1f per room, median %d, largest %d); %d single-screen rooms; map bounds %d x %d screens" % [
		m["rooms"], m["screens"], m["avg"], m["median"], m["largest"], m["single"], int(m["bounds"].x), int(m["bounds"].y)])
	print("Super Metroid: %d rooms, %d screens (%.1f per room)" % [WorldSize.SM_ROOMS, WorldSize.SM_SCREENS, WorldSize.SM_SCREENS_PER_ROOM])
	print("")
	print("%-26s %-32s %s" % ["yardstick", "progress", "now / target"])
	for y in WorldSize.yardsticks(m):
		print("%-26s %s %3d%%   %d / %d" % [y["label"], _bar(y["frac"]), roundi(y["frac"] * 100.0), y["now"], y["target"]])
	print("")
	print("%-16s %-32s %s" % ["area", "rooms against the budget", "rooms / target   screens"])
	for a in WorldSize.area_rows(m):
		print("%-16s %s %3d%%   %d / %d   %d" % [a["area"], _bar(a["frac"]), roundi(a["frac"] * 100.0), a["rooms"], a["target"], a["screens"]])
	print("%-16s %d" % ["budget total", WorldSize.target_total()])
	quit()

static func _bar(frac: float) -> String:
	var n := clampi(roundi(frac * BAR), 0, BAR)
	return "[" + "#".repeat(n) + ".".repeat(BAR - n) + "]"
