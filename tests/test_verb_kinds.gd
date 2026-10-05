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

# --- Task 2: the other six kinds and spec validation ---

func _real_player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var p := Player.new()
	p.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	return p

func test_a_dash_launches_the_caster_and_hits_what_is_in_its_way() -> void:
	var foe := _foe(30)
	var far := _foe(100)
	_verb({"kind": "dash"}).activate()
	assert_eq(player.impulses, [Vector2(500, 0)])
	assert_eq(foe.hits.size(), 1)
	assert_eq(far.hits, [])

func test_a_zone_spawns_a_cloud_that_slows() -> void:
	_verb({"kind": "zone", "radius": 50.0, "seconds": 2.0}).activate()
	var clouds := get_children().filter(func(n: Node) -> bool: return n is SporeCloudArea)
	assert_eq(clouds.size(), 1)
	assert_eq(clouds[0].radius, 50.0)

func test_a_mark_hits_the_nearest_foe_after_its_delay() -> void:
	var near := _foe(50)
	var far := _foe(150)
	_verb({"kind": "mark", "delay": 0.1}).activate()
	assert_eq(near.hits, [], "not yet")
	await wait_seconds(0.3)
	assert_eq(near.hits.size(), 1)
	assert_eq(far.hits, [])

func test_a_mark_survives_its_target_dying_first() -> void:
	var foe := _foe(50)
	_verb({"kind": "mark", "delay": 0.1}).activate()
	foe.free()
	await wait_seconds(0.3)
	assert_true(true, "no crash")

func test_heal_restores_hp_and_mp() -> void:
	var p := _real_player()
	p.health.take_hit(10, "physical")
	p.mana.spend(5)
	var hp := p.health.hp
	var mp := p.mana.mp
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	p.add_child(a)
	a.spec = {"kind": "heal", "hp": 6, "mp": 3}
	a.setup(p, [1], 1)
	a.activate()
	assert_eq(p.health.hp, hp + 6)
	assert_eq(p.mana.mp, mp + 3)

func test_ward_makes_the_caster_untouchable() -> void:
	var p := _real_player()
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	p.add_child(a)
	a.spec = {"kind": "ward", "seconds": 1.0}
	a.setup(p, [1], 1)
	a.activate()
	var hp := p.health.hp
	p.receive_hit(5, "physical")
	assert_eq(p.health.hp, hp, "warded")
	p.tick(1.1)
	p.receive_hit(5, "physical")
	assert_lt(p.health.hp, hp, "the ward ended")

func test_buff_adds_a_stat_modifier_and_removes_it_when_it_ends() -> void:
	var p := _real_player()
	var before := p.stats.get_stat("spd")
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	p.add_child(a)
	a.spec = {"kind": "buff", "stats": {"spd": 20}, "seconds": 0.1}
	a.setup(p, [1], 1)
	a.activate()
	assert_gt(p.stats.get_stat("spd"), before)
	await wait_seconds(0.3)
	assert_eq(p.stats.get_stat("spd"), before)

func test_validate_accepts_a_minimal_spec_of_every_kind() -> void:
	for k in VerbKinds.KINDS:
		var spec := {"kind": k}
		if k == "buff":
			spec["stats"] = {"spd": 20}
		assert_eq(Array(VerbKinds.validate(spec)), [], k)

func test_validate_reports_the_exact_messages() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "x"})), ["unknown verb kind 'x'"])
	assert_eq(Array(VerbKinds.validate({})), ["unknown verb kind ''"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "range": "far"})), ["bolt: range must be a number"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "pierce": 1})), ["bolt: pierce must be true or false"])
	assert_eq(Array(VerbKinds.validate({"kind": "ring", "width": 3})), ["ring: unknown key 'width'"])
	assert_eq(Array(VerbKinds.validate({"kind": "buff", "stats": {"spd": "fast"}})), ["buff: stats must be a dictionary of stat id to number"])
	assert_eq(Array(VerbKinds.validate({"kind": "buff", "stats": {"luck": 3}})), ["buff: stats must be a dictionary of stat id to number"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "status": {"burn": 2}})), ["bolt: status must be slow, stun or root seconds"])

func test_a_buff_survives_a_skill_refresh() -> void:
	var p := _real_player()
	var before := p.stats.get_stat("spd")
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	p.add_child(a)
	a.spec = {"kind": "buff", "stats": {"spd": 20}, "seconds": 0.2}
	a.setup(p, [1], 1)
	a.activate()
	p.skillset.refresh()  # what any level-up or unlock does
	assert_eq(p.stats.get_stat("spd"), before + 20, "the buff is still on")
	await wait_seconds(0.4)
	assert_eq(p.stats.get_stat("spd"), before, "and it still ends")

func test_active_spec_ignores_a_spec_that_is_not_a_dictionary() -> void:
	for bad in ["bolt", [1], 3]:
		var d := TestDefs.skill("v", {"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [4], "spec": bad}]})
		assert_eq(SkillEffects.active_spec(d), {})

# --- B3: the spec's own cooldown and the root status ---

func test_a_spec_cooldown_replaces_the_default() -> void:
	var a := _verb({"kind": "bolt", "cooldown": 5.0})
	assert_true(a.activate())
	a._process(4.0)
	assert_false(a.ready(), "still cooling")
	a._process(1.1)
	assert_true(a.ready())

func test_the_default_cooldown_stands_without_one() -> void:
	var a := _verb({"kind": "bolt"})
	a.activate()
	a._process(Ability.COOLDOWN_SECONDS + 0.01)
	assert_true(a.ready())

func test_validate_accepts_cooldown_and_root_and_rejects_text() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "cooldown": 8.0, "status": {"root": 4.0}})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "zone", "cooldown": 8})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "cooldown": "long"})), ["bolt: cooldown must be a number"])
