extends SceneTree
## Prints, per skill that unlocks from eating, the eat at which it unlocks on four walks of the shipped map, and the level each
## absorbed-levelled skill has reached by the end of each area (Cave-start walk). Read-only.
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/calibrate_essences.gd
## An optional `-- --data=res://some/dir` reads skills and creatures from `<dir>/skills` and `<dir>/creatures` instead.

## The twenty-three rooms the game shipped with: a room the editor adds later is not part of the calibration.
const SHIPPED := ["C1", "C2", "C3", "C4", "C5", "C6", "G1", "G2", "G3", "G4", "G5", "F1", "F2", "F3", "F4", "F5", "F6", "D1", "D2", "D3", "D4", "D5", "D6"]
const WALKS := {"cave": "", "G1": "grotto", "F1": "flooded", "D1": "deep"}

func _init() -> void:
	var root := "res://data"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--data="):
			root = a.trim_prefix("--data=")
	var skills: Array = DefLoader.load_dir(root.path_join("skills"))
	var creatures := {}
	for c in DefLoader.load_dir(root.path_join("creatures")):
		creatures[c.id] = c
	var rooms := {}
	for r in DefLoader.load_dir("res://data/rooms", "RoomDef"):
		if SHIPPED.has(r.id):
			rooms[r.id] = r
	var table := {}
	for walk in WALKS:
		table[walk] = CalibrationWalk.unlock_points(skills, creatures, rooms, WALKS[walk])
	print("skill | cave | G1 | F1 | D1   (the eat, counting from 1, at which the skill unlocks; 0 = never)")
	for d in skills.filter(func(s: SkillDef) -> bool: return s.source == "essence"):
		var row := [d.id]
		for walk in WALKS:
			row.append(int(table[walk].get(d.id, 0)))
		print(" | ".join(PackedStringArray(row.map(func(x): return str(x)))))
	print("level reached at the end of each area, Cave-start walk (the stage-1 cap is %d)" % SkillRulesEngine.BASE_STAGE_CAP)
	var levels := CalibrationWalk.levels_by_area(skills, creatures, rooms)
	for a in CalibrationWalk.AREAS:
		var parts := [a]
		for id in levels[a]:
			parts.append("%s %d" % [id, levels[a][id]])
		print(" | ".join(PackedStringArray(parts)))
	quit()
