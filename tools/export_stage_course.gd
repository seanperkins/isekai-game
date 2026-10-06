extends SceneTree
## Writes tools/art/stage_course.json: the movement sandbox's course as data, in game pixels (x right, y DOWN, so a ledge above the floor has a negative y), for
## the 3D photo stage (tools/art/blender/stage_review.py) to build in Blender. tests/test_stage_course.gd keeps it equal to MovementSandbox's constants. Run:
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/export_stage_course.gd

const PATH := "res://tools/art/stage_course.json"

func _init() -> void:
	var course := {
		"y_axis": "down",
		"floor": _rect(MovementSandbox.FLOOR),
		"walls": MovementSandbox.WALLS.map(_rect),
		"ledges": MovementSandbox.LEDGES.map(_rect),
		"tunnel": _rect(MovementSandbox.TUNNEL),
		"shaft_wall": _rect(MovementSandbox.SHAFT_WALL),
		"crawl_pillar": _rect(MovementSandbox.CRAWL_PILLAR),
		"crawl_slab": _rect(MovementSandbox.CRAWL_SLAB),
		"slick_block": _rect(MovementSandbox.SLICK_BLOCK),
		"slick_ceiling": _rect(MovementSandbox.SLICK_CEILING),
		"step_low": _rect(MovementSandbox.STEP_LOW),
		"oneway_ledge": _rect(MovementSandbox.ONEWAY_LEDGE),
		"dummy": _rect(MovementSandbox.DUMMY),
		"start": [MovementSandbox.START.x, MovementSandbox.START.y],
	}
	var lines: Array = []
	for key: String in course:
		lines.append("\t%s: %s" % [JSON.stringify(key), JSON.stringify(course[key])])
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % PATH)
		quit(1)
		return
	f.store_string("{\n%s\n}\n" % ",\n".join(lines))
	f.close()
	print("wrote %s" % PATH)
	quit(0)

func _rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]
