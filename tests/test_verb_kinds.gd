extends GutTest
## The verb framework: a skill's active effect carries a spec ({"kind": ...}) and one generic ability turns it into behaviour.

class FakeActor extends Node2D:
	var team := "player"
	var facing := 1
	var impulses: Array = []
	var hits: Array = []
	var slowed: Array = []
	func apply_impulse(v: Vector2) -> void:
		impulses.append(v)
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func slow_for(seconds: float) -> void:
		slowed.append(seconds)

var player: FakeActor

func before_each() -> void:
	player = FakeActor.new()
	add_child_autofree(player)
	player.add_to_group("actors")

func _foe(x: float, y: float = 0.0, team := "enemy") -> FakeActor:
	var e := FakeActor.new()
	e.team = team
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = Vector2(x, y)
	return e

func _verb(spec: Dictionary, values := [4]) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(a)
	a.spec = spec
	a.setup(player, values, 1)
	return a

# --- Task 1: the spec and the damage kinds ---

func test_active_spec_is_read_from_the_effect() -> void:
	var d := TestDefs.skill("v", {"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [4], "spec": {"kind": "bolt"}}]})
	assert_eq(SkillEffects.active_spec(d), {"kind": "bolt"})
	var plain := TestDefs.skill("p", {"effects": [{"kind": "active", "scene": "res://scenes/abilities/jet_dash.tscn", "values": []}]})
	assert_eq(SkillEffects.active_spec(plain), {})

func test_a_bolt_pierces_everything_in_front_within_its_range() -> void:
	var near := _foe(40)
	var mid := _foe(120)
	var far := _foe(300)
	var behind := _foe(-40)
	var ally := _foe(60, 0, "player")
	_verb({"kind": "bolt"}).activate()
	assert_eq(near.hits, [[4, "physical"]])
	assert_eq(mid.hits, [[4, "physical"]])
	assert_eq(far.hits, [])
	assert_eq(behind.hits, [])
	assert_eq(ally.hits, [])

func test_a_bolt_that_does_not_pierce_hits_the_nearest_only() -> void:
	var near := _foe(40)
	var mid := _foe(120)
	_verb({"kind": "bolt", "pierce": false}).activate()
	assert_eq(near.hits.size(), 1)
	assert_eq(mid.hits, [])

func test_a_burst_hits_a_short_wide_area_in_front() -> void:
	var inside := _foe(30, 35)
	var too_far := _foe(80)
	var too_wide := _foe(30, 50)
	_verb({"kind": "burst"}).activate()
	assert_eq(inside.hits.size(), 1)
	assert_eq(too_far.hits, [])
	assert_eq(too_wide.hits, [])

func test_a_ring_hits_every_foe_within_its_radius_and_not_the_ally() -> void:
	var front := _foe(50)
	var back := _foe(-60)
	var out := _foe(90)
	var ally := _foe(10, 0, "player")
	_verb({"kind": "ring"}).activate()
	assert_eq(front.hits.size(), 1)
	assert_eq(back.hits.size(), 1)
	assert_eq(out.hits, [])
	assert_eq(ally.hits, [])

func test_a_status_slows_what_it_hits() -> void:
	var foe := _foe(40)
	_verb({"kind": "bolt", "status": {"slow": 2.0}}).activate()
	assert_eq(foe.slowed, [2.0])

func test_the_damage_type_is_the_specs() -> void:
	var foe := _foe(40)
	_verb({"kind": "burst", "damage_type": "poison"}).activate()
	assert_eq(foe.hits, [[4, "poison"]])

func test_an_unknown_kind_does_nothing_and_does_not_crash() -> void:
	var foe := _foe(40)
	_verb({"kind": "nonsense"}).activate()
	assert_eq(foe.hits, [])
