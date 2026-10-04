extends GutTest

func _on_floor(speed: float, step: float) -> Array:
	var s := MoveState.new()
	s.velocity.x = speed
	var i := MoveInput.new()
	i.on_floor = true
	i.dir = 1.0
	i.step_ahead = step
	return [s, i]

func test_a_step_of_24_is_hopped_with_the_impulse_and_the_speed_kept() -> void:
	var wolf := MovementProfile.of("wolf")
	var st := _on_floor(200.0, 24.0)
	VaultStep.step(st[0], st[1], wolf)
	assert_almost_eq((st[0] as MoveState).velocity.y, -sqrt(2.0 * 1344.0 * 30.0), 0.01)
	assert_eq((st[0] as MoveState).velocity.x, 200.0)
	assert_eq((st[0] as MoveState).launched, "vault")

func test_a_step_of_25_is_a_wall() -> void:
	var st := _on_floor(200.0, 25.0)
	VaultStep.step(st[0], st[1], MovementProfile.of("wolf"))
	assert_eq((st[0] as MoveState).velocity.y, 0.0)
	assert_eq((st[0] as MoveState).launched, "")

func test_under_150_px_s_it_does_not_vault() -> void:
	var wolf := MovementProfile.of("wolf")
	var slow := _on_floor(149.9, 20.0)
	VaultStep.step(slow[0], slow[1], wolf)
	assert_eq((slow[0] as MoveState).launched, "")
	var fast := _on_floor(150.0, 20.0)
	VaultStep.step(fast[0], fast[1], wolf)
	assert_eq((fast[0] as MoveState).launched, "vault")
	var leftward := _on_floor(-150.0, 20.0)
	VaultStep.step(leftward[0], leftward[1], wolf)
	assert_eq((leftward[0] as MoveState).launched, "vault", "speed is the magnitude")

func test_it_never_vaults_in_the_air_or_with_no_step() -> void:
	var wolf := MovementProfile.of("wolf")
	var air := _on_floor(200.0, 20.0)
	(air[1] as MoveInput).on_floor = false
	VaultStep.step(air[0], air[1], wolf)
	assert_eq((air[0] as MoveState).launched, "")
	var flat := _on_floor(200.0, 0.0)
	VaultStep.step(flat[0], flat[1], wolf)
	assert_eq((flat[0] as MoveState).launched, "")

func test_a_jump_press_on_the_same_tick_is_the_jump_not_a_vault() -> void:
	var wolf := MovementProfile.of("wolf")
	var st := _on_floor(200.0, 20.0)
	(st[1] as MoveInput).jump_pressed = true
	VerbRunner.step(st[0], st[1], wolf, 1.0 / 60.0)
	assert_eq((st[0] as MoveState).launched, "ground")
	assert_almost_eq((st[0] as MoveState).velocity.y, -403.0, 0.01, "the full jump, not the vault's smaller hop")

func test_the_runner_vaults_a_step_for_the_wolf_after_the_ground_step() -> void:
	var wolf := MovementProfile.of("wolf")
	var st := _on_floor(200.0, 20.0)
	VerbRunner.step(st[0], st[1], wolf, 1.0 / 60.0)
	assert_eq((st[0] as MoveState).launched, "vault")
	assert_almost_eq((st[0] as MoveState).velocity.y, -sqrt(2.0 * 1344.0 * 26.0), 0.01)

func test_only_the_wolf_vaults() -> void:
	for id in ["biped", "slime", "spider"]:
		var st := _on_floor(200.0, 20.0)
		VerbRunner.step(st[0], st[1], MovementProfile.of(id), 1.0 / 60.0)
		assert_eq((st[0] as MoveState).launched, "", id)
		assert_eq((st[0] as MoveState).velocity.y, 0.0, id)
