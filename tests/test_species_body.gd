extends GutTest
## SpeciesBody: the probes, the step and the move the sandbox and the Player share, on a small built world.

class Driver extends Node2D:
	var sb: SpeciesBody
	var input := MoveInput.new()
	func _physics_process(delta: float) -> void:
		var i := input.copy()
		input.jump_pressed = false  # one-shot, like the real buttons
		input.signature_pressed = false
		sb.fill_input(i)
		sb.think(i, delta)
		sb.move()

var driver: Driver
var body: CharacterBody2D
var box: RectangleShape2D
var shape: CollisionShape2D

func _block(r: Rect2, layer := 1) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layer
	b.position = r.position + r.size / 2.0
	var s := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	s.shape = rect
	b.add_child(s)
	add_child_autofree(b)
	return b

## A body of `profile_id` standing on a floor whose top is y 0, at x `x`.
func _spawn(profile_id: String, x := 0.0) -> void:
	_block(Rect2(-600, 0, 1600, 40))
	driver = Driver.new()
	add_child_autofree(driver)
	body = CharacterBody2D.new()
	body.collision_mask = 7
	shape = CollisionShape2D.new()
	box = RectangleShape2D.new()
	box.size = BodyConfig.size()
	shape.shape = box
	body.add_child(shape)
	body.position = Vector2(x, -BodyConfig.BOTTOM)
	driver.add_child(body)
	driver.sb = SpeciesBody.new(body, shape, box)
	driver.sb.set_profile(MovementProfile.of(profile_id))
	await _frames(3)

func _frames(n: int) -> void:
	for _k in n:
		await get_tree().physics_frame

func _probe() -> MoveInput:
	var i := MoveInput.new()
	driver.sb.fill_input(i)
	return i

func test_for_species_maps_each_species_and_refuses_the_unknown() -> void:
	for pair in [["slime", "slime"], ["wolf", "wolf"], ["goblin", "biped"], ["undead", "biped"], ["spider", "spider"]]:
		assert_eq(MovementProfile.for_species(pair[0]).id, pair[1], pair[0])
	assert_null(MovementProfile.for_species("newt"))
	assert_null(MovementProfile.for_species(""))

func test_fill_input_reads_the_floor_and_a_clear_ceiling() -> void:
	await _spawn("slime")
	var i := _probe()
	assert_true(i.on_floor)
	assert_eq(i.wall_side, 0)
	assert_eq(i.clearance_above, 1000.0)

func test_fill_input_reads_a_low_ceiling_and_a_wall() -> void:
	await _spawn("wolf")
	_block(Rect2(-600, -BodyConfig.BOTTOM * 2.0 - 8.0, 1600, 4))  # a ceiling a few px over the head
	_block(Rect2(BodyConfig.size().x / 2.0 + 3.0, -200, 40, 200))  # a wall 3 px from the right edge
	await _frames(2)
	var i := _probe()
	assert_eq(i.clearance_above, 0.0, "it could not stand up under that")
	assert_eq(i.wall_side, 1, "the wolf reads walls on the floor, for its pounce")

func test_a_slime_walks_at_its_top_speed_and_jumps() -> void:
	await _spawn("slime")
	driver.input.dir = 1.0
	await _frames(40)
	assert_almost_eq(body.velocity.x, 140.0, 1.0)
	var y0 := body.global_position.y
	driver.input.jump_pressed = true
	await _frames(12)
	assert_lt(body.global_position.y, y0 - 20.0, "it rose")
	assert_eq(driver.sb.state.facing, 1)

func test_a_wolf_pounce_moves_along_the_aim_and_starts_a_cooldown() -> void:
	await _spawn("wolf")
	driver.input.dir = 1.0
	await _frames(10)
	driver.input.aim = Vector2.RIGHT
	driver.input.signature_pressed = true
	await _frames(2)
	assert_eq(driver.sb.state.verb, "pounce")
	assert_gt(absf(body.velocity.x), 300.0)
	await _frames(30)
	assert_eq(driver.sb.state.verb, "", "it is over")
	assert_gt(float(driver.sb.state.cooldowns.get("pounce", 0.0)), 0.0, "and cooling down")

func test_a_biped_roll_uses_the_flat_box() -> void:
	await _spawn("biped")
	driver.input.signature_pressed = true
	await _frames(2)
	assert_eq(driver.sb.state.verb, "roll")
	assert_eq(box.size, BodyConfig.spread_size())
	assert_almost_eq(shape.position.y, BodyConfig.BOTTOM - box.size.y / 2.0, 0.01, "its bottom stays on the floor")
	await _frames(40)
	assert_eq(driver.sb.state.verb, "", "the roll ended")
	assert_eq(box.size, BodyConfig.size(), "and it stands again")

func test_a_biped_mantles_a_ledge_it_is_pressed_against() -> void:
	await _spawn("biped", 0.0)
	var edge := BodyConfig.size().x / 2.0 + 2.0
	_block(Rect2(edge, -30, 200, 30))  # a ledge whose top is 30 px up, its wall 2 px from the body
	body.global_position = Vector2(0.0, -10.0 - BodyConfig.BOTTOM)  # a hop up, feet 10 px above the floor
	await _frames(1)
	driver.sb.state.velocity = Vector2.ZERO
	var i := _probe()
	assert_ne(i.mantle, Vector2.ZERO, "the lip is within reach")
	driver.input.dir = 1.0
	driver.input.jump_pressed = true
	await _frames(40)
	var feet := body.global_position.y + BodyConfig.BOTTOM
	assert_almost_eq(feet, -30.0, 2.0, "standing on the ledge")
	assert_gt(body.global_position.x, edge, "past its lip")

func test_a_spider_crawls_onto_a_wall() -> void:
	await _spawn("spider", 0.0)
	_block(Rect2(60, -300, 40, 340))  # a wall rising from the floor ahead
	driver.input.dir = 1.0
	await _frames(90)
	assert_true(driver.sb.is_crawling())
	assert_lt(driver.sb.state.surface_n.x, -0.9, "on the wall's left face")
	assert_lt(body.global_position.y, -BodyConfig.BOTTOM - 20.0, "and climbing it")
	assert_eq(box.size, SurfaceStep.box_size(driver.sb.state.surface_n), "with the box shaped to the wall")
	assert_eq(body.velocity, Vector2.ZERO, "the crawl owns the body, gravity does not")

func test_the_move_reports_a_landing_once() -> void:
	await _spawn("slime")
	body.global_position.y -= 80.0
	var landings := 0
	var impact := 0.0
	for _k in 60:
		await get_tree().physics_frame
		if driver.sb.landed():
			landings += 1
			impact = driver.sb.fall_speed
	assert_eq(landings, 1)
	assert_gt(impact, 100.0, "with the speed it hit at")
