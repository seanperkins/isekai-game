extends GutTest
## The deeds the game already earns: guards broken, barriers and hidden things opened, strikes that hit or miss, a far switch, rooms
## entered and cleared.

class Foe extends Node2D:
	var team := "enemy"
	func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

class Barrier extends Node2D:
	var broken := 0
	func dissolve() -> void:
		broken += 1

class Hidden extends Node2D:
	var shown := 0
	func reveal() -> void:
		shown += 1

var skills: Array
var creatures := {}
var skills_by_id := {}
var rules: SkillRulesEngine
var player: Player
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
	events = []
	player = Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	EventBus.game_event.connect(_on_bus)

func after_each() -> void:
	EventBus.game_event.disconnect(_on_bus)

func _on_bus(name: String, tags: Dictionary) -> void:
	events.append([name, tags])

func _named(name: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == name)

func _enemy(id: String, at := Vector2.ZERO) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

func _cast(skill_id: String) -> void:
	var a: Ability = player._ability(skill_id)
	player.facing = 1
	a.aim = Vector2.RIGHT
	assert_true(a.activate(), "%s cast" % skill_id)

# --- a guard broken ---

func test_a_tackle_through_an_armored_front_from_behind_breaks_the_guard() -> void:
	_enemy("lizard").receive_tackle(1, true, Vector2(-10, 0))
	assert_eq(_named(Deeds.GUARD_BROKEN).size(), 1)
	assert_eq(_named(Deeds.GUARD_BROKEN)[0][1], {"source": "lizard"})

func test_a_tackle_on_a_stunned_armored_enemy_breaks_the_guard() -> void:
	var e := _enemy("lizard")
	e.status.stun(5.0)
	e.receive_tackle(1, false, Vector2(10, 0))
	assert_eq(_named(Deeds.GUARD_BROKEN).size(), 1)

func test_a_front_tackle_on_an_armored_enemy_or_any_tackle_on_an_unarmored_one_breaks_nothing() -> void:
	_enemy("lizard").receive_tackle(1, false, Vector2(10, 0))
	_enemy("toad", Vector2(40, 0)).receive_tackle(1, true, Vector2(30, 0))
	assert_eq(_named(Deeds.GUARD_BROKEN).size(), 0)

# --- a barrier and a hidden thing ---

func test_a_dissolve_that_opens_a_barrier_says_so_once_per_barrier() -> void:
	var b := Barrier.new()
	add_child_autofree(b)
	b.add_to_group("dissolvable")
	b.global_position = Vector2(30, 0)
	var far := Barrier.new()
	add_child_autofree(far)
	far.add_to_group("dissolvable")
	far.global_position = Vector2(900, 0)
	_cast("verb_wolf_fenrir")
	assert_eq(b.broken, 1)
	assert_eq(far.broken, 0)
	assert_eq(_named(Deeds.BARRIER_BROKEN).size(), 1)

func test_a_dissolve_over_nothing_says_nothing_and_is_not_a_missed_strike() -> void:
	_cast("verb_wolf_fenrir")
	assert_eq(_named(Deeds.BARRIER_BROKEN).size(), 0)
	assert_eq(_named(Deeds.SKILL_MISSED).size(), 0, "a dissolve is not counted in a perfect-hit streak")

func test_a_reveal_that_shows_a_hidden_thing_says_so_for_each() -> void:
	for x in [20, 40]:
		var h := Hidden.new()
		add_child_autofree(h)
		h.add_to_group("hidden")
		h.global_position = Vector2(x, 0)
	_cast("verb_wolf_wepwawet")
	assert_eq(_named(Deeds.HIDDEN_FOUND).size(), 2)

func test_a_reveal_with_nothing_hidden_says_nothing() -> void:
	_cast("verb_wolf_wepwawet")
	assert_eq(_named(Deeds.HIDDEN_FOUND).size(), 0)

# --- a strike that hits or misses ---

func test_a_bolt_that_finds_a_foe_is_a_hit_and_one_that_finds_none_is_a_miss() -> void:
	var foe := Foe.new()
	add_child_autofree(foe)
	foe.add_to_group("actors")
	foe.global_position = Vector2(60, 0)
	_cast("verb_wolf_cu_sith")
	assert_eq(_named(Deeds.SKILL_HIT).size(), 1)
	assert_eq(_named(Deeds.SKILL_HIT)[0][1], {"id": "verb_wolf_cu_sith"})
	assert_eq(_named(Deeds.SKILL_MISSED).size(), 0)

func test_a_bolt_into_empty_air_is_a_miss() -> void:
	_cast("verb_wolf_cu_sith")
	assert_eq(_named(Deeds.SKILL_MISSED).size(), 1)
	assert_eq(_named(Deeds.SKILL_MISSED)[0][1], {"id": "verb_wolf_cu_sith"})
	assert_eq(_named(Deeds.SKILL_HIT).size(), 0)

func test_a_non_striking_verb_is_neither() -> void:
	_cast("verb_wolf_black_dog")  # a ward
	assert_eq(_named(Deeds.SKILL_HIT).size() + _named(Deeds.SKILL_MISSED).size(), 0)

# --- a switch struck from far away ---

func test_a_switch_hit_from_far_away_says_far_and_from_near_says_nothing_more() -> void:
	var far := ShortcutSwitch.new()
	add_child_autofree(far)
	far.receive_hit(1, "physical", Vector2(400, 0))
	var near := ShortcutSwitch.new()
	add_child_autofree(near)
	near.receive_hit(1, "physical", Vector2(30, 0))
	var hits := _named(Deeds.SWITCH_HIT)
	assert_eq(hits.size(), 2)
	assert_eq(hits[0][1], {"far": true})
	assert_eq(hits[1][1], {})

# --- rooms ---

func _game():
	Game.launch_override = {"headless": true, "args": ["--skip-opening"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	return game

func _count(event: String, tags := {}) -> int:
	return SkillRules.condition_value({"kind": "counter", "event": event, "tags": tags, "n": 1})

func test_the_first_room_and_every_room_after_says_where_it_is() -> void:
	var game = await _game()
	var first: String = game.world.current_id
	assert_eq(_count(Deeds.ROOM_ENTERED, {"room": first}), 1, "the start room")
	var other := "C2" if first != "C2" else "C1"
	game.world.enter(other)
	await wait_physics_frames(2)
	assert_eq(_count(Deeds.ROOM_ENTERED, {"room": other, "area": game.world.rooms[other].area}), 1)

func test_downing_the_last_enemy_of_a_room_clears_it_alone() -> void:
	var game = await _game()
	var enemies: Array = game.world.room.get_children().filter(func(n: Node) -> bool: return n is Enemy)
	assert_gt(enemies.size(), 1, "the start room has enemies")
	for i in enemies.size() - 1:
		enemies[i].receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	assert_eq(_count(Deeds.ROOM_CLEARED), 0, "one is still standing")
	enemies[enemies.size() - 1].receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	assert_eq(_count(Deeds.ROOM_CLEARED, {"alone": true, "room": game.world.current_id}), 1)

func test_a_room_cleared_with_an_ally_beside_you_is_not_alone() -> void:
	var game = await _game()
	var ally := Node2D.new()
	game.add_child(ally)
	ally.add_to_group("verb_allies")
	for n in game.world.room.get_children():
		if n is Enemy:
			n.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	assert_eq(_count(Deeds.ROOM_CLEARED, {"room": game.world.current_id}), 1)
	assert_eq(_count(Deeds.ROOM_CLEARED, {"alone": true}), 0)

func test_a_room_stays_cleared_when_something_falls_after_it() -> void:
	var game = await _game()
	for n in game.world.room.get_children():
		if n is Enemy:
			n.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	var late: Node2D = game._spawn("bat", game.player.global_position + Vector2(200, -40))
	game.world.room.add_child(late)
	late.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	assert_eq(_count(Deeds.ROOM_CLEARED, {"room": game.world.current_id}), 1)

func test_a_room_is_cleared_once_however_many_fall_at_once() -> void:
	var game = await _game()
	for n in game.world.room.get_children():
		if n is Enemy:
			n.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(3)
	assert_eq(_count(Deeds.ROOM_CLEARED, {"room": game.world.current_id}), 1)
