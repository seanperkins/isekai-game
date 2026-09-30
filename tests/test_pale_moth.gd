extends GutTest
## The Pale Moth: the Spore Moth's behaviour on its own paler, larger, derived sheet.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	func receive_hit(_raw: int, _t: String, _from: Vector2 = Vector2.INF, _c: String = "") -> void:
		pass
	func receive_poison(_a: int, _t: int, _s: float) -> void:
		pass

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func test_the_def_has_the_approved_numbers() -> void:
	var c: CreatureDef = creatures["pale_moth"]
	assert_eq([c.stats["max_hp"], c.stats["atk"], c.stats["def"], c.stats["spd"], c.xp], [7, 1, 0, 110, 8])
	assert_eq(c.essences, {"spore": 3, "flight": 2})
	assert_true(c.drifter)
	assert_true(Sources.ALL.has("pale_moth"))

func test_its_sheet_has_the_moths_frames_at_least_1_3_times_as_wide() -> void:
	var moth := SpriteSheet.load_set("spore_moth")
	var pale := SpriteSheet.load_set("pale_moth")
	assert_eq(pale.frame_names().size(), moth.frame_names().size())
	for n in moth.frame_names():
		assert_true(pale.has_frame(n), n)
		assert_gte(pale.frame_size(n).x, moth.frame_size(n).x * 1.3, n)

func test_its_clips_match_the_moths_and_pick_returns_fly() -> void:
	var clips := SlimeAnimator.load_clips(Enemy.CLIPS)
	assert_eq(clips["pale_moth"], clips["spore_moth"])
	assert_eq(EnemyState.pick("pale_moth", EnemyStatus.ACTIVE, "", "idle", false, false, false, false, true, false), "fly")

func test_it_is_paler_than_the_moth() -> void:
	var moth := SpriteSheet.load_set("spore_moth").frame_texture("fly_1").get_image()
	var pale := SpriteSheet.load_set("pale_moth").frame_texture("fly_1").get_image()
	assert_gt(_mean_luma(pale), _mean_luma(moth) + 0.05, "a lightened copy reads paler")

func _mean_luma(im: Image) -> float:
	var sum := 0.0
	var n := 0
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.5:
				sum += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				n += 1
	return sum / maxf(1.0, float(n))

func test_an_enemy_built_from_it_drifts_like_the_moth_and_drops_puffs() -> void:
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.add_to_group("player")
	player.global_position = Vector2(100, -60)
	var m := Enemy.new()
	m.use_sheet = false
	m.setup(creatures["pale_moth"], skills_by_id)
	m.position = Vector2(0, -60)
	add_child_autofree(m)
	var puffs := [0]
	var on_event := func(n: String, _t: Dictionary) -> void:
		if n == "spore_puff":
			puffs[0] += 1
	EventBus.world_event.connect(on_event)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0) + 30)
	EventBus.world_event.disconnect(on_event)
	assert_almost_eq(m.global_position.y, -60.0, 16.0, "no falling, no diving")
	assert_gte(puffs[0], 1)
