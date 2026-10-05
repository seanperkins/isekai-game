extends GutTest
## CreatureDef's verb, form, origin and art fields, and what the validator says about them.

var skills: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")

## The validator's errors with one shipped creature swapped for `fields` set on it.
func _errors(fields: Dictionary) -> PackedStringArray:
	var creatures: Array = []
	for c in TestDefs.all_creatures():
		creatures.append(TestDefs.creature("bat", fields) if c.id == "bat" else c)
	return DefValidator.validate(skills, creatures)

func _has(errors: PackedStringArray, part: String) -> bool:
	for e in errors:
		if e.contains(part):
			return true
	return false

func test_a_plain_creature_has_no_verb_form_or_art() -> void:
	var c := CreatureDef.new()
	assert_eq(c.verb, "")
	assert_eq(c.form, "")
	assert_eq(c.origin, "")
	assert_eq(c.species, "")
	assert_eq(c.role, "")
	assert_eq(c.sprite_set, "")
	assert_eq(c.sprite_frame, "")
	assert_eq(c.wears, "")
	assert_eq(c.sprite_size, 1.0)
	assert_eq(c.sprite_tint, Color.WHITE)

func test_the_validator_accepts_a_twin_with_a_known_verb_and_a_real_still() -> void:
	var errors := _errors({"origin": "twin", "form": "wolf_fenrir", "verb": "verb_wolf_fenrir", "sprite_set": "forms_wolf", "sprite_frame": "fenrir"})
	assert_eq(errors, PackedStringArray(), "no errors")

func test_an_unknown_verb_is_an_error() -> void:
	assert_true(_has(_errors({"verb": "verb_nothing"}), "verb 'verb_nothing' is not a skill"))

func test_a_verb_that_is_not_a_data_verb_is_an_error() -> void:
	assert_true(_has(_errors({"verb": "leap"}), "has no verb spec"))

func test_a_sprite_set_that_is_not_a_sheet_is_an_error() -> void:
	assert_true(_has(_errors({"sprite_set": "forms_nothing", "sprite_frame": "x"}), "sprite_set 'forms_nothing' is not a sheet"))

func test_a_frame_the_sheet_lacks_is_an_error() -> void:
	assert_true(_has(_errors({"sprite_set": "forms_wolf", "sprite_frame": "nothing"}), "has no frame 'nothing'"))

func test_wearing_a_creature_that_is_not_shipped_is_an_error() -> void:
	assert_true(_has(_errors({"wears": "twin_wolf_fenrir"}), "wears 'twin_wolf_fenrir'"))
	assert_false(_has(_errors({"wears": "lizard"}), "wears"))

func test_an_origin_outside_the_three_is_an_error() -> void:
	assert_true(_has(_errors({"origin": "wild"}), "origin 'wild'"))

func test_a_twin_needs_its_form() -> void:
	assert_true(_has(_errors({"origin": "twin"}), "a twin needs a form"))
	assert_false(_has(_errors({"origin": "support"}), "needs a form"))
