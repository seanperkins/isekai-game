extends GutTest
## Holding a room against what is in it, and keeping the village: two deeds that are about time and about a whole area.

var skills: Array
var creatures := {}
var skills_by_id := {}
var rules: SkillRulesEngine
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	rules.start_run()
	events = []
	EventBus.game_event.connect(_on_bus)

func after_each() -> void:
	EventBus.game_event.disconnect(_on_bus)

func _on_bus(name: String, tags: Dictionary) -> void:
	events.append([name, tags])

func _named(name: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == name)

func _enemy(id: String, parent: Node) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	parent.add_child(e)
	return e

# --- RoomHold ---

func _hold(room: String) -> RoomHold:
	var h := RoomHold.new()
	h.setup({"id": room, "pos": Vector2.ZERO}, {})
	h.ledger = rules
	add_child_autofree(h)
	return h

func test_twenty_seconds_with_a_threat_alive_is_a_hold_and_nineteen_is_not() -> void:
	var h := _hold("HOLD1")
	h.step(19.0, true)
	assert_eq(_named(Deeds.ROOM_HELD).size(), 0)
	h.step(1.0, true)
	assert_eq(_named(Deeds.ROOM_HELD), [[Deeds.ROOM_HELD, {"room": "HOLD1"}]])

func test_a_room_is_held_once_per_life_and_seconds_without_a_threat_count_for_nothing() -> void:
	var h := _hold("HOLD1")
	h.step(100.0, false)
	assert_eq(_named(Deeds.ROOM_HELD).size(), 0)
	h.step(25.0, true)
	h.step(25.0, true)
	assert_eq(_named(Deeds.ROOM_HELD).size(), 1)

func test_a_room_held_earlier_this_life_pays_nothing_when_it_is_built_again() -> void:
	rules.handle_event(Deeds.ROOM_HELD, {"room": "HOLD1"})
	var h := _hold("HOLD1")
	h.step(30.0, true)
	assert_eq(_named(Deeds.ROOM_HELD).size(), 0)

func test_a_hold_counts_a_live_threat_among_the_rooms_enemies_and_not_a_downed_one() -> void:
	var room := Node2D.new()
	add_child_autofree(room)
	var h := RoomHold.new()
	h.setup({"id": "HOLD1", "pos": Vector2.ZERO}, {})
	room.add_child(h)
	assert_false(h.threat_alive(), "an empty room")
	var e := _enemy("toad", room)
	assert_true(h.threat_alive())
	e.status.state = EnemyStatus.DOWNED
	assert_false(h.threat_alive(), "a downed foe is no threat")

func test_the_room_builder_adds_a_hold_only_to_a_room_tagged_hold() -> void:
	var plain := AreaKit.room("HOLD2", "forest", Vector2i(40, 40))
	var tagged := AreaKit.room("HOLD3", "forest", Vector2i(40, 41))
	AreaKit.tag(tagged, "hold")
	var a := RoomBuilder.build_room(plain, {})
	var b := RoomBuilder.build_room(tagged, {})
	add_child_autofree(a)
	add_child_autofree(b)
	assert_eq(a.get_children().filter(func(n: Node) -> bool: return n is RoomHold).size(), 0)
	var holds := b.get_children().filter(func(n: Node) -> bool: return n is RoomHold)
	assert_eq(holds.size(), 1)
	assert_eq(holds[0].id, "HOLD3")

# --- VillageWatch ---

func _watch() -> VillageWatch:
	var w := VillageWatch.new()
	w.emit_deed = func(event: String, tags: Dictionary) -> void: events.append([event, tags])
	return w

func _visit(w: VillageWatch, ids: Array) -> void:
	for id in ids:
		w.enter(id, "village")

func test_leaving_after_a_clean_visit_to_the_yard_keeps_the_village() -> void:
	var w := _watch()
	_visit(w, ["VI1", "VI3"])
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1)
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 0, "two of the four rooms")

func test_every_room_seen_with_nobody_alerted_is_a_visit_unseen() -> void:
	var w := _watch()
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.enter("VI5", "swamp")
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 1)
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1)

func test_a_kill_spoils_kept_and_an_alert_spoils_unseen() -> void:
	var w := _watch()
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.killed()
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 0)
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 1, "a kill is not an alert")
	events.clear()
	var v := _watch()
	_visit(v, ["VI1", "VI2", "VI3", "VI4"])
	v.alerted()
	v.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 0)
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1, "an alert is not a kill")

func test_a_kill_or_an_alert_outside_the_village_counts_for_nothing() -> void:
	var w := _watch()
	w.killed()
	w.alerted()
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1)
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 1)

func test_leaving_again_in_the_same_life_pays_nothing_more_and_a_new_life_resets() -> void:
	var w := _watch()
	_visit(w, ["VI1", "VI3"])
	w.enter("SW3", "swamp")
	_visit(w, ["VI3"])
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1)
	w.reset()
	_visit(w, ["VI3"])
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 2, "a new life")

func test_a_new_life_can_say_both_deeds_again() -> void:
	var w := _watch()
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.enter("SW3", "swamp")
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 1, "once a life")
	w.reset()
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 2)
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 2)

func test_stepping_into_the_village_and_straight_out_pays_nothing() -> void:
	var w := _watch()
	_visit(w, ["VI1"])
	w.enter("SW3", "swamp")
	assert_eq(events, [])

func test_the_scan_finds_an_alert_enemy_in_the_room_while_inside() -> void:
	var room := Node2D.new()
	add_child_autofree(room)
	var e := _enemy("toad", room)
	var w := _watch()
	w.scan(room)
	_visit(w, ["VI1", "VI2", "VI3", "VI4"])
	w.scan(room)
	e._alert = 1.0
	w.scan(room)
	w.enter("SW3", "swamp")
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 0)

# --- in the game ---

func test_a_life_that_begins_in_the_village_is_watched_from_its_first_room() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.world.current_id = "VI3"
	game._on_room_entered("VI3")
	game.begin_life({"kit": {}})
	game._on_room_entered("SW3")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1, "the Yard was where the life began")

func test_eating_or_webbing_a_village_creature_spoils_kept_as_killing_does() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	for event in [[Events.PREDATED, {"source": "village_goblin", "kind": "creature"}], [Deeds.PREY_COCOONED, {"creature": "cave_rat"}]]:
		events.clear()
		game._village.reset()
		game._on_room_entered("VI3")
		game._emit_game_event(event[0], event[1])
		game._on_room_entered("SW3")
		assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 0, event[0])

func test_the_game_feeds_the_village_watch_rooms_kills_and_a_new_life() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	for id in ["VI1", "VI2", "VI3", "VI4"]:
		game._on_room_entered(id)
	game._on_room_entered("SW3")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1)
	assert_eq(_named(Deeds.VILLAGE_VISITED_UNSEEN).size(), 1)
	game._village.reset()
	for id in ["VI3"]:
		game._on_room_entered(id)
	game._emit_game_event(Deeds.DEFEATED, {"source": "village_goblin"})
	game._on_room_entered("SW3")
	assert_eq(_named(Deeds.VILLAGE_KEPT).size(), 1, "a village creature was killed: spoiled")
