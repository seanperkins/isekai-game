extends SceneTree
## Records a species' scripted run over the movement sandbox's course and writes it to .tmp/stage/<species>_<script>.json (tools/movement_recorder.gd says what is in it):
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/record_movement.gd -- goblin jump_ledges
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/record_movement.gd -- all      (every species, every script it can run)

const OUT_DIR := "res://.tmp/stage"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = []  # [species, script]
	if args.size() == 1 and args[0] == "all":
		for species: String in MovementRecorder.SCRIPTS_FOR:
			for script_name: String in MovementRecorder.scripts_for(species):
				jobs.append([species, script_name])
	elif args.size() == 2:
		jobs.append([args[0], args[1]])
	else:
		push_error("usage: -- <species> <script> | all")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var rec := MovementRecorder.new()
	root.add_child(rec)
	await process_frame  # the tree is up before the first physics frame is awaited
	var failed := false
	for job: Array in jobs:
		var r: Dictionary = await rec.record(job[0], job[1])
		if r.is_empty():
			push_error("cannot record %s %s" % [job[0], job[1]])
			failed = true
			continue
		var path := "%s/%s_%s.json" % [OUT_DIR, job[0], job[1]]
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
			failed = true
			continue
		f.store_string(JSON.stringify(r))
		f.close()
		print("%s: %d ticks" % [path, r["ticks"].size()])
	quit(1 if failed else 0)
