extends GutTest
## The allies a verb calls (VerbAlly) as the packs need them: mortal ones that die to a touch, ones that wear a creature's look, that web, that pounce when
## the caller does, that follow the caller's lead, that carry parts, that appear late, that draw enemies, that hatch from cocoons or rise from corpses.

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	_floor()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000
	player.global_position = Vector2(-200, 0)

func _floor() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("verb_allies"):
		n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [4], 1)
	return a

func _allies() -> Array:
	return get_tree().get_nodes_in_group("verb_allies")

func _creature(id: String) -> CreatureDef:
	return DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]

func test_an_ally_that_is_hurt_by_a_touch_dies_to_the_first_one() -> void:
	player.global_position = Vector2(30, 0)  # beside the lizard
	_verb({"kind": "summon", "count": 1, "seconds": 5.0, "mortal": true}).activate()
	assert_eq(_allies().size(), 1)
	var ally: VerbAlly = _allies()[0]
	ally.global_position = lizard.global_position
	await wait_physics_frames(6)
	assert_eq(_allies().size(), 0, "the court dies in one hit")

func test_an_ordinary_ally_cannot_be_hurt() -> void:
	player.global_position = Vector2(30, 0)
	_verb({"kind": "summon", "count": 1, "seconds": 5.0}).activate()
	var ally: VerbAlly = _allies()[0]
	ally.global_position = lizard.global_position
	await wait_physics_frames(6)
	assert_eq(_allies().size(), 1)

func test_an_ally_wears_the_look_of_the_creature_it_is() -> void:
	_verb({"kind": "summon", "count": 1, "seconds": 5.0, "look": "skeleton"}).activate()
	var ally: VerbAlly = _allies()[0]
	var sprite := ally.get_child(0) as Sprite2D
	assert_not_null(sprite.texture)
	assert_ne(sprite.texture, Art.texture("slime_idle"), "not the slime stand-in")

func test_an_ally_that_webs_slows_what_it_strikes() -> void:
	player.global_position = Vector2(30, 0)
	_verb({"kind": "summon", "count": 1, "seconds": 5.0, "web": true}).activate()
	var ally: VerbAlly = _allies()[0]
	ally.global_position = lizard.global_position + Vector2(-10, 0)
	await wait_physics_frames(20)
	assert_gt(lizard._slow, 0.0, "webbed")

func test_an_echo_ally_pounces_when_the_caller_does() -> void:
	player.global_position = Vector2(-20, 0)
	_verb({"kind": "summon", "count": 2, "seconds": 5.0, "echo": true}).activate()
	for a in _allies():
		a.global_position = Vector2(-20, 0)
	player.echo_pounce()
	await wait_physics_frames(3)
	assert_lt(lizard.health.hp, 1000, "the echoes struck with the caller")

func test_an_ally_that_follows_a_lead_goes_for_the_callers_target_not_the_nearest() -> void:
	var near := Enemy.new()
	near.setup(lizard.def, {})
	near.position = Vector2(-150, 0)
	add_child_autofree(near)
	near.health.max_hp = 1000
	near.health.hp = 1000
	player.note_target(lizard)  # the caller's last blow was on the lizard, farther off
	_verb({"kind": "summon", "count": 1, "seconds": 5.0, "command": true}).activate()
	var ally: VerbAlly = _allies()[0]
	ally.global_position = Vector2(-160, 0)
	await wait_seconds(0.4)
	assert_gt(ally.global_position.x, -140.0, "it left the near one for the target")

func test_an_ally_that_carries_brings_a_lying_part_to_the_caller() -> void:
	lizard.global_position = Vector2(900, 0)
	var part: PartDef = load("res://data/parts/claw.tres")
	var pickup := PartPickup.new()
	pickup.setup(part, Vector2(-150, 0))
	add_child_autofree(pickup)
	pickup.delay = 0.0
	var before := player.parts_carried()
	player.global_position = Vector2(-300, 0)
	_verb({"kind": "summon", "count": 1, "seconds": 8.0, "carry": true}).activate()
	var ally: VerbAlly = _allies()[0]
	ally.global_position = Vector2(-290, 0)
	await wait_seconds(2.5)
	assert_eq(player.parts_carried(), before + 1, "the part was brought")

func test_an_ally_that_comes_late_comes_late() -> void:
	_verb({"kind": "summon", "count": 2, "seconds": 5.0, "delay": 0.4}).activate()
	assert_eq(_allies().size(), 0, "not yet")
	await wait_seconds(0.7)
	assert_eq(_allies().size(), 2, "now")

func test_an_ally_draws_the_enemies_near_it() -> void:
	player.global_position = Vector2(-100, 0)
	_verb({"kind": "summon", "count": 1, "seconds": 5.0, "lure": 300.0}).activate()
	assert_true(lizard.is_lured(), "a decoy")

func test_cocoons_hatch_into_young_and_without_one_nothing_hatches() -> void:
	_verb({"kind": "summon", "count": 3, "seconds": 5.0, "from_cocoons": 2}).activate()
	assert_eq(_allies().size(), 0, "no cocoon, no young")
	player.inventory.add_cocoon("lizard")
	player.inventory.add_cocoon("lizard")
	_verb({"kind": "summon", "count": 3, "seconds": 5.0, "from_cocoons": 2, "cooldown": 0.0}).activate()
	assert_eq(_allies().size(), 4, "two young for each cocoon")
	assert_eq(player.inventory.cocoons().size(), 0, "and the cocoons are spent")

func test_the_dead_stand_up_as_dancers_and_only_near_bodies() -> void:
	_verb({"kind": "raise", "range": 120.0, "seconds": 6.0}).activate()
	assert_eq(_allies().size(), 0, "only works near bodies")
	var corpse := Enemy.new()
	corpse.setup(lizard.def, {})
	corpse.position = Vector2(-150, 0)
	add_child_autofree(corpse)
	corpse.status.down()
	_verb({"kind": "raise", "range": 120.0, "seconds": 6.0, "cooldown": 0.0}).activate()
	assert_eq(_allies().size(), 1, "the body stands up")
	assert_eq(corpse.status.state, EnemyStatus.GONE, "and is no longer a body")

func test_a_summon_can_ride_on_another_verb() -> void:
	_verb({"kind": "burst", "range": 10.0, "summon": {"count": 2, "seconds": 5.0, "mortal": true}}).activate()
	assert_eq(_allies().size(), 2)

func test_the_new_spec_keys_validate() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "summon", "count": 2, "seconds": 5, "mortal": true, "look": "skeleton", "web": true, "echo": true, "command": true,
		"carry": true, "delay": 1.0, "lure": 200, "from_cocoons": 2})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "raise", "range": 100, "seconds": 8})), [])
	assert_ne(Array(VerbKinds.validate({"kind": "summon", "mortal": "yes"})), [])
