extends GutTest

const DT := 1.0 / 60.0

var slime: MovementProfile
var wolf: MovementProfile

func before_each() -> void:
	slime = MovementProfile.of("slime")
	wolf = MovementProfile.of("wolf")

## An airborne input with a wall on `side` (-1 left, 1 right, 0 none) and the stick at `dir`.
func _wall(side: int, dir := 0.0) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = false
	i.wall_side = side
	i.dir = dir
	return i

func _step(s: MoveState, i: MoveInput, p := slime, boost := 1.0) -> void:
	GroundAirStep.step(s, i, p, DT, 1.0, boost)

func test_a_fall_onto_a_wall_sticks_for_twelve_ticks_then_slides_at_90() -> void:
	var s := MoveState.new()
	s.velocity.y = 300.0
	var i := _wall(-1, -1.0)
	for k in 12:
		_step(s, i)
		assert_eq(s.velocity.y, 15.0, "stuck, tick %d" % (k + 1))
		assert_true(s.clinging)
	var top := 0.0
	var rose := false
	for _k in 40:
		_step(s, i)
		top = maxf(top, s.velocity.y)
		rose = rose or s.velocity.y > 15.0
		assert_true(s.clinging)
	assert_true(rose, "it starts to slide")
	assert_eq(top, 90.0)

func test_it_does_not_cling_without_pressing_toward_the_wall() -> void:
	for dir in [0.0, 1.0]:
		var s := MoveState.new()
		for _k in 30:
			_step(s, _wall(-1, dir))
		assert_gt(s.velocity.y, 200.0, "dir %s" % dir)
		assert_false(s.clinging)

func test_it_does_not_cling_while_rising() -> void:
	var s := MoveState.new()
	s.velocity.y = -200.0
	_step(s, _wall(-1, -1.0))
	assert_lt(s.velocity.y, 0.0)
	assert_false(s.clinging)

func test_leaving_the_wall_rearms_the_stick() -> void:
	var s := MoveState.new()
	s.velocity.y = 300.0
	for _k in 20:
		_step(s, _wall(-1, -1.0))
	for _k in 3:
		_step(s, _wall(0, -1.0))
	assert_false(s.clinging)
	s.velocity.y = 100.0
	_step(s, _wall(-1, -1.0))
	assert_eq(s.velocity.y, 15.0)

func test_a_species_without_the_wall_verb_ignores_walls() -> void:
	var s := MoveState.new()
	for _k in 30:
		_step(s, _wall(-1, -1.0), wolf)
	assert_gt(s.velocity.y, 200.0)
	assert_false(s.clinging)
