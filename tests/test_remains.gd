extends GutTest
## What a life carried when it died waits where it fell: saved with the world, one bundle, gone after three more deaths unrecovered.

class FakeBody extends Node2D:
	var got: Array = []
	var refuses: Array = []
	func collect_part(id: String) -> bool:
		if refuses.has(id):
			return false
		got.append(id)
		return true

var dir: String
var parts := {}

func before_all() -> void:
	parts = PartLoader.load_all()

func before_each() -> void:
	dir = "user://test_remains_%d" % Time.get_ticks_usec()

func after_each() -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)
	if Compendium.progress != null:
		Compendium.progress.remains = {}

func _profile() -> Profile:
	var p := Profile.new(dir.path_join("profile.json"))
	p.reload()
	return p

# --- the record ---

func test_a_death_with_parts_leaves_remains_where_it_fell() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C2", Vector2(120, 80), ["ribs", "claw"])
	assert_eq(w.remains["room"], "C2")
	assert_eq(w.remains["pos"], [120.0, 80.0])
	assert_eq(w.remains["parts"], ["ribs", "claw"])
	assert_eq(w.remains["deaths_left"], WorldProgress.REMAINS_DEATHS)

func test_a_death_with_nothing_leaves_nothing_and_keeps_the_older_remains() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C2", Vector2(1, 2), ["ribs"])
	w.leave_remains("C3", Vector2(3, 4), [])
	assert_eq(w.remains["room"], "C2")
	assert_eq(w.remains["parts"], ["ribs"])
	var none := WorldProgress.new()
	none.leave_remains("C3", Vector2.ZERO, [])
	assert_eq(none.remains, {})

func test_a_second_death_with_parts_replaces_the_remains() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C2", Vector2(1, 2), ["ribs"])
	w.note_death_unrecovered()
	w.leave_remains("C3", Vector2(3, 4), ["skull"])
	assert_eq(w.remains["room"], "C3")
	assert_eq(w.remains["parts"], ["skull"])
	assert_eq(w.remains["deaths_left"], WorldProgress.REMAINS_DEATHS, "the new bundle starts fresh")

func test_remains_vanish_after_three_unrecovered_deaths() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C2", Vector2(1, 2), ["ribs"])
	w.note_death_unrecovered()
	w.note_death_unrecovered()
	assert_false(w.remains.is_empty(), "two deaths on, still there")
	w.note_death_unrecovered()
	assert_eq(w.remains, {})

func test_an_unrecovered_death_with_no_remains_changes_nothing() -> void:
	var w := WorldProgress.new()
	w.note_death_unrecovered()
	assert_eq(w.remains, {})

func test_taking_the_remains_returns_them_once_and_clears_them() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C2", Vector2(1, 2), ["ribs"])
	assert_eq(w.take_remains()["parts"], ["ribs"])
	assert_eq(w.remains, {})
	assert_eq(w.take_remains(), {})

func test_keeping_some_of_the_remains_saves_what_is_left() -> void:
	var w := WorldProgress.new(_profile())
	w.leave_remains("C2", Vector2(1, 2), ["ribs", "cocoon:bat"])
	w.keep_remains(["cocoon:bat"])
	assert_eq(w.remains["parts"], ["cocoon:bat"])
	assert_eq(w.remains["deaths_left"], WorldProgress.REMAINS_DEATHS, "the clock is not reset or spent")
	assert_eq(WorldProgress.new(_profile()).remains["parts"], ["cocoon:bat"])

func test_keeping_nothing_clears_the_remains_and_keeping_with_none_does_nothing() -> void:
	var w := WorldProgress.new()
	w.keep_remains(["ribs"])
	assert_eq(w.remains, {})
	w.leave_remains("C2", Vector2(1, 2), ["ribs"])
	w.keep_remains([])
	assert_eq(w.remains, {})

func test_remains_survive_a_reload_and_so_does_their_clearing() -> void:
	var p := _profile()
	WorldProgress.new(p).leave_remains("C2", Vector2(120, 80), ["ribs", "moonstone"])
	var again := WorldProgress.new(_profile())
	assert_eq(again.remains["room"], "C2")
	assert_eq(again.remains["parts"], ["ribs", "moonstone"])
	assert_eq(again.remains["pos"], [120.0, 80.0])
	assert_eq(again.remains["deaths_left"], WorldProgress.REMAINS_DEATHS)
	again.take_remains()
	assert_eq(WorldProgress.new(_profile()).remains, {})

func test_the_countdown_survives_a_reload() -> void:
	WorldProgress.new(_profile()).leave_remains("C2", Vector2.ZERO, ["ribs"])
	var w := WorldProgress.new(_profile())
	w.note_death_unrecovered()
	assert_eq(WorldProgress.new(_profile()).remains["deaths_left"], WorldProgress.REMAINS_DEATHS - 1)

func test_a_profile_with_no_remains_section_loads_empty() -> void:
	assert_eq(WorldProgress.new(_profile()).remains, {})

func test_a_malformed_remains_section_loads_empty() -> void:
	for bad in [{"room": "C2"}, {"room": 4, "pos": [1, 2], "parts": ["ribs"], "deaths_left": 3},
			{"room": "C2", "pos": [1], "parts": ["ribs"], "deaths_left": 3}, {"room": "C2", "pos": [1, 2], "parts": "ribs", "deaths_left": 3},
			{"room": "C2", "pos": ["a", 2], "parts": ["ribs"], "deaths_left": 3}, {"room": "C2", "pos": [1, 2], "parts": [4], "deaths_left": 3},
			{"room": "C2", "pos": [1, 2], "parts": ["ribs"], "deaths_left": 0}, {"room": "C2", "pos": [1, 2], "parts": [], "deaths_left": 3}]:
		var p := _profile()
		p.set_section("remains", bad)
		assert_eq(WorldProgress.new(p).remains, {}, "bad: %s" % str(bad))

func test_a_save_that_claims_more_deaths_than_remains_ever_get_is_capped() -> void:
	var p := _profile()
	p.set_section("remains", {"room": "C2", "pos": [1, 2], "parts": ["ribs"], "deaths_left": 99})
	assert_eq(WorldProgress.new(p).remains["deaths_left"], WorldProgress.REMAINS_DEATHS)

func test_a_saved_part_the_data_no_longer_holds_is_dropped() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C2", Vector2(1, 2), ["ribs", "no_such_part", "claw"])
	w.sanitize_remains(parts.keys(), ["C2"])
	assert_eq(w.remains["parts"], ["ribs", "claw"])

func test_remains_of_nothing_the_data_holds_are_dropped_whole() -> void:
	var w := WorldProgress.new(_profile())
	w.leave_remains("C2", Vector2(1, 2), ["no_such_part"])
	w.sanitize_remains(parts.keys(), ["C2"])
	assert_eq(w.remains, {})
	assert_eq(WorldProgress.new(_profile()).remains, {}, "and the save is cleaned too")

func test_remains_in_a_room_the_data_no_longer_holds_are_dropped() -> void:
	var w := WorldProgress.new()
	w.leave_remains("GONE", Vector2(1, 2), ["ribs"])
	w.sanitize_remains(parts.keys(), ["C2"])
	assert_eq(w.remains, {})

# --- the bundle on the floor ---

func _body(at := Vector2.ZERO) -> FakeBody:
	var b := FakeBody.new()
	b.position = at
	add_child_autofree(b)
	b.add_to_group("player")
	return b

func _remains(ids: Array, at: Vector2) -> Remains:
	var r := Remains.new()
	r.setup(ids, at)
	add_child_autofree(r)
	return r

func test_standing_on_the_remains_gives_every_part_back_once() -> void:
	var body := _body()
	var r := _remains(["ribs", "claw", "moonstone"], Vector2(5, 0))
	watch_signals(r)
	r._physics_process(0.016)
	r._physics_process(0.016)
	assert_eq(body.got, ["ribs", "claw", "moonstone"])
	assert_signal_emit_count(r, "recovered", 1)
	assert_true(r.is_queued_for_deletion())

func test_what_the_body_refuses_stays_in_the_remains() -> void:
	var body := _body()
	body.refuses = ["cocoon:bat"]
	var r := _remains(["ribs", "cocoon:bat"], Vector2.ZERO)
	watch_signals(r)
	r._physics_process(0.016)
	assert_eq(body.got, ["ribs"])
	assert_eq(r.parts, ["cocoon:bat"])
	assert_false(r.is_queued_for_deletion(), "what is left is still there")
	assert_signal_emit_count(r, "recovered", 1)
	assert_eq(get_signal_parameters(r, "recovered"), [["cocoon:bat"]])

func test_a_body_that_refuses_everything_takes_nothing_and_says_nothing() -> void:
	var body := _body()
	body.refuses = ["ribs", "claw"]
	var r := _remains(["ribs", "claw"], Vector2.ZERO)
	watch_signals(r)
	r._physics_process(0.016)
	r._physics_process(0.016)
	assert_eq(body.got, [])
	assert_eq(r.parts, ["ribs", "claw"])
	assert_signal_not_emitted(r, "recovered")
	assert_false(r.is_queued_for_deletion())

func test_what_was_refused_comes_later_when_the_body_has_room() -> void:
	var body := _body()
	body.refuses = ["cocoon:bat"]
	var r := _remains(["ribs", "cocoon:bat"], Vector2.ZERO)
	r._physics_process(0.016)
	body.refuses = []
	watch_signals(r)
	r._physics_process(0.016)
	assert_eq(body.got, ["ribs", "cocoon:bat"])
	assert_eq(get_signal_parameters(r, "recovered"), [[]])
	assert_true(r.is_queued_for_deletion())

func test_remains_out_of_reach_stay() -> void:
	var body := _body()
	var r := _remains(["ribs"], Vector2(PartPickup.COLLECT_RANGE + 1.0, 0))
	watch_signals(r)
	r._physics_process(0.016)
	assert_eq(body.got, [])
	assert_signal_not_emitted(r, "recovered")
	assert_false(r.is_queued_for_deletion())

func test_something_that_is_not_the_player_does_not_take_the_remains() -> void:
	var other := FakeBody.new()
	add_child_autofree(other)
	var r := _remains(["ribs"], Vector2.ZERO)
	r._physics_process(0.016)
	assert_eq(other.got, [])
	assert_false(r.is_queued_for_deletion())

# --- in the game ---

func _game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	game._progress.remains = {}
	return game

func _remains_nodes(game: Node) -> Array:
	return game.world.room.get_children().filter(func(n: Node) -> bool: return n is Remains)

func test_a_game_starting_with_stale_remains_cleans_them() -> void:
	Compendium.progress.remains = {"room": "C1", "pos": [1.0, 2.0], "parts": ["ribs", "no_such_part"], "deaths_left": 3}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game._progress.remains["parts"], ["ribs"])
	game._progress.remains = {}

func test_a_cocoon_in_the_remains_comes_back_as_a_cocoon() -> void:
	var game = await _game()
	game.player.set_species("spider")
	var here: String = game.world.current_id
	game._progress.leave_remains(here, Vector2(60, 60), ["cocoon:bat", "claw"])
	game._on_room_entered(here)
	await wait_physics_frames(2)
	var found := _remains_nodes(game)
	assert_eq(found.size(), 1)
	game.player.global_position = found[0].global_position
	await wait_physics_frames(3)
	assert_eq(game.player.inventory.cocoons(), ["bat"])
	assert_eq(game.player.inventory.carried_parts(), ["claw"])

func test_dying_with_a_cocoon_leaves_it_in_the_remains() -> void:
	var game = await _game()
	game.player.set_species("spider")
	game.player.collect_part("cocoon:bat")
	game.player.receive_hit(game.player.health.max_hp * 5, "fire")
	assert_eq(game._progress.remains["parts"], ["cocoon:bat"])

func test_a_saved_cocoon_of_a_creature_the_data_no_longer_holds_is_dropped() -> void:
	Compendium.progress.remains = {"room": "C1", "pos": [1.0, 2.0], "parts": ["cocoon:no_such_creature", "cocoon:bat", "claw"], "deaths_left": 3}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game._progress.remains["parts"], ["cocoon:bat", "claw"])
	game._progress.remains = {}

func test_dying_with_parts_leaves_them_where_you_fell_and_empties_the_pack() -> void:
	var game = await _game()
	game.player.set_species("undead")
	game.player.collect_part("ribs")
	game.player.collect_part("moonstone")
	var at: Vector2 = game.world.room.to_local(game.player.global_position)
	game.player.receive_hit(game.player.health.max_hp * 5, "fire")
	assert_true(game.player.health.is_dead())
	var r: Dictionary = game._progress.remains
	assert_eq(r["room"], game.world.current_id)
	assert_eq(r["parts"], ["ribs", "moonstone"])
	assert_almost_eq(float(r["pos"][0]), at.x, 0.5)
	assert_almost_eq(float(r["pos"][1]), at.y, 0.5)
	assert_eq(game.player.inventory.worn(), [])
	assert_eq(game.player.inventory.carried(), [])

func test_dying_with_nothing_keeps_the_older_remains_and_counts_the_death() -> void:
	var game = await _game()
	game._progress.leave_remains("C2", Vector2(1, 2), ["ribs"])
	game.player.receive_hit(game.player.health.max_hp * 5, "fire")
	assert_eq(game._progress.remains["parts"], ["ribs"])
	assert_eq(game._progress.remains["deaths_left"], WorldProgress.REMAINS_DEATHS - 1)

func test_dying_again_with_parts_replaces_the_remains() -> void:
	var game = await _game()
	game._progress.leave_remains("C2", Vector2(1, 2), ["skull"])
	game.player.collect_part("claw")
	game.player.receive_hit(game.player.health.max_hp * 5, "fire")
	assert_eq(game._progress.remains["parts"], ["claw"])
	assert_eq(game._progress.remains["room"], game.world.current_id)

func test_entering_the_room_of_your_remains_shows_them_and_collecting_returns_the_parts() -> void:
	var game = await _game()
	game.player.set_species("undead")
	var here: String = game.world.current_id
	game._progress.leave_remains(here, Vector2(60, 60), ["ribs", "moonstone"])
	game._on_room_entered(here)  # not World.enter: it frees the floor an undead body stands on this frame (see the ledger's deferred minor)
	await wait_physics_frames(2)
	var found := _remains_nodes(game)
	assert_eq(found.size(), 1)
	assert_eq(found[0].position, Vector2(60, 60))
	game.player.global_position = found[0].global_position
	await wait_physics_frames(3)
	assert_eq(game.player.inventory.worn(), ["ribs"], "the undead wear what fits")
	assert_eq(game.player.inventory.carried(), ["moonstone"])
	assert_eq(game._progress.remains, {})
	await wait_physics_frames(2)
	assert_eq(_remains_nodes(game).size(), 0)

func test_a_spider_with_full_hands_leaves_the_rest_of_its_remains_waiting() -> void:
	var game = await _game()
	game.player.set_species("spider")
	var here: String = game.world.current_id
	game.player.collect_part("cocoon:toad")
	game.player.collect_part("cocoon:lizard")
	game._progress.leave_remains(here, Vector2(60, 60), ["cocoon:bat", "cocoon:moth", "claw"])
	game._on_room_entered(here)
	await wait_physics_frames(2)
	game.player.global_position = _remains_nodes(game)[0].global_position
	await wait_physics_frames(3)
	assert_eq(game.player.inventory.carried_parts(), ["claw"])
	assert_eq(game.player.inventory.cocoons(), ["toad", "lizard"], "full: the two cocoons stay where they are")
	assert_eq(game._progress.remains["parts"], ["cocoon:bat", "cocoon:moth"], "and are still saved")
	assert_eq(_remains_nodes(game).size(), 1)

func test_the_parts_do_not_come_back_twice() -> void:
	var game = await _game()
	var here: String = game.world.current_id
	game._progress.leave_remains(here, Vector2(60, 60), ["claw"])
	game.world.enter(here)
	await wait_physics_frames(2)
	game.player.global_position = _remains_nodes(game)[0].global_position
	await wait_physics_frames(3)
	game._on_room_entered(here)  # the next life's start in this room
	await wait_physics_frames(2)
	assert_eq(_remains_nodes(game).size(), 0, "nothing is left to show")
	assert_eq(game.player.inventory.count("claw"), 1)

func test_the_remains_are_shown_once_however_often_the_room_is_announced() -> void:
	var game = await _game()
	var here: String = game.world.current_id
	game._progress.leave_remains(here, Vector2(60, 60), ["claw"])
	game._on_room_entered(here)
	game._on_room_entered(here)
	assert_eq(_remains_nodes(game).size(), 1)

func test_remains_in_another_room_are_not_shown_here() -> void:
	var game = await _game()
	var other := "C2" if game.world.current_id != "C2" else "C1"
	game._progress.leave_remains(other, Vector2(60, 60), ["claw"])
	game._on_room_entered(game.world.current_id)
	assert_eq(_remains_nodes(game).size(), 0)
	assert_false(game._progress.remains.is_empty(), "and they wait")

func test_recovered_parts_count_as_taken_again_this_life() -> void:
	var game = await _game()
	var here: String = game.world.current_id
	game._progress.leave_remains(here, Vector2(60, 60), ["moonstone"])
	game.world.enter(here)
	await wait_physics_frames(2)
	game.player.global_position = _remains_nodes(game)[0].global_position
	await wait_physics_frames(3)
	var carried := SkillRules.condition_value({"kind": "counter", "event": Deeds.ITEM_CARRIED, "tags": {}, "n": 1})
	assert_eq(carried, 1)
