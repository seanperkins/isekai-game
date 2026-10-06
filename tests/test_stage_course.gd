extends GutTest
## The 3D stage's course is the movement sandbox's own: tools/art/stage_course.json must say what MovementSandbox's constants say, so a ledge moved in the
## game fails here until the course is exported again (godot --headless -s tools/export_stage_course.gd).

const COURSE_PATH := "res://tools/art/stage_course.json"

func _course() -> Dictionary:
	var f := FileAccess.open(COURSE_PATH, FileAccess.READ)
	assert_not_null(f, "the course is exported: godot --headless -s tools/export_stage_course.gd")
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	assert_true(parsed is Dictionary, "the course is a JSON object")
	return parsed if parsed is Dictionary else {}

func _rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])

func _rects(a: Array) -> Array:
	return a.map(_rect)

func test_the_floor_and_the_walls_are_the_sandboxs() -> void:
	var c := _course()
	assert_eq(_rect(c["floor"]), MovementSandbox.FLOOR)
	assert_eq(_rects(c["walls"]), MovementSandbox.WALLS)

func test_the_ledges_are_the_sandboxs() -> void:
	assert_eq(_rects(_course()["ledges"]), MovementSandbox.LEDGES)

func test_the_obstacles_are_the_sandboxs() -> void:
	var c := _course()
	assert_eq(_rect(c["tunnel"]), MovementSandbox.TUNNEL)
	assert_eq(_rect(c["shaft_wall"]), MovementSandbox.SHAFT_WALL)
	assert_eq(_rect(c["crawl_pillar"]), MovementSandbox.CRAWL_PILLAR)
	assert_eq(_rect(c["crawl_slab"]), MovementSandbox.CRAWL_SLAB)
	assert_eq(_rect(c["slick_block"]), MovementSandbox.SLICK_BLOCK)
	assert_eq(_rect(c["slick_ceiling"]), MovementSandbox.SLICK_CEILING)
	assert_eq(_rect(c["step_low"]), MovementSandbox.STEP_LOW)
	assert_eq(_rect(c["oneway_ledge"]), MovementSandbox.ONEWAY_LEDGE)
	assert_eq(_rect(c["dummy"]), MovementSandbox.DUMMY)

func test_the_start_is_the_sandboxs() -> void:
	var s: Array = _course()["start"]
	assert_eq(Vector2(s[0], s[1]), MovementSandbox.START)

func test_the_course_says_which_way_is_up() -> void:
	assert_eq(_course()["y_axis"], "down", "game y points down: a ledge top above the floor has a negative y")
