extends SceneTree
## Prints, for each diet of the world's creatures, the eat at which each essence power unlocks on four walks of the four shipped areas, the eat at
## which each slime lineage opens on a Cave start, and what is revealed and offered at the end of each area. Read-only.
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/calibrate_essences.gd
## A diet is the creatures an eater meets (CalibrationWalk.diet): `old` the hand-made ones, `common` those and the new commons (what a stage-1 body
## downs: the calibration's), `elite` and `all` with the new elites and then the rares. An optional `-- --diet=old` prints one.
## An optional `-- --data=res://some/dir` reads skills and creatures from `<dir>/skills` and `<dir>/creatures` instead.

const WALKS := {"cave": "", "G1": "grotto", "F1": "flooded", "D1": "deep"}
const DIETS := {"old": ["old"], "common": ["old", "common"], "elite": ["old", "common", "elite"], "all": ["old", "common", "elite", "rare"]}

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)  # the autoloads the classes name exist after the first frame

func _run() -> void:
	var root := "res://data"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--data="):
			root = a.trim_prefix("--data=")
		if a.begins_with("--diet="):
			only = a.trim_prefix("--diet=")
	var skills: Array = DefLoader.load_dir(root.path_join("skills"))
	var creatures := {}
	for c in DefLoader.load_dir(root.path_join("creatures")):
		creatures[c.id] = c
	var forms := FormLoader.load_species()
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/creature_areas.json"))
	var four := {}
	var world = load("res://scripts/world/world.gd")  # loaded here: its classes name autoloads, which a -s script has only after its first frame
	var all: Dictionary = world.load_rooms("res://data/rooms")
	for id in all:
		if CalibrationWalk.AREAS.has((all[id] as RoomDef).area):
			four[id] = all[id]
	for name in DIETS:
		if only != "" and only != name:
			continue
		var rooms := CalibrationWalk.diet(four, plan, DIETS[name])
		print("== diet %s: %d creatures in the four areas" % [name, rooms.values().map(func(r: RoomDef) -> int: return r.spawns.size()).reduce(func(a: int, b: int) -> int: return a + b)])
		var table := {}
		for walk in WALKS:
			table[walk] = CalibrationWalk.unlock_points(skills, creatures, rooms, WALKS[walk])
		print("skill | cave | G1 | F1 | D1   (the eat, counting from 1, at which the skill unlocks; 0 = never)")
		for d in skills.filter(func(s: SkillDef) -> bool: return s.source == "essence"):
			var row := [d.id]
			for walk in WALKS:
				row.append(int(table[walk].get(d.id, 0)))
			print(" | ".join(PackedStringArray(row.map(func(x): return str(x)))))
		for walk in WALKS:
			print("lineages at the end of each area, %s start:" % walk)
			for row in _lineages(rooms, creatures, forms, skills, WALKS[walk]):
				print("  %s | revealed %s | offered %s" % row)
	quit()

## [[area, revealed, offered], ...] at the end of each area on the walk from `start_area`.
func _lineages(rooms: Dictionary, creatures: Dictionary, forms: Dictionary, skills: Array, start_area: String) -> Array:
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	rules.start_run()
	var order := CalibrationWalk.order(rooms, start_area)
	var out: Array = []
	for i in order.size():
		var room: RoomDef = rooms[order[i]]
		for s in room.spawns:
			var c: CreatureDef = creatures[s["id"]]
			if not c.untackleable:
				CalibrationWalk.eat(rules, c)
		var next_area: String = (rooms[order[i + 1]] as RoomDef).area if i + 1 < order.size() else ""
		if next_area != room.area:
			out.append([room.area, FormOffers.revealed_lineages(forms, rules), FormOffers.offered_lineages(forms, rules)])
	rules.free()
	return out
