extends GutTest
## The room MCP's menagerie_shot tool and the ShotRunner behind it. The real run starts a second Godot with a rendering window, so
## these tests hand it a fake runner that writes the frames a real run would.

const TMP := "res://.tmp/shot_tool_test"

var tools: RoomTools
var calls: Array = []
var creatures: Array

class FakeRunner extends RefCounted:
	var calls: Array
	var dir: String
	var code := 0
	var written := true
	func _init(p_calls: Array, p_dir: String) -> void:
		calls = p_calls
		dir = p_dir
	func run(argv: Array) -> Dictionary:
		calls.append(argv)
		var stops := argv.size() - 4  # GODOT=.., SHOTS_OUT=.., bash, script, then the stops
		var out := ""
		for a in argv:
			if str(a).begins_with("SHOTS_OUT="):
				out = str(a).trim_prefix("SHOTS_OUT=")
		if written:
			DirAccess.make_dir_recursive_absolute(out)
			for i in stops:
				var img := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
				img.fill(Color(0.2, 0.3, 0.5))
				img.save_png("%s/stop_%d.png" % [out, i])
		var log := FileAccess.open(out + ".log", FileAccess.WRITE)  # the wrapper leaves a log beside its frames
		log.store_string("log")
		log.close()
		return {"code": code, "output": "%d of %d frames" % [stops, stops] if code == 0 else "the window was fullscreen"}

var fake: FakeRunner

func before_all() -> void:
	creatures = DefLoader.load_dir("res://data/creatures")

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	calls = []
	fake = FakeRunner.new(calls, TMP)
	tools = RoomTools.new(RoomSession.new(), ShotRunner.new(fake.run, TMP))

func after_each() -> void:
	var d := DirAccess.open(TMP)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

func _images(r: Dictionary) -> Array:
	return r["content"].filter(func(c: Dictionary) -> bool: return c["type"] == "image")

func _text(r: Dictionary) -> String:
	return "\n".join(r["content"].filter(func(c: Dictionary) -> bool: return c["type"] == "text").map(func(c: Dictionary) -> String: return c["text"]))

func test_the_tool_is_listed_with_a_schema() -> void:
	var found := tools.tool_list().filter(func(t: Dictionary) -> bool: return t["name"] == "menagerie_shot")
	assert_eq(found.size(), 1)
	assert_eq(found[0]["inputSchema"]["properties"].keys(), ["creatures", "x", "scale"])

func test_a_creature_is_shown_from_just_left_of_where_it_stands() -> void:
	var r := tools.call_tool("menagerie_shot", {"creatures": ["twin_wolf_fenrir"]})
	assert_false(r["isError"], _text(r))
	assert_eq(_images(r).size(), 1)
	var x := Menagerie.x_of("twin_wolf_fenrir", creatures)
	assert_gt(x, 0.0)
	assert_eq(calls.size(), 1)
	assert_eq(calls[0].slice(4), [str(int(x - ShotRunner.VIEW_LEAD))], "the player stands left of it, so the slime is not drawn over it")

func test_raw_positions_are_used_as_given_and_combine_with_creatures() -> void:
	var r := tools.call_tool("menagerie_shot", {"x": [1000, 2500], "creatures": ["bat"]})
	assert_false(r["isError"], _text(r))
	assert_eq(_images(r).size(), 3)
	assert_eq(calls[0].slice(4), ["170", "1000", "2500"], "the creature's stop comes first, then the positions")

func test_the_images_are_scaled_and_each_has_a_caption() -> void:
	var r := tools.call_tool("menagerie_shot", {"x": [1000], "scale": 0.5})
	var img := Image.new()
	assert_eq(img.load_png_from_buffer(Marshalls.base64_to_raw(_images(r)[0]["data"])), OK)
	assert_eq(img.get_size(), Vector2i(640, 360))
	assert_string_contains(_text(r), "x 1000")
	var full := tools.call_tool("menagerie_shot", {"x": [1000], "scale": 1.0})
	img.load_png_from_buffer(Marshalls.base64_to_raw(_images(full)[0]["data"]))
	assert_eq(img.get_size(), Vector2i(1280, 720))

func test_nothing_to_show_or_too_much_is_refused_and_nothing_runs() -> void:
	assert_true(tools.call_tool("menagerie_shot", {})["isError"], "no creature and no x")
	assert_true(tools.call_tool("menagerie_shot", {"x": [1, 2, 3, 4, 5]})["isError"], "more than four")
	assert_true(tools.call_tool("menagerie_shot", {"creatures": ["bat", "toad"], "x": [1, 2, 3]})["isError"], "creatures and x together make more than four")
	var unknown := tools.call_tool("menagerie_shot", {"creatures": ["twin_nothing"]})
	assert_true(unknown["isError"])
	assert_string_contains(_text(unknown), "twin_nothing")
	var water := tools.call_tool("menagerie_shot", {"creatures": ["water_pool"]})
	assert_true(water["isError"], "the water pool is terrain and is not in the room")
	assert_true(tools.call_tool("menagerie_shot", {"x": [-5]})["isError"])
	assert_true(tools.call_tool("menagerie_shot", {"x": [999999]})["isError"])
	assert_true(tools.call_tool("menagerie_shot", {"x": ["1000; rm -rf /"]})["isError"])
	assert_true(tools.call_tool("menagerie_shot", {"x": [1000], "scale": 0.0})["isError"])
	assert_eq(calls.size(), 0, "none of those started a Godot")

func test_a_failed_run_reports_why_and_returns_no_images() -> void:
	fake.code = 1
	var r := tools.call_tool("menagerie_shot", {"x": [1000]})
	assert_true(r["isError"])
	assert_string_contains(_text(r), "the window was fullscreen")
	assert_eq(_images(r).size(), 0)

func test_a_run_that_wrote_no_frames_is_an_error_not_an_empty_answer() -> void:
	fake.written = false
	var r := tools.call_tool("menagerie_shot", {"x": [1000]})
	assert_true(r["isError"])
	assert_eq(_images(r).size(), 0)

func test_the_command_is_an_argv_with_numbers_only() -> void:
	var argv := ShotRunner.command("/Applications/Godot.app/Contents/MacOS/Godot", "/out/run_1", "/proj/tools/menagerie_shots.sh", [1000, 2500])
	assert_eq(argv, ["GODOT=/Applications/Godot.app/Contents/MacOS/Godot", "SHOTS_OUT=/out/run_1", "bash", "/proj/tools/menagerie_shots.sh", "1000", "2500"])

func test_each_call_gets_its_own_directory_and_leaves_nothing_behind() -> void:
	tools.call_tool("menagerie_shot", {"x": [1000]})
	tools.call_tool("menagerie_shot", {"x": [1000]})
	var outs := calls.map(func(argv: Array) -> String: return str(argv[1]).trim_prefix("SHOTS_OUT="))
	assert_ne(outs[0], outs[1], "two calls never share frames")
	var abs_tmp := ProjectSettings.globalize_path(TMP)
	for out: String in outs:
		assert_true(out.begins_with(abs_tmp), "frames are under the tool's own root")
	assert_eq(DirAccess.get_directories_at(abs_tmp).size(), 0, "the frame directories are removed")
	assert_eq(DirAccess.get_files_at(abs_tmp).size(), 0, "and so are the logs")

func test_a_failed_run_leaves_nothing_behind_either() -> void:
	fake.code = 1
	tools.call_tool("menagerie_shot", {"x": [1000]})
	assert_eq(DirAccess.get_directories_at(ProjectSettings.globalize_path(TMP)).size(), 0)
	assert_eq(DirAccess.get_files_at(ProjectSettings.globalize_path(TMP)).size(), 0)

func test_frames_left_by_an_earlier_run_are_never_returned() -> void:
	var stale := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	stale.save_png(ProjectSettings.globalize_path(TMP) + "/stop_0.png")  # the old fixed place
	fake.written = false
	var r := tools.call_tool("menagerie_shot", {"x": [1000]})
	assert_true(r["isError"])
	assert_eq(_images(r).size(), 0)

func test_positions_are_whole_numbers_and_stay_inside_the_room() -> void:
	assert_true(tools.call_tool("menagerie_shot", {"x": [2500.5]})["isError"], "a fraction would be silently rounded down")
	var far := tools.call_tool("menagerie_shot", {"x": [11500]})
	assert_true(far["isError"], "past the end of the room")
	assert_string_contains(_text(far), "10")
	assert_eq(calls.size(), 0)
	assert_false(tools.call_tool("menagerie_shot", {"x": [10000]})["isError"], "inside it")

func test_the_room_width_matches_the_room_it_builds() -> void:
	var room: RoomDef = Menagerie.request(creatures)["rooms"][Menagerie.ROOM_ID]
	assert_gte(room.pixel_size().x, Menagerie.width(Menagerie.order(creatures).size()))
	assert_lt(room.pixel_size().x - Menagerie.width(Menagerie.order(creatures).size()), RoomDef.SCREEN.x, "to the screen")

func test_x_of_follows_the_rooms_order() -> void:
	var order := Menagerie.order(creatures)
	assert_eq(Menagerie.x_of(order[0].id, creatures), Menagerie.spawn_x(0))
	assert_eq(Menagerie.x_of(order[7].id, creatures), Menagerie.spawn_x(7))
	assert_eq(Menagerie.x_of("nothing", creatures), -1.0)
	assert_eq(Menagerie.x_of("water_pool", creatures), -1.0)
