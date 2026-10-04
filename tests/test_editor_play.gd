extends GutTest
## Play from the editor: the real game on the working rooms, sandboxed from the real progress, and back.

var model: RoomEditModel
var game: Game

func before_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func after_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	get_tree().paused = false
	SkillRules.reset_run()
	Announcer.queue.clear()
	Compendium.progress.sanitize(["C1"])  # forget any pool a test attuned (and save that)
	var scene := get_tree().current_scene
	if scene != null:
		scene.queue_free()
		get_tree().current_scene = null

func _play(room_id := "C2", pos := Vector2(200, 250)) -> Game:
	Game.play_request = {"rooms": model.rooms, "room": room_id, "pos": pos}
	Game.editor_resume = {"model": model, "room": room_id, "view": {"zoom": 2.0}}
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	return game

func _key(code: Key, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	return ev

func test_the_request_starts_the_world_at_the_spot_on_the_edited_geometry_and_is_cleared() -> void:
	model.add_solid("C2", Vector2(400, 200), Vector2(480, 216))
	await _play("C2", Vector2(200, 250))
	assert_eq(Game.play_request, {}, "consumed")
	assert_eq(game.world.current_id, "C2")
	assert_same(game.world.rooms, model.rooms, "the world runs on the working set")
	var rect: Rect2 = model.rooms["C2"].world_rect()
	assert_almost_eq(game.player.global_position, rect.position + Vector2(200, 250), Vector2(4, 4))
	assert_true((game.world.rooms["C2"] as RoomDef).solids.has(Rect2(400, 200, 80, 16)))

func test_without_a_request_the_game_is_unchanged() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game.world.current_id, "C1")
	assert_same(game.world.ctx["progress"], Compendium.progress)

func test_the_play_world_has_its_own_progress_and_the_real_one_is_untouched() -> void:
	var visited_before: Array = Compendium.progress.visited.duplicate()
	var shortcuts_before: Array = Compendium.progress.shortcuts.duplicate()
	await _play("C2")
	var progress = game.world.ctx["progress"]
	assert_not_null(progress)
	assert_not_same(progress, Compendium.progress)
	assert_null(progress.profile, "no profile: it saves nothing")
	game.world.enter("C1")
	game.world.enter("C2")
	progress.open_shortcut("c6_drop")
	assert_true(progress.is_open("c6_drop"))
	assert_eq(Compendium.progress.visited, visited_before)
	assert_eq(Compendium.progress.shortcuts, shortcuts_before)

func test_a_death_returns_to_the_editor_without_the_menu_and_the_model_is_unchanged() -> void:
	Compendium.progress.attune("G1")  # the real progress has a second pool: given to the Run it would open the menu
	await _play("C2")
	var menus := [0]
	game.run.goddess_needed.connect(func(_model: GoddessModel, _line: String) -> void: menus[0] += 1)
	var before := RoomEditModel.copy_room(model.rooms["C2"])
	game.player.health.take_hit(999, "physical")
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.6)
	assert_eq(menus[0], 0)
	var scene := get_tree().current_scene
	assert_true(scene is RoomEditor, "back in the editor, not a reloaded game")
	assert_same((scene as RoomEditor).model, model, "the whole model came back")
	assert_true(RoomEditModel.same_room(before, model.rooms["C2"]))
	assert_null(Game.editor_resume, "consumed by the editor")

func test_f5_returns_to_the_editor_even_while_the_skill_screen_pauses_the_tree() -> void:
	await _play("C2")
	get_tree().paused = true
	get_viewport().push_input(_key(KEY_F5))
	await wait_seconds(0.3)
	assert_false(get_tree().paused, "unpaused on the way out")
	assert_true(get_tree().current_scene is RoomEditor)

func test_f5_is_ignored_on_key_repeat_and_while_the_death_card_shows() -> void:
	await _play("C2")
	get_viewport().push_input(_key(KEY_F5, true))
	await wait_seconds(0.3)
	assert_false(get_tree().current_scene is RoomEditor, "an echo does nothing")
	game.player.health.take_hit(999, "physical")
	await wait_process_frames(3)
	assert_true(game.run.death_card_visible())
	get_viewport().push_input(_key(KEY_F5))
	await wait_process_frames(3)
	assert_false(get_tree().current_scene is RoomEditor, "F5 does nothing under the death card")

# --- the kit and open shortcuts ---

func _request(extra := {}) -> void:
	Game.play_request = {"rooms": model.rooms, "room": "C6", "pos": Vector2(120, 250)}
	for k in extra:
		Game.play_request[k] = extra[k]
	Game.editor_resume = {"model": model, "room": "C6", "view": {}}
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)

func test_a_request_without_kit_or_open_shortcuts_still_plays() -> void:
	_request()
	await wait_physics_frames(3)
	assert_eq(game.world.current_id, "C6")
	assert_false(SkillRules.owned().has("wall_cling"))

func test_a_kit_starts_the_player_with_the_skills_and_never_touches_the_compendium() -> void:
	# the suite's profile persists between tests: start from slots that are really UNKNOWN, so a grant would show
	var kept := {}
	for id in ["leap", "wall_cling"]:
		kept[id] = Compendium.model.state(id)
		Compendium.model._states[id] = CompendiumModel.State.UNKNOWN
	var leap_before := Compendium.model.state("leap")
	var cling_before := Compendium.model.state("wall_cling")
	_request({"kit": {"skills": ["leap", "wall_cling"]}})
	await wait_physics_frames(3)
	assert_true(SkillRules.owned().has("wall_cling"))
	assert_true(SkillRules.owned().has("leap"))
	assert_eq(Compendium.model.state("leap"), leap_before, "the kit grant raises no Compendium slot")
	assert_eq(Compendium.model.state("wall_cling"), cling_before)
	assert_eq([leap_before, cling_before], [CompendiumModel.State.UNKNOWN, CompendiumModel.State.UNKNOWN])
	for id in kept:
		Compendium.model._states[id] = kept[id]

func test_without_open_shortcuts_the_entry_room_has_its_gate_and_its_switch() -> void:
	_request()
	await wait_physics_frames(3)
	assert_eq(get_tree().get_nodes_in_group("gate_c6_drop").size(), 1)
	assert_gt(get_tree().get_nodes_in_group("actors").filter(func(n): return n is ShortcutSwitch).size(), 0)

func test_open_shortcuts_leaves_the_entry_room_with_neither_gate_nor_switch() -> void:
	_request({"open_shortcuts": true})
	await wait_physics_frames(3)
	assert_eq(get_tree().get_nodes_in_group("gate_c6_drop").size(), 0)
	assert_eq(get_tree().get_nodes_in_group("actors").filter(func(n): return n is ShortcutSwitch).size(), 0)
	assert_true(game.world.ctx["progress"].is_open("c6_drop"))

func test_open_shortcuts_never_reaches_the_real_progress() -> void:
	var before: Array = Compendium.progress.shortcuts.duplicate()
	_request({"open_shortcuts": true})
	await wait_physics_frames(3)
	assert_eq(Compendium.progress.shortcuts, before)

# --- the sandbox check ---

func after_all() -> void:
	RoomEditor.sandbox_root = ""

func test_in_sandbox_is_a_directory_prefix_test() -> void:
	var root := "/x/.tmp/editor-home"
	assert_true(RoomEditor.in_sandbox("/x/.tmp/editor-home/Library/Application Support/Godot/app_userdata/Slime", root))
	assert_true(RoomEditor.in_sandbox("/x/.tmp/editor-home", root))
	assert_true(RoomEditor.in_sandbox("/x/.tmp/editor-home/", root))
	assert_false(RoomEditor.in_sandbox("/x/.tmp/editor-home2/Library", root), "a sibling that shares the prefix")
	assert_false(RoomEditor.in_sandbox("/Users/sean/Library/Application Support/Godot/app_userdata/Slime", root))
	assert_false(RoomEditor.in_sandbox("/x/.tmp/editor-home/Library", ""), "an empty root is never a sandbox")

func test_the_suites_own_home_is_not_the_editor_sandbox() -> void:
	RoomEditor.sandbox_root = ""
	assert_false(RoomEditor.sandbox_ok(), "the suite runs with HOME=.tmp/gdhome: Play must refuse there")

func test_an_injected_root_is_trusted_for_the_editors_own_tests() -> void:
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	assert_true(RoomEditor.sandbox_ok())
	RoomEditor.sandbox_root = "/nowhere/.tmp/editor-home"
	assert_false(RoomEditor.sandbox_ok())
	RoomEditor.sandbox_root = ""

# --- the whole round trip ---

func test_the_editor_plays_and_returns_and_save_after_the_round_trip_writes_the_edit() -> void:
	Game.editor_resume = null
	var ed: RoomEditor = load("res://scenes/room_editor.tscn").instantiate()
	add_child_autofree(ed)
	await wait_process_frames(3)
	var kept := ed.model
	ed.open_room("C2")
	ed.model.add_solid("C2", Vector2(400, 200), Vector2(480, 216))
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	assert_eq(ed.play_error(Vector2(200, 100)), "")
	ed.play(Vector2(200, 100))
	ed.queue_free()
	await wait_process_frames(3)
	await wait_physics_frames(3)
	var g := get_tree().current_scene as Game
	assert_not_null(g, "the real game")
	assert_eq(g.world.current_id, "C2")
	assert_true((g.world.rooms["C2"] as RoomDef).solids.has(Rect2(400, 200, 80, 16)), "the unsaved edit is in the played room")
	g.return_to_editor()
	await wait_seconds(0.5)
	var back := get_tree().current_scene as RoomEditor
	assert_not_null(back)
	assert_same(back.model, kept)
	assert_eq(back.room_id, "C2")
	assert_true(back.model.dirty.has("C2"), "the dirty set survived")
	back.save_dir = "res://.tmp/editor_roundtrip_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(back.save_dir))
	back.save()
	var reloaded := ResourceLoader.load("%s/C2.tres" % back.save_dir, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_true(reloaded.solids.has(Rect2(400, 200, 80, 16)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C2.tres" % back.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(back.save_dir))
	RoomEditor.sandbox_root = ""
