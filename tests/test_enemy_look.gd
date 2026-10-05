extends GutTest
## A creature wears its art: a still from a sheet, the frames of a shipped creature it wears, or a placeholder when its art is missing.

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy_of(def: CreatureDef) -> Enemy:
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	add_child_autofree(e)
	return e

func _enemy(id: String) -> Enemy:
	return _enemy_of(creatures[id])

func test_a_twin_shows_its_forms_still_at_its_size() -> void:
	var e := _enemy("twin_wolf_fenrir")
	await wait_physics_frames(2)
	var sprite: Sprite2D = e.get_node("Sprite")
	var want := SpriteSheet.load_set("forms_wolf").frame_texture("fenrir") as AtlasTexture
	assert_eq((sprite.texture as AtlasTexture).region, want.region)
	var size: float = creatures["twin_wolf_fenrir"].sprite_size
	assert_almost_eq(sprite.scale.x, size, 0.0001)
	assert_almost_eq(sprite.scale.y, size, size * Enemy.STILL_BREATH + 0.001, "it breathes a little (tests/test_enemy_still_motion.gd)")
	assert_almost_eq(sprite.position.y, Enemy.BODY_BOTTOM - want.region.size.y * sprite.scale.y / 2.0, 0.01, "its feet are on the ground")

func test_a_still_turns_with_the_creature() -> void:
	var e := _enemy("twin_wolf_fenrir")
	e.facing = 1
	await wait_physics_frames(2)
	assert_false((e.get_node("Sprite") as Sprite2D).flip_h)
	e.facing = -1
	await wait_physics_frames(2)
	assert_true((e.get_node("Sprite") as Sprite2D).flip_h)

func test_a_twin_without_a_still_wears_the_slime_sheet_in_its_tint() -> void:
	var def: CreatureDef = creatures["twin_tide"] if creatures.has("twin_tide") else creatures["twin_weaver"]
	var e := _enemy_of(def)
	await wait_physics_frames(2)
	var sprite: Sprite2D = e.get_node("Sprite")
	assert_not_null(sprite.texture)
	assert_eq(sprite.modulate, def.sprite_tint)

func test_a_support_monster_wears_the_frames_of_a_shipped_creature_tinted() -> void:
	var rat: CreatureDef = creatures["cave_rat"]
	var e := _enemy_of(rat)
	await wait_physics_frames(2)
	var sprite: Sprite2D = e.get_node("Sprite")
	assert_eq(e._look_id(), rat.wears)
	assert_not_null(sprite.texture, "it is visible")
	assert_eq(sprite.modulate, rat.sprite_tint)

func test_a_creature_whose_art_is_missing_is_a_visible_placeholder_not_an_error() -> void:
	var def := CreatureDef.new()
	def.id = "twin_missing"
	def.stats = {"max_hp": 3, "atk": 1, "def": 0, "spd": 100}
	def.sprite_set = "forms_nothing"
	def.sprite_frame = "nothing"
	var e := _enemy_of(def)
	await wait_physics_frames(2)
	assert_eq(e._look_id(), Enemy.PLACEHOLDER_LOOK)
	assert_not_null((e.get_node("Sprite") as Sprite2D).texture)

func test_a_shipped_creature_looks_as_it_did() -> void:
	var e := _enemy("lizard")
	await wait_physics_frames(2)
	var sprite: Sprite2D = e.get_node("Sprite")
	assert_eq(e._look_id(), "lizard")
	assert_eq(e.frame_name(), "lizard_1")
	assert_eq(sprite.scale, Vector2.ONE)
	assert_eq(sprite.modulate, Color.WHITE)

func test_a_stunned_twin_takes_the_stun_tint_over_its_own() -> void:
	var e := _enemy("twin_wolf_fenrir")
	e.status.stun(5.0)
	await wait_physics_frames(2)
	assert_eq((e.get_node("Sprite") as Sprite2D).modulate, Enemy.STUNNED_TINT)

func test_every_creature_is_drawn() -> void:
	for id in Sources.ALL:
		var e := _enemy(id)
		await wait_physics_frames(1)
		var sprite := e.get_node_or_null("Sprite") as Sprite2D
		assert_not_null(sprite, id)
		if sprite != null:
			assert_not_null(sprite.texture, "%s has a texture" % id)
		e.queue_free()
