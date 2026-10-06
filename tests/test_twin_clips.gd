extends GutTest
## A twin whose form has its own animated sheet (assets/sheets/anim_<form>.png and data/form_clips.json) plays its clips, lit and mirrored with
## its normals; any other twin still draws as a still. tests/support/sheets holds a small fixture form.

var creatures := {}
var skills_by_id := {}
var _dir := ""
var _clips := ""

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	_dir = SpriteSheet.dir
	_clips = Enemy.form_clips_path
	SpriteSheet.dir = "res://tests/support/sheets/"
	Enemy.form_clips_path = "res://tests/support/sheets/form_clips.json"

func after_each() -> void:
	SpriteSheet.dir = _dir
	Enemy.form_clips_path = _clips

func _fixture_def() -> CreatureDef:
	var def := CreatureDef.new()
	def.id = "twin_fixture"
	def.form = "fixture_form"
	def.origin = "twin"
	def.stats = {"max_hp": 6, "atk": 2, "def": 0, "spd": 90}
	return def

func _enemy(def: CreatureDef) -> Enemy:
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	add_child_autofree(e)
	return e

func _frame(e: Enemy) -> Color:
	return ((e.get_node("Sprite") as Sprite2D).texture as CanvasTexture).diffuse_texture.get_image().get_pixel(0, 0)

func _step(e: Enemy, seconds := 0.0) -> void:
	e._update_visual(seconds)

func test_a_twin_with_an_animated_form_draws_its_idle_clip_lit() -> void:
	var e := _enemy(_fixture_def())
	_step(e)
	assert_true((e.get_node("Sprite") as Sprite2D).texture is CanvasTexture, "lit by the room's lights")
	assert_eq(e._anim_state, "idle")
	assert_eq(_frame(e), Color8(40, 100, 200), "the first idle frame")

func test_it_walks_when_it_moves() -> void:
	var e := _enemy(_fixture_def())
	e.velocity.x = 60.0
	_step(e)
	assert_eq(e._anim_state, "walk")

func test_the_clip_advances_with_time() -> void:
	var e := _enemy(_fixture_def())
	_step(e, 0.0)
	var first := _frame(e)
	_step(e, 0.6)
	assert_ne(_frame(e), first, "the second idle frame (2 fps: half a second per frame)")

func test_its_verb_winds_up_then_recovers() -> void:
	var e := _enemy(_fixture_def())
	e._verb_state = "windup"
	_step(e)
	assert_eq(e._anim_state, "windup")
	e._verb_state = "recover"
	_step(e)
	assert_eq(e._anim_state, "recover")

func test_a_recover_clip_plays_out_after_the_verb_has_ended() -> void:
	var e := _enemy(_fixture_def())
	e._verb_state = "recover"
	_step(e)
	e._verb_state = ""
	_step(e, 0.1)
	assert_eq(e._anim_state, "recover", "the one-shot is not finished: 2 frames at 4 fps is half a second")
	_step(e, 0.6)
	assert_eq(e._anim_state, "idle", "and then it is")

func test_a_hit_interrupts_a_clip() -> void:
	var e := _enemy(_fixture_def())
	e._verb_state = "recover"
	_step(e)
	e._hurt_t = 0.2
	_step(e)
	assert_eq(e._anim_state, "hurt")

func test_a_stun_with_no_stunned_clip_shows_the_hurt_one() -> void:
	var e := _enemy(_fixture_def())
	e.status.stun(5.0)
	_step(e)
	assert_eq(e._anim_state, "hurt", "stunned falls back to hurt")

func test_it_turns_with_a_mirrored_picture_and_flipped_normals() -> void:
	var e := _enemy(_fixture_def())
	e.facing = 1
	_step(e)
	var right := (e.get_node("Sprite") as Sprite2D).texture as CanvasTexture
	e.facing = -1
	_step(e)
	var sprite := e.get_node("Sprite") as Sprite2D
	assert_ne(sprite.texture, right)
	assert_false(sprite.flip_h, "mirrored in the texture so the normals can be mirrored with it")
	var n := (sprite.texture as CanvasTexture).normal_texture.get_image().get_pixel(0, 0)
	var was := right.normal_texture.get_image().get_pixel(3, 0)
	assert_eq(n.r8, 255 - was.r8)

func test_its_hurt_box_stays_the_bodys() -> void:
	var e := _enemy(_fixture_def())
	_step(e)
	assert_null(e._shapes, "an animated twin is hit as a still is: by its body, not by the frame")

func test_it_is_drawn_at_its_size_on_the_floor() -> void:
	var def := _fixture_def()
	def.sprite_size = 2.0
	var e := _enemy(def)
	_step(e)
	var sprite := e.get_node("Sprite") as Sprite2D
	assert_eq(sprite.scale, Vector2(2.0, 2.0))
	assert_eq(sprite.position.y, Enemy.BODY_BOTTOM - 6.0, "a 6 px tall frame at 2x stands on the floor")

func test_a_twin_with_no_animated_form_is_still_a_still() -> void:
	var e := _enemy(creatures["twin_wolf_fenrir"])
	_step(e)
	assert_false((e.get_node("Sprite") as Sprite2D).texture is CanvasTexture)
	assert_eq(e._anim_state, "")
