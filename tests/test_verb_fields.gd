extends GutTest
## The verbs built on a timed field or a chain: pull, aura, chain, engulf, dissolve, and a zone with its own damage type.

class Actor extends Node2D:
	var team := "player"
	var facing := 1
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

class Foe extends Node2D:
	var team := "enemy"
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

class Gate extends Node2D:
	var dissolved := 0
	func dissolve() -> void:
		dissolved += 1

var creatures := {}
var skills_by_id := {}
var caster: Actor

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	caster = Actor.new()
	add_child_autofree(caster)
	caster.add_to_group("actors")
	caster.add_to_group("player")

func after_each() -> void:
	for f in _fields():  # a field outlives its test by a frame; the next test counts them
		f.free()

func _foe(x: float, y := 0.0, team := "enemy") -> Foe:
	var f := Foe.new()
	f.team = team
	add_child_autofree(f)
	f.add_to_group("actors")
	f.global_position = Vector2(x, y)
	return f

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	e.dormant = false
	return e

func _verb(spec: Dictionary, value := 4) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(a)
	a.spec = spec
	a.setup(caster, [value], 1)
	return a

func _fields() -> Array:
	return get_tree().get_nodes_in_group("verb_fields")

func _power(value := 4) -> int:
	return Damage.skill_power(value, 1)

# --- pull ---

func test_a_pull_field_draws_foes_toward_its_centre() -> void:
	var near := _foe(70, 50)
	var out := _foe(70, 300)
	_verb({"kind": "pull", "radius": 100.0, "seconds": 2.0, "strength": 80.0}).activate()
	await wait_seconds(0.5)
	assert_lt(near.global_position.distance_to(Vector2(70, 0)), 40.0, "drawn in")
	assert_eq(out.global_position, Vector2(70, 300), "outside the radius is left alone")

func test_a_pull_field_ticks_damage_once_a_second_when_asked() -> void:
	var hurt := _foe(70, 20)
	var spared := _foe(70, -20)
	_verb({"kind": "pull", "radius": 100.0, "seconds": 2.0, "strength": 10.0, "damage": true, "damage_type": "water"}).activate()
	await wait_seconds(2.4)
	assert_eq(hurt.hits, [[_power(), "water"], [_power(), "water"]])
	_verb({"kind": "pull", "radius": 100.0, "seconds": 1.0, "strength": 10.0}).activate()
	spared.hits.clear()
	await wait_seconds(1.3)
	assert_eq(spared.hits, [], "no damage unless the spec says")

func test_a_pull_field_survives_a_foe_freed_inside_it() -> void:
	var foe := _foe(70, 30)
	_verb({"kind": "pull", "radius": 100.0, "seconds": 1.0, "strength": 80.0, "damage": true}).activate()
	await wait_physics_frames(3)
	foe.free()
	await wait_seconds(1.3)
	assert_eq(_fields().size(), 0, "and it still ends")

func test_a_pull_field_never_draws_the_casters_team() -> void:
	var ally := _foe(70, 50, "player")
	_verb({"kind": "pull", "radius": 100.0, "seconds": 1.0, "strength": 80.0}).activate()
	await wait_seconds(0.4)
	assert_eq(ally.global_position, Vector2(70, 50))

# --- aura ---

func test_an_aura_follows_the_caster_and_hurts_what_is_near() -> void:
	var foe := _foe(100, 0)
	var ally := _foe(100, 10, "player")
	_verb({"kind": "aura", "radius": 40.0, "seconds": 3.0, "damage": true}).activate()
	caster.global_position = Vector2(100, 0)
	await wait_seconds(1.2)
	assert_eq(foe.hits.size(), 1)
	assert_eq(foe.hits[0], [_power(), "physical"])
	assert_eq(ally.hits, [])

func test_an_aura_ends_with_its_caster() -> void:
	_verb({"kind": "aura", "radius": 40.0, "seconds": 5.0}).activate()
	assert_eq(_fields().size(), 1)
	caster.free()
	await wait_physics_frames(3)
	assert_eq(_fields().size(), 0)

# --- chain ---

func test_a_chain_jumps_to_the_nearest_foe_not_yet_hit() -> void:
	var a := _foe(40)
	var b := _foe(100)
	var c := _foe(160)
	var far := _foe(400)
	_verb({"kind": "chain", "range": 160.0, "jump": 80.0, "hops": 3, "damage_type": "poison"}, 3).activate()
	for f in [a, b, c]:
		assert_eq(f.hits, [[_power(3), "poison"]])
	assert_eq(far.hits, [])

func test_a_chain_stops_after_its_hops() -> void:
	var foes := [_foe(40), _foe(90), _foe(140), _foe(190)]
	_verb({"kind": "chain", "range": 160.0, "jump": 80.0, "hops": 1}).activate()
	assert_eq(foes[0].hits.size() + foes[1].hits.size(), 2)
	assert_eq(foes[2].hits.size() + foes[3].hits.size(), 0)

func test_a_chain_with_nothing_in_range_does_nothing() -> void:
	assert_true(_verb({"kind": "chain"}).activate())

# --- engulf ---

func test_engulf_stuns_the_nearest_predatable_foe_and_digests_it() -> void:
	var lizard := _enemy("lizard", Vector2(30, 0))
	lizard.health.max_hp = 100
	lizard.health.hp = 100
	_verb({"kind": "engulf", "range": 40.0, "seconds": 3.0}, 2).activate()
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)
	await wait_seconds(1.2)
	assert_eq(100 - lizard.health.hp, Damage.hit(_power(2), "physical", 0, 0, 0), "one tick, through no armour")
	await wait_seconds(2.4)
	assert_eq(100 - lizard.health.hp, 3 * Damage.hit(_power(2), "physical", 0, 0, 0), "three ticks in all")

func test_engulf_skips_what_cannot_be_stunned() -> void:
	var serpent := _enemy("serpent", Vector2(30, 0))
	var hp := serpent.health.hp
	_verb({"kind": "engulf", "range": 40.0, "seconds": 3.0}).activate()
	await wait_seconds(1.2)
	assert_eq(serpent.status.state, EnemyStatus.ACTIVE)
	assert_eq(serpent.health.hp, hp)

func test_engulf_with_its_prey_gone_ends_quietly() -> void:
	var lizard := _enemy("lizard", Vector2(30, 0))
	_verb({"kind": "engulf", "range": 40.0, "seconds": 3.0}).activate()
	lizard.free()
	await wait_seconds(0.4)
	assert_eq(_fields().size(), 0)

# --- dissolve ---

func test_dissolve_ignores_armour_and_opens_a_dissolvable() -> void:
	var crab := _enemy("mushroom_crab", Vector2(30, 0))
	var hp := crab.health.hp
	var gate := Gate.new()
	add_child_autofree(gate)
	gate.add_to_group("dissolvable")
	gate.global_position = Vector2(30, 0)
	var far_gate := Gate.new()
	add_child_autofree(far_gate)
	far_gate.add_to_group("dissolvable")
	far_gate.global_position = Vector2(300, 0)
	var plain := _foe(20, 10)
	_verb({"kind": "dissolve", "range": 60.0, "half_width": 40.0}, 6).activate()
	var through_armour := Damage.hit(_power(6), "physical", crab.stats.get_stat("def"), 0, 0)
	var ignoring := Damage.hit(_power(6), "physical", 0, 0, 0)
	assert_lt(through_armour, ignoring, "the armour would have mattered")
	assert_eq(hp - crab.health.hp, ignoring)
	assert_eq(gate.dissolved, 1)
	assert_eq(far_gate.dissolved, 0)
	assert_eq(plain.hits, [[_power(6), "physical"]], "an ordinary target is hit the ordinary way")

# --- a zone with its own damage type ---

func test_a_zone_can_deal_its_own_damage_type() -> void:
	var foe := _foe(10, 0)
	_verb({"kind": "zone", "radius": 60.0, "seconds": 1.2, "damage": true, "damage_type": "water", "slow": false}).activate()
	await wait_seconds(1.1)
	assert_eq(foe.hits[0][1], "water")

func test_a_zone_keeps_poison_by_default() -> void:
	var foe := _foe(10, 0)
	_verb({"kind": "zone", "radius": 60.0, "seconds": 1.2, "damage": true, "slow": false}).activate()
	await wait_seconds(1.1)
	assert_eq(foe.hits[0][1], "poison")

func test_validate_knows_the_new_kinds() -> void:
	for spec in [{"kind": "pull", "strength": 90, "ahead": 70, "damage": true, "damage_type": "water"}, {"kind": "aura", "radius": 60, "damage": true},
			{"kind": "chain", "range": 160, "jump": 80, "hops": 3, "damage_type": "poison", "status": {"slow": 1.0}},
			{"kind": "engulf", "range": 40, "seconds": 3}, {"kind": "dissolve", "range": 60, "half_width": 40}, {"kind": "zone", "damage_type": "water"}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
	assert_eq(Array(VerbKinds.validate({"kind": "pull", "strength": "hard"})), ["pull: strength must be a number"])
	assert_eq(Array(VerbKinds.validate({"kind": "aura", "hops": 2})), ["aura: unknown key 'hops'"])
