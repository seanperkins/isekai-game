extends GutTest

var events: Array
var sensors: PlayerSensors

func before_each() -> void:
	events = []
	sensors = PlayerSensors.new()
	sensors.emit_event = func(n: String, t: Dictionary) -> void: events.append([n, t])

func test_wall_touched_fires_once_per_airborne_contact() -> void:
	sensors.physics_update(true, false)
	sensors.physics_update(true, false)
	sensors.physics_update(true, false)
	sensors.physics_update(false, false)
	sensors.physics_update(true, false)
	assert_eq(events.size(), 2)
	assert_eq(events[0], ["wall_touched", {}])

func test_wall_contact_on_the_floor_does_not_count() -> void:
	sensors.physics_update(true, true)
	sensors.physics_update(true, false)  # still the same contact, now airborne: no new edge
	assert_eq(events.size(), 0)

func test_jumped_and_inspected_first_time() -> void:
	sensors.jumped("ground")
	sensors.inspected("bat", true)
	sensors.inspected("bat", true)
	sensors.inspected("serpent", false)
	assert_eq(events[0], ["jumped", {"from": "ground"}])
	assert_eq(events[1], ["inspected", {"target": "bat", "first_time": true, "appraisal_target": true}])
	assert_eq(events[2][1]["first_time"], false)
	assert_eq(events[3][1], {"target": "serpent", "first_time": true, "appraisal_target": false})

func test_predation_hold_scales_with_predation_time() -> void:
	var hold := PredationHold.new()
	var target := RefCounted.new()
	hold.start(target, 70)  # Glutton Lv1: 0.7 s
	assert_false(hold.update(0.6))
	assert_true(hold.update(0.1))
	hold.cancel()
	assert_false(hold.active())
	assert_false(hold.update(5.0))

func test_stun_then_recover() -> void:
	var s := EnemyStatus.new()
	s.stun()
	assert_true(s.predatable())
	s.update(1.9)
	assert_eq(s.state, EnemyStatus.STUNNED)
	s.update(0.2)
	assert_eq(s.state, EnemyStatus.ACTIVE)
	assert_false(s.predatable())

func test_downed_vanishes_after_five_seconds_and_hold_pauses_it() -> void:
	var s := EnemyStatus.new()
	s.down()
	s.update(4.0)
	s.held = true
	s.update(10.0)
	assert_eq(s.state, EnemyStatus.DOWNED)
	s.held = false  # a cancelled hold keeps the remaining 1 s
	s.update(0.9)
	assert_eq(s.state, EnemyStatus.DOWNED)
	s.update(0.2)
	assert_eq(s.state, EnemyStatus.GONE)

func test_stun_never_overrides_downed_or_gone() -> void:
	var s := EnemyStatus.new()
	s.down()
	s.stun()
	assert_eq(s.state, EnemyStatus.DOWNED)
	s.consume()
	s.stun()
	s.down()
	assert_eq(s.state, EnemyStatus.GONE)
	assert_false(s.predatable())
