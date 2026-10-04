extends GutTest
## The player remembers the cause of its last hit (a creature id, "spear", or the damage type), set before `died` fires, so the
## goddess can say what killed you. (test_death_cause.gd is the creatures' death effects.)

class CauseStub extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func is_on_floor() -> bool:
		return true
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, cause: String = "") -> void:
		hits.append([raw, damage_type, cause])
	func receive_poison(_a: int, _t: int, _s: float) -> void:
		pass

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _player() -> Player:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills_by_id.values())
	var compendium := CompendiumModel.new(skills_by_id.values(), creatures.values())
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	var player := Player.new()
	player.setup(rules, compendium, creatures.values(), func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	return player

func _stub() -> CauseStub:
	var stub := CauseStub.new()
	add_child_autofree(stub)
	stub.add_to_group("player")
	return stub

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func test_the_cause_is_recorded() -> void:
	var player := _player()
	player.receive_hit(3, "physical", Vector2.INF, "bat")
	assert_eq(player.last_hit_cause, "bat")

func test_no_cause_falls_back_to_the_damage_type() -> void:
	var player := _player()
	player.receive_hit(3, "poison")
	assert_eq(player.last_hit_cause, "poison")

func test_a_hit_blocked_by_invulnerability_keeps_the_earlier_cause() -> void:
	var player := _player()
	player.receive_hit(3, "physical", Vector2.INF, "bat")
	player.receive_hit(3, "physical", Vector2.INF, "spear")
	assert_eq(player.last_hit_cause, "bat")

func test_the_cause_is_set_before_died_fires() -> void:
	var player := _player()
	var seen := []
	player.died.connect(func() -> void: seen.append(player.last_hit_cause))
	player.receive_hit(9999, "physical", Vector2.INF, "spear")
	assert_eq(seen, ["spear"])

func test_contact_names_the_creature() -> void:
	var stub := _stub()
	_enemy("bat", Vector2.ZERO)
	stub.global_position = Vector2(4, 0)
	await wait_physics_frames(2)
	assert_gt(stub.hits.size(), 0)
	assert_eq(stub.hits[0][2], "bat")

func test_the_drake_slam_names_the_drake() -> void:
	var stub := _stub()
	var drake := _enemy("stone_drake", Vector2.ZERO)
	drake.set_physics_process(false)
	stub.global_position = Vector2.ZERO
	drake._slam(stub)
	assert_eq(stub.hits.size(), 1)
	assert_eq(stub.hits[0][2], "stone_drake")

func test_the_spear_names_itself() -> void:
	var stub := _stub()
	var spear := Spear.new()
	add_child_autofree(spear)
	spear.set_physics_process(false)
	spear._hit(stub)
	assert_eq(stub.hits.size(), 1)
	assert_eq(stub.hits[0][2], "spear")
