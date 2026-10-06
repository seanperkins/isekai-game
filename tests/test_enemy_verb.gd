extends GutTest
## An enemy casts its form's verb at the player: a windup, the cast, a recovery, then the verb's own cooldown.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

var creatures := {}
var skills_by_id := {}
var player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 16)  # its top is at y = 6, where an enemy at y = 0 stands
	add_child_autofree(ground)
	player = StubPlayer.new()
	add_child_autofree(player)
	player.add_to_group("player")
	player.add_to_group("actors")

func _enemy(id: String, at := Vector2.ZERO) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

func _spec(id: String) -> Dictionary:
	return SkillEffects.active_spec(skills_by_id[creatures[id].verb])

func test_a_twin_casts_its_bolt_at_a_player_in_range() -> void:
	var e := _enemy("twin_undead_dullahan")
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	assert_gt(player.hits.size(), 0, "the bolt reached the player")

func test_a_player_beyond_verb_range_is_left_alone() -> void:
	var e := _enemy("twin_undead_dullahan")
	player.global_position = Vector2(Enemy.VERB_RANGE + 6.0, 0)  # inside CHASE_RANGE, so it is alert, but it has not closed in yet
	await wait_physics_frames(4)
	assert_true(e.is_alert())
	assert_false(e.telegraphing(), "out of range: no windup")
	assert_eq(e.verb_casts, 0)

func test_the_cast_waits_out_a_telegraphed_windup() -> void:
	var e := _enemy("twin_undead_dullahan")
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(6)
	assert_true(e.telegraphing(), "it winds up first")
	assert_eq(e.verb_casts, 0)
	await wait_physics_frames(40)
	assert_eq(e.verb_casts, 1)
	assert_false(e.telegraphing())

func test_the_verbs_own_cooldown_holds_the_next_cast_off() -> void:
	var e := _enemy("twin_undead_dullahan")
	player.global_position = Vector2(100, 0)
	assert_gte(float(_spec("twin_undead_dullahan")["cooldown"]), 2.0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	await wait_physics_frames(60)  # a second more: still cooling down
	assert_eq(e.verb_casts, 1)

func test_a_stunned_or_dormant_enemy_never_casts() -> void:
	var stunned := _enemy("twin_undead_dullahan")
	stunned.status.stun(30.0)
	var dormant := _enemy("twin_undead_dullahan", Vector2(20, 0))
	dormant.dormant = true
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(60)
	assert_eq(stunned.verb_casts, 0)
	assert_eq(dormant.verb_casts, 0)

func test_a_heal_verb_casts_only_when_hurt() -> void:
	skills_by_id["verb_test_heal"] = TestDefs.skill("verb_test_heal", {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [0], "spec": {"kind": "heal", "hp": 8, "cooldown": 30.0}}]})
	var c: CreatureDef = creatures["twin_undead_zombie"].duplicate()
	c.verb = "verb_test_heal"
	var e := Enemy.new()
	e.setup(c, skills_by_id)
	add_child_autofree(e)
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 0, "at full health it does not heal")
	e.health.hp = 1
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	assert_gt(e.health.hp, 1)

func test_a_dash_verb_throws_the_enemy_toward_the_player() -> void:
	var e := _enemy("twin_wolf_hellhound")
	player.global_position = Vector2(140, 0)
	var start := e.global_position.x
	await wait_physics_frames(45)
	assert_gte(e.verb_casts, 1)
	assert_gt(e.global_position.x, start + 20.0, "the dash carried it forward")

func test_a_ward_makes_the_enemy_refuse_blows_for_its_seconds() -> void:
	# no shipped twin casts a plain ward now (the black dog's is a veil, which only a player can use), so the verb is made here
	skills_by_id["verb_test_ward"] = TestDefs.skill("verb_test_ward", {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [0], "spec": {"kind": "ward", "seconds": 2.0, "cooldown": 10.0}}]})
	var c: CreatureDef = creatures["twin_wolf_black_dog"].duplicate()
	c.verb = "verb_test_ward"
	var e := Enemy.new()
	e.setup(c, skills_by_id)
	add_child_autofree(e)
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	var hp := e.health.hp
	e.receive_hit(5, "physical")
	assert_eq(e.health.hp, hp, "warded")
	await wait_physics_frames(int(2.0 * 60.0) + 10)
	e.receive_hit(1, "physical")
	assert_lt(e.health.hp, hp, "the ward ran out")

func test_an_enemys_verb_hits_for_no_more_than_twice_its_attack() -> void:
	skills_by_id["verb_test_big"] = TestDefs.skill("verb_test_big", {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [9], "spec": {"kind": "bolt", "range": 200.0, "cooldown": 3.0}}]})
	var c: CreatureDef = creatures["twin_undead_dullahan"].duplicate()
	c.verb = "verb_test_big"
	var e := Enemy.new()
	e.setup(c, skills_by_id)
	add_child_autofree(e)  # value 9, so an uncapped hit would be well above twice its ATK
	var atk := int(e.stats.get_stat("atk"))
	assert_gt(Damage.skill_power(9, atk), 2 * atk, "the cap bites on this twin")
	assert_eq(e._verb.power(), 2 * atk)

func test_a_verb_an_enemy_cannot_cast_builds_no_ability_and_the_twin_still_fights() -> void:
	var e := _enemy("twin_wolf_lycaon")  # a summon
	assert_false(VerbKinds.ENEMY_KINDS.has(_spec("twin_wolf_lycaon")["kind"]))
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 0)
	assert_eq(e.get_children().filter(func(n: Node) -> bool: return n is Ability).size(), 0)

func test_every_twin_with_a_castable_verb_casts_it_once_without_error() -> void:
	var cast := 0
	for id in MenagerieIds.TWINS:
		var c: CreatureDef = creatures[id]
		if c.verb == "" or not VerbKinds.ENEMY_KINDS.has(_spec(id).get("kind", "")):
			continue
		var e := _enemy(id)
		e.health.hp = 1  # so a heal verb has a reason to cast
		player.global_position = Vector2(80, 0)
		for i in 90:
			await wait_physics_frames(1)
			if e.verb_casts > 0:
				break
		assert_gte(e.verb_casts, 1, id)
		cast += 1
		e.queue_free()
	assert_gt(cast, 60, "most twins cast a verb")

func test_a_stun_in_the_middle_of_the_windup_drops_the_cast() -> void:
	var e := _enemy("twin_undead_dullahan")
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(6)
	assert_true(e.telegraphing())
	e.status.stun(30.0)
	await wait_physics_frames(40)
	assert_eq(e.verb_casts, 0)
	assert_false(e.telegraphing())

func test_a_dying_enemy_never_casts() -> void:
	var e := _enemy("twin_undead_dullahan")
	e.status.die()
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(60)
	assert_eq(e.verb_casts, 0)

## A real Player in place of the stub: a slow from an enemy's verb has to reach it.
func _real_player(at: Vector2) -> Player:
	player.remove_from_group("player")  # the enemy aims at the first player in the group
	player.remove_from_group("actors")
	var skills := DefLoader.load_dir("res://data/skills")
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	var p := Player.new()
	p.setup(rules, CompendiumModel.new(skills, []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(p)
	rules.start_run()
	p.global_position = at
	p._invuln = 1000.0
	return p

func test_a_slow_only_zone_slows_a_real_player_standing_in_it() -> void:
	var spec := _spec("twin_spider_loom_weaver")
	assert_true(bool(spec.get("slow", true)) and not bool(spec.get("damage", false)), "this twin's verb is a slow and nothing else")
	var e := _enemy("twin_spider_loom_weaver")
	var p := _real_player(Vector2(60, 0))
	await wait_physics_frames(90)
	assert_gte(e.verb_casts, 1)
	assert_lt(p.stats.get_stat("spd"), 100, "the web slowed it")

func test_a_slow_wears_off_and_slows_do_not_stack() -> void:
	var p := _real_player(Vector2(0, -200))
	p.slow_for(0.3)
	assert_eq(p.stats.get_stat("spd"), 100 + Player.SLOW_SPD)
	p.slow_for(0.3)
	assert_eq(p.stats.get_stat("spd"), 100 + Player.SLOW_SPD, "slows do not stack")
	await wait_physics_frames(30)  # half a second
	assert_eq(p.stats.get_stat("spd"), 100, "it wears off")

func test_a_shorter_slow_does_not_cut_a_longer_one_short() -> void:
	var p := _real_player(Vector2(0, -200))
	p.slow_for(0.8)
	p.slow_for(0.1)
	await wait_physics_frames(30)  # half a second: past the short one, inside the long one
	assert_eq(p.stats.get_stat("spd"), 100 + Player.SLOW_SPD, "the longer slow still holds")
	await wait_physics_frames(40)
	assert_eq(p.stats.get_stat("spd"), 100)

func test_a_window_verb_is_a_buff_to_an_enemy_and_ends_with_its_crash() -> void:
	skills_by_id["verb_test_rage"] = TestDefs.skill("verb_test_rage", {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [0], "spec": {"kind": "rage", "seconds": 0.5, "stats": {"atk": 5}, "crash": {"stats": {"atk": -2}, "seconds": 1.5}, "cooldown": 30.0}}]})
	var c: CreatureDef = creatures["twin_wolf_black_dog"].duplicate()
	c.verb = "verb_test_rage"
	var e := Enemy.new()
	e.setup(c, skills_by_id)
	add_child_autofree(e)
	var atk := e.stats.get_stat("atk")
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	assert_eq(e.stats.get_stat("atk"), atk + 5, "the window")
	await wait_seconds(0.4)
	assert_eq(e.stats.get_stat("atk"), atk - 2, "the crash")
	await wait_seconds(1.5)
	assert_eq(e.stats.get_stat("atk"), atk, "recovered")

func test_a_blink_verb_carries_the_enemy_toward_the_player() -> void:
	skills_by_id["verb_test_blink"] = TestDefs.skill("verb_test_blink", {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [0], "spec": {"kind": "blink", "distance": 60.0, "cooldown": 30.0}}]})
	var c: CreatureDef = creatures["twin_wolf_black_dog"].duplicate()
	c.verb = "verb_test_blink"
	var e := Enemy.new()
	e.setup(c, skills_by_id)
	add_child_autofree(e)
	player.global_position = Vector2(140, 0)
	var x0 := e.global_position.x
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	assert_gt(e.global_position.x, x0 + 40.0, "it jumped ahead")

func _summoner(seconds: float, cooldown: float) -> Enemy:
	skills_by_id["verb_test_summon"] = TestDefs.skill("verb_test_summon", {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [0],
		"spec": {"kind": "summon", "count": 2, "seconds": seconds, "look": "skeleton", "cooldown": cooldown}}]})
	var c: CreatureDef = creatures["twin_undead_dullahan"].duplicate()
	c.verb = "verb_test_summon"
	var e := Enemy.new()
	e.setup(c, skills_by_id)
	add_child_autofree(e)
	player.global_position = Vector2(100, 0)
	return e

func _minions_of(e: Enemy) -> Array:
	return get_tree().get_nodes_in_group("minions").filter(func(n): return is_instance_valid(n) and n.get_meta("minion_of", null) == e)

func after_each() -> void:
	for m in get_tree().get_nodes_in_group("minions"):
		m.free()

func test_an_enemys_summon_calls_hostile_minions_up_to_its_count() -> void:
	var e := _summoner(5.0, 0.5)
	await wait_physics_frames(150)
	var minions := _minions_of(e)
	assert_gt(e.verb_casts, 1, "it keeps calling")
	assert_eq(minions.size(), 2, "never more than its count")
	assert_eq(minions[0].def.id, "skeleton")
	assert_eq(minions[0].team, "enemy", "hostile")

func test_an_enemys_minions_go_when_their_time_is_up() -> void:
	var e := _summoner(0.6, 30.0)
	await wait_physics_frames(45)
	assert_eq(e.verb_casts, 1)
	assert_gt(_minions_of(e).size(), 0)
	await wait_seconds(1.0)
	assert_eq(_minions_of(e).size(), 0, "gone")
