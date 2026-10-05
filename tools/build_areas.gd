extends SceneTree
## Builds the new areas' rooms: `godot --headless -s tools/build_areas.gd` (see tools/build_areas.sh). With `-- --check` it writes nothing and
## exits 1 when a room would change. It refuses to write a world that has a WorldValidator error or a RoomLint finding.

func _initialize() -> void:
	# The rooms' classes name autoloads, which a -s script has only after its first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var builder = load("res://tools/areas/area_builder.gd")
	var check := "--check" in OS.get_cmdline_user_args()
	var world: Dictionary = builder.build()
	var problems: PackedStringArray = builder.problems(world)
	if not problems.is_empty():
		print("build_areas: the world has %d problems, nothing written:" % problems.size())
		for p in problems:
			print("  " + p)
		quit(1)
		return
	var ids: Array = builder.stale(world)
	if check:
		print("build_areas: %d rooms would change%s" % [ids.size(), (": " + ", ".join(ids)) if not ids.is_empty() else ""])
		quit(1 if not ids.is_empty() else 0)
		return
	builder.write(world, ids)
	print("build_areas: wrote %d rooms%s" % [ids.size(), (": " + ", ".join(ids)) if not ids.is_empty() else ""])
	quit(0)
