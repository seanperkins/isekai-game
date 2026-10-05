extends GutTest
## The slime's form-four verbs: the table, the data it writes, and each verb on an enemy.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func apply_impulse(_v: Vector2) -> void:
		pass

var creatures := {}
var skills_by_id := {}
var skills: Array
var caster: StubPlayer

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in skills:
		skills_by_id[d.id] = d

func before_each() -> void:
	caster = StubPlayer.new()
	add_child_autofree(caster)
	caster.add_to_group("player")
	caster.add_to_group("actors")
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

## The verb a form grants, built as the Player builds it.
func _verb(form_id: String) -> VerbAbility:
	var d: SkillDef = skills_by_id["verb_" + form_id]
	var a: VerbAbility = load(SkillEffects.active_scene(d)).instantiate()
	add_child_autofree(a)
	a.spec = SkillEffects.active_spec(d)
	a.setup(caster, SkillEffects.active_values(d), 1)
	return a

func _rows() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tools/form_verbs.json"))

# --- the root ---

func test_a_rooted_enemy_does_not_act_and_is_not_edible() -> void:
	var lizard := _enemy("lizard", Vector2(0, 0))
	caster.global_position = Vector2(100, 0)
	lizard.root_for(1.0)
	assert_true(lizard.is_rooted())
	await wait_physics_frames(20)
	assert_eq(lizard.position.x, 0.0, "it holds its ground")
	assert_false(lizard.can_be_predated())
	caster.global_position = Vector2(4, 0)
	await wait_physics_frames(3)
	assert_eq(caster.hits, [], "and does not strike")

func test_a_stunned_enemy_that_is_rooted_cannot_be_eaten_until_the_root_ends() -> void:
	var lizard := _enemy("lizard", Vector2(0, 0))
	lizard.status.stun(5.0)
	assert_true(lizard.can_be_predated(), "stunned: edible")
	lizard.root_for(0.3)
	assert_false(lizard.can_be_predated(), "bound: not")
	await wait_seconds(0.6)
	assert_true(lizard.can_be_predated(), "free of the root: edible again")

func test_a_root_ends() -> void:
	var lizard := _enemy("lizard", Vector2(0, 0))
	caster.global_position = Vector2(100, 0)
	lizard.root_for(0.3)
	await wait_seconds(0.6)
	assert_false(lizard.is_rooted())
	await wait_physics_frames(15)
	assert_ne(lizard.position.x, 0.0, "it moves again")

func test_a_boss_that_cannot_be_stunned_can_be_rooted() -> void:
	var serpent := _enemy("serpent", Vector2(0, 0))
	serpent.root_for(1.0)
	assert_true(serpent.is_rooted())
	assert_eq(serpent.status.state, EnemyStatus.ACTIVE, "a root is not a stun")

func test_bind_roots_the_nearest_foe_and_waits_eight_seconds() -> void:
	var lizard := _enemy("lizard", Vector2(60, 0))
	var bind := _verb("gleipnir")
	assert_true(bind.activate())
	assert_true(lizard.is_rooted())
	bind._process(7.0)
	assert_false(bind.ready())
	bind._process(1.1)
	assert_true(bind.ready())

func test_bind_with_nothing_in_range_does_nothing() -> void:
	assert_true(_verb("gleipnir").activate())

func test_pseudopod_reaches_a_foe_a_burst_would_miss() -> void:
	var lizard := _enemy("lizard", Vector2(120, 0))
	var hp := lizard.health.hp
	_verb("shoggoth").activate()
	assert_lt(lizard.health.hp, hp)

func test_hurl_hits_the_nearest_foe_only() -> void:
	var near := _enemy("lizard", Vector2(80, 0))
	var far := _enemy("lizard", Vector2(160, 0))
	var hp := far.health.hp
	_verb("poltergeist").activate()
	assert_lt(near.health.hp, near.health.max_hp)
	assert_eq(far.health.hp, hp)

# --- the table and the data ---

func test_each_verb_row_has_a_form_and_a_skill() -> void:
	assert_gt(_rows().size(), 0)
	for row in _rows():
		var f: FormDef = load("res://data/forms/%s.tres" % row["form"])
		assert_not_null(f, row["form"])
		assert_eq(f.verb, "verb_" + row["form"], row["form"])
		assert_true(f.grants.has(f.verb), row["form"])
		var d: SkillDef = skills_by_id.get(f.verb)
		assert_not_null(d, f.verb)
		assert_eq(d.source, "form_verb")
		assert_eq(d.display_name, row["name"])
		assert_eq(d.mp_cost, int(row["mp"]))
		assert_eq(SkillEffects.active_spec(d)["kind"], row["spec"]["kind"])

func test_the_data_validates() -> void:
	var verb_ids: Array = skills.filter(func(d: SkillDef) -> bool: return d.source == "form_verb").map(func(d: SkillDef) -> String: return d.id)
	var forms := FormLoader.load_all()
	var skill_ids: Array = skills.map(func(d: SkillDef) -> String: return d.id)
	assert_eq(Array(FormValidator.validate(forms, skill_ids, false, verb_ids)), [])
	assert_eq(Array(DefValidator.validate(skills, DefLoader.load_dir("res://data/creatures"))), [])

func test_a_form_without_a_row_has_no_verb() -> void:
	var with_verbs: Array = _rows().map(func(r: Dictionary) -> String: return r["form"])
	for id in FormLoader.load_all():
		if not with_verbs.has(id):
			assert_eq(FormLoader.load_all()[id].verb, "", id)
