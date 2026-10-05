extends GutTest
## The art the new forms were given: one still per form in its species' sheet, as data on the form and as what the game draws.

const COUNTS := {"wolf": 21, "spider": 21, "goblin": 28, "undead": 29}
const NEW_SLIME := ["gleipnir", "ariadne", "beanstalk", "selkie", "kraken", "tiamat", "alkahest", "pestilence", "slime_mold", "talos",
	"philosophers_stone", "cube", "mimic", "poltergeist", "cloud_rider", "shoggoth", "king_slime", "quicksilver_slime"]

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

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
