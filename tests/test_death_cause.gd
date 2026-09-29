extends GutTest
## The killing blow carries a cause, and a creature that dies is DYING (not attackable, not edible,
## no AI) until its death effect ends. These pin the state and the arguments; test_death_fx.gd pins
## the effects.

var creatures := {}
var skills := {}
var downed_count := 0

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func _enemy(id: String = "toad") -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills)
	e.set_physics_process(false)
	add_child_autofree(e)
	downed_count = 0
	e.downed.connect(func(_d: CreatureDef) -> void: downed_count += 1)
	return e

func _kill(e: Enemy, cause: String = "") -> void:
	e.receive_hit(9999, "physical", Vector2(-50, 0), cause)

# --- EnemyStatus ---

func test_dying_is_the_fifth_state_and_update_ignores_it() -> void:
	var s := EnemyStatus.new()
	s.die()
	assert_eq(s.state, EnemyStatus.DYING)
	s.update(100.0)
	assert_eq(s.state, EnemyStatus.DYING, "no timer: an unlisted state must not count down to GONE")

func test_a_dying_creature_is_not_predatable_and_cannot_be_stunned() -> void:
	var s := EnemyStatus.new()
	s.die()
	assert_false(s.predatable())
	s.stun()
	assert_eq(s.state, EnemyStatus.DYING)

func test_down_ends_dying_and_starts_the_eat_window() -> void:
	var s := EnemyStatus.new()
	s.die()
	s.down()
	assert_eq(s.state, EnemyStatus.DOWNED)
	assert_true(s.predatable())

# --- Enemy ---

func test_a_lethal_hit_enters_dying_and_reports_downed_once() -> void:
	var e := _enemy()
	_kill(e)
	assert_eq(e.status.state, EnemyStatus.DYING)
	assert_eq(downed_count, 1)
	_kill(e)  # a second blow while dying
	assert_eq(downed_count, 1, "XP and the Bestiary are paid once")

func test_a_dying_creature_ignores_blows_and_cannot_be_eaten() -> void:
	var e := _enemy()
	_kill(e)
	e.receive_thread(3)
	assert_eq(e.status.state, EnemyStatus.DYING)
	assert_false(e.receive_tackle(5, true, Vector2(-30, 0)) and false)
	assert_eq(e.status.state, EnemyStatus.DYING)
	assert_false(e.can_be_predated())

func test_a_lethal_tackle_still_counts_as_a_stun_or_down() -> void:
	var e := _enemy()
	assert_true(e.receive_tackle(9999, false, Vector2(-30, 0)))
	assert_eq(e.status.state, EnemyStatus.DYING)

func test_a_non_lethal_tackle_still_stuns() -> void:
	var e := _enemy()
	assert_true(e.receive_tackle(1, false, Vector2(-30, 0)))
	assert_eq(e.status.state, EnemyStatus.STUNNED)

func test_the_cause_defaults_from_the_damage_type() -> void:
	assert_eq(Enemy.cause_for("poison"), "poison")
	assert_eq(Enemy.cause_for("physical"), "other")
	var e := _enemy()
	e.receive_hit(9999, "poison", Vector2.INF)
	assert_eq(e._cause, "poison")

func test_an_explicit_cause_wins_and_is_stored_before_the_death_is_reported() -> void:
	var e := _enemy()
	var seen := []
	e.downed.connect(func(_d: CreatureDef) -> void: seen.append(e._cause))
	e.receive_hit(9999, "physical", Vector2(-10, 0), "blade")
	assert_eq(seen, ["blade"])
	assert_eq(e._killed_from, Vector2(-10, 0))

func test_a_lethal_tackle_records_the_tackle_cause_and_position() -> void:
	var e := _enemy()
	e.receive_tackle(9999, false, Vector2(-25, 4))
	assert_eq(e._cause, "tackle")
	assert_eq(e._killed_from, Vector2(-25, 4))

func test_a_dying_enemy_does_no_contact_damage() -> void:
	var e := _enemy()
	e.set_physics_process(true)
	var hits := []
	var victim := _recorder(hits)
	victim.add_to_group("player")
	add_child_autofree(victim)
	victim.global_position = e.global_position
	await wait_physics_frames(2)
	assert_gt(hits.size(), 0, "an active enemy on top of the player does hurt it")
	hits.clear()
	_kill(e)
	await wait_physics_frames(3)
	assert_eq(hits.size(), 0, "a dying one does not")

# --- the other two implementors and the callers ---

func test_the_player_takes_the_new_arguments() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(p)
	rules.start_run()
	p.receive_hit(1, "physical", Vector2(5, 5), "other")
	assert_lt(p.health.hp, p.health.max_hp)

func test_the_shortcut_switch_takes_the_new_arguments() -> void:
	var sw := ShortcutSwitch.new()
	sw.setup({"shortcut": "s", "pos": Vector2.ZERO}, {})
	add_child_autofree(sw)
	sw.receive_hit(1, "physical", Vector2(3, 3), "blade")
	assert_true(sw.is_queued_for_deletion())
	var sw2 := ShortcutSwitch.new()
	sw2.setup({"shortcut": "s2", "pos": Vector2.ZERO}, {})
	add_child_autofree(sw2)
	assert_false(sw2.receive_tackle(1, false, Vector2(3, 3)))
	assert_true(sw2.is_queued_for_deletion())

func _cast(script_path: String, damage_hits: Array) -> void:
	var actor := Node2D.new()
	actor.set_script(_actor())
	add_child_autofree(actor)
	actor.global_position = Vector2.ZERO
	var target := _recorder(damage_hits)
	target.add_to_group("actors")
	add_child_autofree(target)
	target.global_position = Vector2(30, 0)
	var ab: Ability = load(script_path).new()
	add_child_autofree(ab)
	ab.setup(actor, [5], 1)
	ab.activate()

func test_water_blade_passes_the_blade_cause_and_the_casters_position() -> void:
	var hits := []
	_cast("res://scripts/abilities/water_blade.gd", hits)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0][3], "blade")
	assert_eq(hits[0][2], Vector2.ZERO)

func test_poison_breath_passes_the_poison_cause_and_the_casters_position() -> void:
	var hits := []
	_cast("res://scripts/abilities/poison_breath.gd", hits)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0][3], "poison")
	assert_eq(hits[0][2], Vector2.ZERO)

func _actor() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar team := 'player'\nvar facing := 1\n"
	s.reload()
	return s

## A target that records every receive_hit it gets: [raw, damage_type, from, cause].
func _recorder(seen: Array) -> Node2D:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar team := 'enemy'\nvar seen := []\nfunc receive_hit(a, b, c = Vector2.INF, d = ''):\n\tseen.append([a, b, c, d])\n"
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	n.seen = seen
	return n
