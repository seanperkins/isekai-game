extends GutTest
## Style D visuals: sprite frames for the slime and enemies, tiled room solids, lights, camera.

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.set_physics_process(false)
	return e

func _sprite(n: Node) -> Sprite2D:
	return n.get_node("Sprite")

func test_player_frame_rules() -> void:
	assert_eq(Player.pick_frame(true, true, 0.0), "slime_eat")
	assert_eq(Player.pick_frame(false, false, 0.0), "slime_jump")
	assert_eq(Player.pick_frame(false, true, 0.1), "slime_land")
	assert_eq(Player.pick_frame(false, true, 0.0), "slime_idle")

func test_player_draws_the_slime_and_flips_with_facing() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(p)
	assert_eq(_sprite(p).texture, Art.texture("slime_idle"))
	p.facing = -1
	p._update_visual(0.016)
	assert_true(_sprite(p).flip_h)

func test_enemy_frames_follow_behaviour() -> void:
	var bat := _enemy("bat")
	bat._anim_t = 0.0
	assert_eq(bat.frame_name(), "bat_1")
	bat._anim_t = 0.3
	assert_eq(bat.frame_name(), "bat_2")
	var toad := _enemy("toad")
	assert_eq(toad.frame_name(), "toad_idle")
	toad._spit_cd = Enemy.SPIT_COOLDOWN
	assert_eq(toad.frame_name(), "toad_spit")
	var spider := _enemy("spider")
	assert_eq(spider.frame_name(), "spider_hang")
	spider._on_ceiling = false
	assert_eq(spider.frame_name(), "spider_crawl")
	assert_eq(_enemy("serpent").frame_name(), "serpent")

func test_enemy_sprite_shows_state() -> void:
	var bat := _enemy("bat")
	assert_not_null(_sprite(bat).texture)
	assert_true(_sprite(bat).flip_h)  # sprites face right; enemies start facing left
	bat.receive_tackle(1, true)
	bat._update_visual()
	assert_ne(_sprite(bat).modulate, Color.WHITE)
	bat.receive_hit(9, "physical")
	bat._update_visual()
	assert_true(_sprite(bat).flip_v)

func test_room_visual_kinds() -> void:
	assert_eq(RoomBuilder.visual_kind(Rect2(0, 320, 1600, 40)), "ground")
	assert_eq(RoomBuilder.visual_kind(Rect2(260, 266, 120, 12)), "ground")
	assert_eq(RoomBuilder.visual_kind(Rect2(760, 140, 16, 180)), "column")
	assert_eq(RoomBuilder.visual_kind(Rect2(-20, 0, 20, 360)), "wall")
	assert_eq(RoomBuilder.visual_kind(Rect2(1600, 0, 20, 360)), "wall")
	assert_eq(RoomBuilder.visual_kind(Rect2(0, -20, 1600, 20)), "wall")
	assert_eq(RoomBuilder.visual_kind(Rect2(3200, 0, 20, 1080), 3200.0), "wall")
	assert_eq(RoomBuilder.visual_kind(Rect2(1700, 986, 120, 12), 3200.0), "ground")

func test_room_solids_are_textured() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var node := RoomBuilder.build_room(rooms["C1"], {})
	add_child_autofree(node)
	for b in node.get_children().filter(func(n): return n is StaticBody2D):
		var rects: Array = b.get_children().filter(func(n): return n is TextureRect)
		assert_eq(rects.size(), 1)
		assert_not_null(rects[0].texture)

func test_game_is_lit_framed_and_fully_sprited() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	assert_eq(game.find_children("*", "CanvasModulate", true, false).size(), 1)
	var lit: Array = game.world.rooms["C1"].decor.filter(func(d): return d.has("light"))
	assert_gte(game.find_children("*", "PointLight2D", true, false).size(), lit.size() + 1)
	var cam: Camera2D = game.world.camera
	assert_eq(cam.zoom, Vector2(1, 1))  # 640x360 internal resolution
	assert_true(game.world.current_rect().has_point(cam.global_position))
	for n in get_tree().get_nodes_in_group("predatable"):
		assert_not_null(_sprite(n).texture, str(n))
	assert_false(game.find_children("*", "ColorRect", true, false).any(func(r): return r.get_parent() is Enemy or r.get_parent() is Player))

func test_cave_backdrop_is_textured_behind_the_room() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(1)
	var backs: Array = game.world.room.get_children().filter(func(n): return n is TextureRect and n.z_index < 0)  # each room carries its own backdrop
	assert_eq(backs.size(), 1)
	assert_eq(backs[0].texture, Art.texture("wall"))
	assert_gt(game.AMBIENT.v, 0.5)
