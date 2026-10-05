extends GutTest
## The verbs that move the caster or leave something behind: glide, recall, shed, court and stalk.

class Actor extends Node2D:
	var team := "player"
	var facing := 1
	var velocity := Vector2.ZERO
	var impulses: Array = []
	var warded: Array = []
	func apply_impulse(v: Vector2) -> void:
		impulses.append(v)
	func ward(seconds: float) -> void:
		warded.append(seconds)
	func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

class Foe extends Node2D:
	var team := "enemy"
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

class Faller extends CharacterBody2D:
	func _physics_process(delta: float) -> void:
		velocity.y += 900.0 * delta
		move_and_slide()

var caster: Actor

func before_each() -> void:
	caster = Actor.new()
	add_child_autofree(caster)
	caster.add_to_group("actors")

func after_each() -> void:
	for group in ["verb_allies", "verb_husks", "verb_vines"]:
		for n in get_tree().get_nodes_in_group(group):
			n.free()

func _foe(x: float, y := 0.0, team := "enemy") -> Foe:
	var f := Foe.new()
	f.team = team
	add_child_autofree(f)
	f.add_to_group("actors")
	f.global_position = Vector2(x, y)
	return f

func _verb(spec: Dictionary, value := 4, who: Node2D = null) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(a)
	a.spec = spec
	a.setup(who if who != null else caster, [value], 1)
	return a

func _real_player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var p := Player.new()
	p.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	return p

func _power(value := 4) -> int:
	return Damage.skill_power(value, 1)

# --- glide ---

func test_glide_caps_the_fall_speed_for_its_time() -> void:
	var p := _real_player()
	await wait_physics_frames(2)
	p.velocity.y = 300.0
	p.glide(0.5, 40.0)
	await wait_physics_frames(6)
	assert_lte(p.velocity.y, 40.0, "gliding")
	await wait_seconds(0.8)
	assert_gt(p.velocity.y, 100.0, "and falling again once it ends")

func test_glide_on_an_actor_that_cannot_glide_does_nothing() -> void:
	assert_true(_verb({"kind": "glide"}).activate())

# --- recall ---

func test_a_recall_lays_a_mark_then_returns_to_it() -> void:
	var a := _verb({"kind": "anchor", "seconds": 30.0})
	caster.global_position = Vector2(10, 20)
	a.activate()
	assert_eq(caster.global_position, Vector2(10, 20), "the first cast only lays the mark")
	caster.global_position = Vector2(210, 20)
	caster.velocity = Vector2(80, 80)
	a._process(1.0)
	a.activate()
	assert_eq(caster.global_position, Vector2(10, 20))
	assert_eq(caster.velocity, Vector2.ZERO)
	caster.global_position = Vector2(50, 0)
	a._process(1.0)
	a.activate()
	assert_eq(caster.global_position, Vector2(50, 0), "the third lays a new one")

func test_a_recall_mark_expires() -> void:
	var a := _verb({"kind": "anchor", "seconds": 0.05})
	caster.global_position = Vector2(10, 0)
	a.activate()
	await wait_seconds(0.15)
	caster.global_position = Vector2(99, 0)
	a._process(1.0)
	a.activate()
	assert_eq(caster.global_position, Vector2(99, 0), "an old mark is not returned to")

class FakeWorld extends Node2D:
	var room: Node2D

func test_a_recall_mark_does_not_follow_the_caster_into_another_room() -> void:
	var world := FakeWorld.new()
	add_child_autofree(world)
	var room_a := Node2D.new()
	var room_b := Node2D.new()
	world.add_child(room_a)
	world.add_child(room_b)
	world.room = room_a
	var walker := Actor.new()
	world.add_child(walker)
	walker.global_position = Vector2(10, 0)
	var a := _verb({"kind": "anchor", "seconds": 30.0}, 4, walker)
	a.activate()  # the mark is laid in room A
	world.room = room_b
	walker.global_position = Vector2(500, 0)
	a._process(1.0)
	a.activate()
	assert_eq(walker.global_position, Vector2(500, 0), "room A is gone: there is nothing to return to")
	walker.global_position = Vector2(600, 0)
	a._process(1.0)
	a.activate()
	assert_eq(walker.global_position, Vector2(500, 0), "but the cast laid a new mark in room B, which it returns to")

# --- shed ---

func test_a_shed_leaves_a_husk_and_slips_away() -> void:
	caster.global_position = Vector2(30, 5)
	caster.facing = 1
	_verb({"kind": "decoy", "seconds": 1.0, "speed": 360.0, "ward": 0.6}).activate()
	var husks := get_tree().get_nodes_in_group("verb_husks")
	assert_eq(husks.size(), 1)
	assert_eq(husks[0].global_position, Vector2(30, 5))
	assert_eq(caster.warded, [0.6])
	assert_eq(caster.impulses, [Vector2(-360.0, 0.0)], "away from where it faces")

func test_a_husk_fades_and_goes() -> void:
	_verb({"kind": "decoy", "seconds": 0.2}).activate()
	await wait_seconds(0.5)
	assert_eq(get_tree().get_nodes_in_group("verb_husks").size(), 0)

# --- court ---

func test_a_summon_spawns_allies_that_hit_the_nearest_foe_and_expire() -> void:
	var foe := _foe(60)
	_verb({"kind": "summon", "count": 3, "seconds": 2.0}).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_allies").size(), 3)
	await wait_seconds(1.5)
	assert_gt(foe.hits.size(), 0, "they fight")
	assert_eq(foe.hits[0], [_power(), "physical"])
	await wait_seconds(1.2)
	assert_eq(get_tree().get_nodes_in_group("verb_allies").size(), 0, "and they go")

func test_a_second_court_replaces_the_first() -> void:
	var a := _verb({"kind": "summon", "count": 3, "seconds": 5.0})
	a.activate()
	a._process(5.0)
	a.activate()
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("verb_allies").size(), 3)

func test_allies_reach_a_foe_at_another_height() -> void:
	var foe := _foe(40, 80)
	_verb({"kind": "summon", "count": 2, "seconds": 3.0}).activate()
	await wait_seconds(2.0)
	assert_gt(foe.hits.size(), 0, "they come to it, up or down")

func test_allies_never_hit_their_own_team() -> void:
	var friend := _foe(60, 0, "player")
	_verb({"kind": "summon", "count": 3, "seconds": 1.5}).activate()
	await wait_seconds(1.2)
	assert_eq(friend.hits, [])

func test_allies_are_freed_with_their_caster() -> void:
	_verb({"kind": "summon", "count": 2, "seconds": 10.0}).activate()
	caster.free()
	await wait_physics_frames(3)
	assert_eq(get_tree().get_nodes_in_group("verb_allies").size(), 0)

func test_allies_with_no_foe_stay_near_their_caster() -> void:
	_verb({"kind": "summon", "count": 2, "seconds": 5.0}).activate()
	caster.global_position = Vector2(200, 0)
	await wait_seconds(1.5)
	for ally in get_tree().get_nodes_in_group("verb_allies"):
		assert_lt(absf(ally.global_position.x - 200.0), 40.0)

# --- stalk ---

func test_a_vine_makes_one_way_steps_that_a_body_can_land_on_and_then_goes() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 210)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	caster.global_position = Vector2(0, 150)
	await wait_physics_frames(2)
	_verb({"kind": "vine", "height": 160.0, "seconds": 1.5}).activate()
	var vines := get_tree().get_nodes_in_group("verb_vines")
	assert_eq(vines.size(), 1)
	var steps: Array = vines[0].get_children().filter(func(n: Node) -> bool: return n is StaticBody2D)
	assert_eq(steps.size(), 4)
	var tops: Array = steps.map(func(n: StaticBody2D) -> float: return n.global_position.y)
	tops.sort()
	assert_lt(tops[3] - tops[0], 130.0)
	assert_gt(tops[3] - tops[0], 100.0, "a stack, not a line")
	for s in steps:
		assert_true(s.get_child(0).one_way_collision, "a body can jump up through it")
	var lowest: StaticBody2D = steps.filter(func(n: StaticBody2D) -> bool: return is_equal_approx(n.global_position.y, tops[3]))[0]
	var box_body := Faller.new()
	var bshape := CollisionShape2D.new()
	var bbox := RectangleShape2D.new()
	bbox.size = Vector2(8, 8)
	bshape.shape = bbox
	box_body.add_child(bshape)
	add_child_autofree(box_body)
	box_body.global_position = lowest.global_position + Vector2(0, -30)
	await wait_seconds(0.6)
	assert_lt(box_body.global_position.y, lowest.global_position.y, "it came to rest on the step")
	await wait_seconds(1.2)
	assert_eq(get_tree().get_nodes_in_group("verb_vines").size(), 0)

func test_a_vine_with_no_floor_under_it_still_grows() -> void:
	caster.global_position = Vector2(0, -5000)
	assert_true(_verb({"kind": "vine", "height": 80.0, "seconds": 0.3}).activate())
	assert_eq(get_tree().get_nodes_in_group("verb_vines").size(), 1)

func test_validate_knows_the_mover_kinds() -> void:
	for spec in [{"kind": "glide", "seconds": 1.5, "fall": 40}, {"kind": "anchor", "seconds": 30}, {"kind": "decoy", "seconds": 1.2, "speed": 360, "ward": 0.6},
			{"kind": "summon", "count": 3, "seconds": 10}, {"kind": "vine", "height": 160, "seconds": 10}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
	assert_eq(Array(VerbKinds.validate({"kind": "summon", "count": "many"})), ["summon: count must be a number"])
