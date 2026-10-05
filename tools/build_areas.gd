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
	var orphans: Array = builder.orphans(world, builder.modules())
	if check:
		print("build_areas: %d rooms would change%s; %d orphans%s" % [ids.size(), (": " + ", ".join(ids)) if not ids.is_empty() else "",
			orphans.size(), (": " + ", ".join(orphans)) if not orphans.is_empty() else ""])
		quit(1 if not (ids.is_empty() and orphans.is_empty()) else 0)
		return
	var errors: PackedStringArray = builder.write(world, ids)
	if not errors.is_empty():
		for e in errors:
			print("build_areas: " + e)
		quit(1)
		return
	builder.remove(orphans)
	print("build_areas: wrote %d rooms%s, removed %d orphans%s" % [ids.size(), (": " + ", ".join(ids)) if not ids.is_empty() else "",
		orphans.size(), (": " + ", ".join(orphans)) if not orphans.is_empty() else ""])
	quit(0)
