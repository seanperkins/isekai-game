extends GutTest
## The Bog Lizardman holds its beat and throws a flat, physical spear on its own cooldown; the toad's glob is untouched.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	var poisons: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(a: int, t: int, s: float) -> void:
		poisons.append([a, t, s])

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func _solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _floor() -> void:
	_solid(Rect2(-600, 6, 1200, 20))

func test_the_lizardman_is_a_spitter_with_no_poison_spit() -> void:
	var l := _enemy("bog_lizardman", Vector2.ZERO)
	assert_eq(l.kind, Enemy.Kind.SPITTER)

func test_a_spitblob_is_unchanged_a_toads_glob_arcs_and_poisons() -> void:
	var blob := SpitBlob.new()
	assert_eq(blob.gravity, SpitBlob.GRAVITY)
	add_child_autofree(blob)
	blob.launch(Vector2(0, 0), Vector2(100, 0), 3, 1, 3.0)
	fake_player.global_position = Vector2(100, 0)
	await wait_physics_frames(60)
	assert_false(fake_player.poisons.is_empty())

func test_the_windup_throw_and_cooldown_use_the_spear_constants() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	fake_player.global_position = Vector2(100, 0)  # in sight, level, inside SPEAR_RANGE (140) but outside the toad's 90
	var winding := false
	for i in 120:
		await wait_physics_frames(1)
		if l.telegraphing():
			winding = true
			break
	assert_true(winding, "it raises its spear first")
	await wait_physics_frames(int(Enemy.SPIT_WINDUP * 60.0) + 5)
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is Spear).size(), 1, "one spear in flight")
	assert_almost_eq(l._spit_cd, Enemy.SPEAR_COOLDOWN, 0.2)

func test_the_throw_pose_shows_after_the_throw_for_the_pose_window() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	l._spit_cd = Enemy.SPEAR_COOLDOWN
	assert_true(l._spit_cd > l._spit_cooldown() - Enemy.SPIT_POSE_SECONDS, "right after a throw")
	l._spit_cd = Enemy.SPEAR_COOLDOWN - Enemy.SPIT_POSE_SECONDS - 0.01
	assert_false(l._spit_cd > l._spit_cooldown() - Enemy.SPIT_POSE_SECONDS, "the pose ends with the window")

func test_it_does_not_throw_at_a_player_off_level_or_out_of_range() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	fake_player.global_position = Vector2(100, -60)  # 60 above: past SPEAR_LEVEL, inside the range
	await wait_physics_frames(90)
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is Spear).size(), 0)
	assert_true(fake_player.hits.is_empty(), "no spear was thrown (one would have hit and gone)")
	fake_player.global_position = Vector2(300, 0)  # past SPEAR_RANGE
	await wait_physics_frames(90)
	assert_true(fake_player.hits.is_empty())
	assert_eq(l._spit_cd, 0.0, "it never started a cooldown")

func test_the_spear_flies_a_straight_aimed_line_and_hits_physical_for_the_creatures_atk() -> void:
	var spear := Spear.new()
	add_child_autofree(spear)
	spear.launch(Vector2(0, 0), Vector2(100, -30), 3, 0, 0.0)
	assert_eq(spear.gravity, 0.0)
	var dir := (Vector2(100, -30)).normalized()
	assert_almost_eq(spear.velocity.normalized().x, dir.x, 0.001)
	assert_almost_eq(spear.velocity.length(), Spear.SPEED, 0.01)
	fake_player.global_position = Vector2(100, -30)
	await wait_physics_frames(60)
	assert_eq(fake_player.hits, [[3, "physical"]])
	assert_true(fake_player.poisons.is_empty())

func test_the_spear_dies_on_rock() -> void:
	_solid(Rect2(40, -50, 20, 100))
	var spear := Spear.new()
	add_child_autofree(spear)
	spear.launch(Vector2(0, 0), Vector2(200, 0), 3, 0, 0.0)
	fake_player.global_position = Vector2(200, 0)
	await wait_physics_frames(60)
	assert_true(fake_player.hits.is_empty(), "the rock stopped it")
	assert_false(is_instance_valid(spear) and spear.is_inside_tree())

func test_an_alerted_lizardman_stands_still_facing_the_player_and_never_chases() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	l._spit_cd = 99.0  # on cooldown: _spitter_act returns false and _walk runs
	fake_player.global_position = Vector2(-100, 0)
	await wait_physics_frames(30)
	assert_eq(l.velocity.x, 0.0, "it holds its post while alerted")
	assert_eq(l.facing, -1, "and faces you")
	assert_almost_eq(l.global_position.x, 0.0, 0.5)

func test_an_unalerted_lizardman_patrols_its_beat() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	fake_player.global_position = Vector2(2000, 0)
	await wait_physics_frames(60)
	assert_ne(l.velocity.x, 0.0)
