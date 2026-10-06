extends GutTest
## The art the new forms were given: one still per form in its species' sheet, as data on the form and as what the game draws.

const COUNTS := {"wolf": 21, "spider": 21, "goblin": 28, "undead": 29}
const NEW_SLIME := ["gleipnir", "ariadne", "beanstalk", "selkie", "kraken", "tiamat", "alkahest", "pestilence", "slime_mold", "talos",
	"philosophers_stone", "cube", "mimic", "poltergeist", "cloud_rider", "shoggoth", "king_slime", "quicksilver_slime"]

func _about(f: FormDef) -> Array:
	return Array(FormValidator.validate({f.id: f}, [], true)).filter(func(m: String) -> bool: return m.begins_with(f.id + ":"))

func _fixture(set_name: String, frame: String) -> FormDef:
	var f := FormDef.new()
	f.id = "fx"
	f.species = "wolf"
	f.stage = 2
	f.lineage = "x"
	f.parents = ["wolf"]
	f.sprite_set = set_name
	f.sprite_frame = frame
	return f

func test_every_new_form_has_its_still() -> void:
	var forms := FormLoader.load_all()
	for species in COUNTS:
		var of: Array = forms.values().filter(func(f: FormDef) -> bool: return f.species == species)
		assert_eq(of.size(), COUNTS[species], species)
		for f in of:
			assert_eq(f.sprite_set, "forms_%s" % species, f.id)
			assert_true(SpriteSheet.load_set(f.sprite_set).has_frame(f.sprite_frame), "%s: %s" % [f.id, f.sprite_frame])
	for id in NEW_SLIME:
		assert_eq(forms[id].sprite_set, "forms_slime", id)
		assert_eq(forms[id].sprite_frame, id, id)

func test_the_built_slime_forms_keep_their_own_animated_sheets() -> void:
	var forms := FormLoader.load_all()
	for id in forms:
		var f: FormDef = forms[id]
		if f.species == "slime" and not NEW_SLIME.has(id):
			assert_eq(f.sprite_frame, "", id)
			assert_ne(f.sprite_set, "forms_slime", id)

func test_a_frame_the_sheet_lacks_is_reported() -> void:
	assert_string_contains("\n".join(_about(_fixture("forms_wolf", "no_such_frame"))), "sprite frame 'no_such_frame' is not in sheet 'forms_wolf'")
	assert_eq(_about(_fixture("forms_wolf", "warg")).filter(func(m: String) -> bool: return m.contains("sprite")), [])

func test_a_frame_without_a_set_is_reported() -> void:
	assert_string_contains("\n".join(_about(_fixture("", "warg"))), "a sprite frame needs a sprite set")

func _region(t: Texture2D) -> Rect2:
	return (t as AtlasTexture).region

func test_look_uses_the_frame_when_there_is_one() -> void:
	var forms := FormLoader.load_all()
	var warg: Dictionary = FormEffects.look(forms["wolf_warg"], null)
	assert_eq(_region(warg["texture"]), _region(SpriteSheet.load_set("forms_wolf").frame_texture("warg")))
	var weaver: Dictionary = FormEffects.look(forms["weaver"], null)
	assert_eq(_region(weaver["texture"]), _region(SpriteSheet.load_set(forms["weaver"].sprite_set).frame_texture("idle_1")))

# --- drawn as the still (Task 2) ---

var rules: SkillRulesEngine
var player: Player

func _spawn(species: String) -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = species
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	_block(Rect2(-2000.0, BodyConfig.BOTTOM, 4000.0, 20.0))
	await wait_physics_frames(6)

func _block(r: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = r.position + r.size / 2.0
	var s := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	s.shape = rect
	b.add_child(s)
	add_child_autofree(b)
	return b

func _settle() -> void:
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	await wait_physics_frames(3)

func _tex_region(sprite: Sprite2D) -> Rect2:
	return (sprite.texture as AtlasTexture).region

func after_each() -> void:
	for a in ["move_right", "move_left", "tackle"]:
		Input.action_release(a)
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_a_wolf_form_is_drawn_from_its_animated_sheet_not_its_still() -> void:
	await _spawn("wolf")
	assert_true(player.advance_form("wolf_warg", true))
	await _settle()
	assert_eq(player.still_frame(), "", "its still is the picture of the form (the skill screen), not its body")
	assert_true(player.form_animates())
	assert_true(player.body_sheet().has_normals(), "lit")
	assert_gte(player.hurt_polygon().size(), 3)
	assert_eq(player.body_scale(), 1.0, "drawn at the sheet's own size")

func test_a_slime_form_with_a_still_is_drawn_as_it() -> void:
	await _spawn("slime")
	for id in ["weaver", "snare", "gleipnir"]:
		assert_true(player.advance_form(id, true), id)
	await _settle()
	var sprite: Sprite2D = player.get_node("Sprite")
	assert_eq(player.still_frame(), "gleipnir")
	assert_eq(_tex_region(sprite), (SpriteSheet.load_set("forms_slime").frame_texture("gleipnir") as AtlasTexture).region)
	assert_gte(player.hurt_polygon().size(), 3)

func test_a_form_with_no_still_keeps_the_animated_look() -> void:
	await _spawn("slime")
	assert_true(player.advance_form("weaver", true))
	await _settle()
	assert_eq(player.still_frame(), "")
	assert_true(player.body_sheet().has_frame("idle_1"), "its own animated sheet")
	await _spawn("wolf")
	assert_eq(player.still_frame(), "", "the base wolf animates")

func test_an_animated_spider_on_a_wall_is_turned_to_it_and_keeps_its_thread() -> void:
	await _spawn("spider")
	var forms := FormLoader.load_all()
	var stage2: Array = forms.values().filter(func(f: FormDef) -> bool: return f.species == "spider" and f.stage == 2)
	assert_true(player.advance_form(stage2[0].id, true))
	await _settle()
	assert_true(player.form_animates())
	_block(Rect2(60.0, -600.0, 40, 600.0 + BodyConfig.BOTTOM))
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_physics_frames(100)
	var sprite: Sprite2D = player.get_node("Sprite")
	assert_gt(absf(sprite.rotation), 1.0, "a quarter turn to the wall")
	assert_true(sprite.texture is CanvasTexture, "lit while it climbs")

func test_a_form_whose_sheet_cannot_be_found_falls_back_to_the_base_look() -> void:
	await _spawn("wolf")
	var broken: FormDef = player.forms["wolf_warg"].duplicate()
	broken.sprite_set = "no_such_sheet"
	player.forms["wolf_warg"] = broken
	assert_true(player.advance_form("wolf_warg", true))
	await _settle()
	assert_eq(player.still_frame(), "")
	assert_true(player.get_node("Sprite").visible)

func test_a_form_whose_frame_is_missing_keeps_the_base_look_even_on_a_species_body() -> void:
	await _spawn("wolf")
	var broken: FormDef = player.forms["wolf_warg"].duplicate()
	broken.sprite_frame = "no_such_frame"
	player.forms["wolf_warg"] = broken
	assert_true(player.advance_form("wolf_warg", true))
	await _settle()
	assert_eq(player.still_frame(), "")
	assert_true(player.body_sheet().has_frame("idle_1") or player.body_sheet().frame_names().size() > 0)

func test_evolving_from_a_still_form_to_an_animated_one_swaps_the_look_back() -> void:
	await _spawn("slime")
	for id in ["weaver", "snare", "gleipnir"]:
		assert_true(player.advance_form(id, true), id)
	await _settle()
	assert_eq(player.still_frame(), "gleipnir")
	player._use_form_sheet(player.forms["weaver"])
	assert_eq(player.still_frame(), "")
	assert_true(player.body_sheet().has_frame("idle_1"))

func test_a_species_body_does_not_take_an_animated_form_sheet_with_no_still() -> void:
	await _spawn("wolf")
	var odd: FormDef = player.forms["wolf_warg"].duplicate()
	odd.id = "wolf_odd"  # a form with no clips of its own
	odd.sprite_set = "form_weaver"  # the slime's animated sheet: its clips are not the wolf's
	odd.sprite_frame = ""
	player.forms["wolf_warg"] = odd
	assert_true(player.advance_form("wolf_warg", true))
	await _settle()
	assert_eq(player.still_frame(), "")
	assert_eq(player.body_sheet().frame_names(), SpriteSheet.load_set("gloom_wolf").frame_names(), "still the wolf's own sheet")
	Input.action_press("move_right")
	await wait_physics_frames(20)  # it runs on without a bad frame lookup
	assert_true(player.get_node("Sprite").visible)

func _bounds(points: PackedVector2Array) -> Rect2:
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	return r

func test_an_animated_spider_has_its_idle_frames_hurt_shape_swells_through_evolution_and_flashes_when_hit() -> void:
	await _spawn("spider")
	var base_scale: float = (player.get_node("Sprite") as Sprite2D).scale.x
	var forms := FormLoader.load_all()
	var stage2: Array = forms.values().filter(func(f: FormDef) -> bool: return f.species == "spider" and f.stage == 2)
	assert_true(player.advance_form(stage2[0].id, true))
	await wait_physics_frames(3)
	var sprite: Sprite2D = player.get_node("Sprite")
	assert_gt(sprite.scale.x, base_scale + 0.05, "swelling through the evolution moment")
	await _settle()
	var idle_frame: String = player._animator.clips["idle"]["frames"][0]
	player.global_position.y -= 80.0  # in the air, where a spider is not turned to a surface
	await wait_physics_frames(3)
	var traced: PackedVector2Array = player.body_sheet().hurt(idle_frame)
	Input.action_press("move_left")  # in the air, turning round: the shape is mirrored with the sprite
	await wait_physics_frames(12)
	assert_false(sprite.flip_h, "turned round in the texture, so its normals turn with it")
	var mirrored := PackedVector2Array()
	for p in traced:
		mirrored.append(Vector2(-p.x, p.y))
	var expected := ShapeHit.moved(mirrored, player.global_position + Vector2(0.0, Player.BODY_BOTTOM), 1.0)
	assert_eq(player.hurt_polygon(), expected, "the idle frame's own traced shape, mirrored, point for point")
	player.receive_hit(1, "physical", player.global_position + Vector2(40.0, 0.0))
	await wait_physics_frames(2)
	assert_lt(sprite.modulate.g, sprite.modulate.r, "red for a moment when hurt")

func test_the_base_spider_is_drawn_lit_and_turned_round_in_its_texture() -> void:
	await _spawn("spider")
	await _settle()
	var sprite: Sprite2D = player.get_node("Sprite")
	assert_true(player._sheet.has_normals(), "the base spider's sheet has a normal map")
	assert_true(sprite.texture is CanvasTexture, "so the room's lights shade it")
	player.global_position.y -= 80.0  # in the air, where a spider is not turned to a surface
	Input.action_press("move_left")
	await wait_physics_frames(12)
	Input.action_release("move_left")
	assert_true(sprite.texture is CanvasTexture)
	assert_false(sprite.flip_h, "turned round in the texture, so its normals turn with it")

func test_look_falls_back_to_the_base_when_the_requested_frame_is_missing() -> void:
	var broken: FormDef = FormLoader.load_all()["wolf_warg"].duplicate()
	broken.sprite_frame = "no_such_frame"
	var base := SpriteSheet.load_set("gloom_wolf")
	var look: Dictionary = FormEffects.look(broken, base)
	assert_eq(_region(look["texture"]), _region(base.frame_texture("idle_1")), "the base sheet's idle frame")
	assert_eq(look["tint"], broken.tint, "tinted as a form with no art is")
