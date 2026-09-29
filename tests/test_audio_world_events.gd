extends GutTest
## Enemies and world objects say what happened; they never name a sound.

var seen: Array = []
var skills_by_id := {}
var creatures := {}

func _record(n: String, t: Dictionary) -> void:
	seen.append([n, t])

func before_each() -> void:
	seen = []
	EventBus.world_event.connect(_record)
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func after_each() -> void:
	EventBus.world_event.disconnect(_record)

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = Vector2(40, 20)
	e.set_physics_process(false)
	return e

func test_a_hit_says_where_it_landed() -> void:
	var e := _enemy("toad")
	e.receive_hit(1, "physical")
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], "enemy_hit")
	assert_eq(seen[0][1]["pos"], Vector2(40, 20))

func test_a_kill_says_who_died_and_a_dead_enemy_is_not_hit_again() -> void:
	var e := _enemy("bat")
	e.receive_hit(999, "physical")
	var names := seen.map(func(x): return x[0])
	assert_has(names, "enemy_died")
	var died: Array = seen.filter(func(x): return x[0] == "enemy_died")[0]
	assert_eq(died[1]["id"], "bat")
	assert_eq(died[1]["pos"], Vector2(40, 20))
	seen = []
	e.receive_hit(1, "physical")
	assert_eq(seen, [])

func test_reading_a_tablet_says_so() -> void:
	var t := Tablet.new()
	t.setup({"id": "t1", "title": "T", "text": "words", "hint": "", "pos": Vector2(10, 20)}, {})
	add_child_autofree(t)
	t.interact(autofree(Player.new()))
	assert_eq(seen.map(func(x): return x[0]), ["tablet_read"])
	assert_eq(seen[0][1]["pos"], Vector2(10, 20))

func test_opening_a_switch_says_so() -> void:
	var s := ShortcutSwitch.new()
	s.setup({"shortcut": "a", "pos": Vector2(5, 6)}, {})
	add_child_autofree(s)
	s.open()
	assert_eq(seen.map(func(x): return x[0]), ["switch_opened"])
	assert_eq(seen[0][1]["pos"], Vector2(5, 6))

func test_soaking_in_a_glow_pool_says_so() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	var player := Player.new()
	player.setup(rules, compendium, creature_list, func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	rules.start_run()
	seen = []
	var pool := GlowPool.new()
	pool.setup({"id": "p1", "pos": Vector2(7, 8)}, {})
	add_child_autofree(pool)
	pool.interact(player)
	assert_true(seen.any(func(x): return x[0] == "pool_rested" and x[1]["pos"] == Vector2(7, 8)))
