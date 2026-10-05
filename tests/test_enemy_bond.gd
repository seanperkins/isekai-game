extends GutTest
## When a creature can be bonded: alive, stunned, awake, and one that accepts a bond at all.

var skills_by_id := {}

func before_all() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy(bonds: Array = ["pack"]) -> Enemy:
	var e := Enemy.new()
	e.setup(TestDefs.creature("t_wolf", {"bonds": bonds}), skills_by_id)
	add_child_autofree(e)
	return e

func test_a_stunned_creature_that_accepts_a_bond_can_be_bonded() -> void:
	var e := _enemy()
	e.status.stun(10.0)
	assert_true(e.can_be_bonded())

func test_an_active_creature_cannot() -> void:
	assert_false(_enemy().can_be_bonded())

func test_a_stunned_creature_that_accepts_nothing_cannot() -> void:
	var e := _enemy([])
	e.status.stun(10.0)
	assert_false(e.can_be_bonded())

func test_a_dying_creature_cannot() -> void:
	var e := _enemy()
	e.receive_hit(999, "physical", Vector2.INF)
	assert_eq(e.status.state, EnemyStatus.DYING)
	assert_false(e.can_be_bonded())

func test_a_downed_corpse_cannot() -> void:
	var e := _enemy()
	e.receive_hit(999, "physical", Vector2.INF)
	e.finish_dying()
	assert_eq(e.status.state, EnemyStatus.DOWNED)
	assert_false(e.can_be_bonded())

func test_a_dormant_creature_cannot() -> void:
	var e := _enemy()
	e.status.stun(10.0)
	e.dormant = true
	assert_false(e.can_be_bonded())

func test_a_stun_that_wears_off_ends_the_chance() -> void:
	var e := _enemy()
	e.status.stun(0.5)
	e._physics_process(1.0)
	assert_false(e.can_be_bonded())

func test_bonding_takes_the_creature_out_of_the_room_once() -> void:
	var e := _enemy()
	e.status.stun(10.0)
	var def := e.consume()
	assert_eq(def.id, "t_wolf")
	assert_true(e.is_queued_for_deletion())
	assert_false(e.can_be_bonded(), "gone, so it cannot be bonded or eaten again")
