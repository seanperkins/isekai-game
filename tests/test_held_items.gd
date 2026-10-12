extends GutTest
## data/held_items.json through HeldItems: the items the held-item layer can draw, their grips, and what each goblin form holds by default.

const TABLE := "res://data/held_items.json"

func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TABLE))

func test_an_item_has_a_set_a_frame_and_a_grip_beside_its_picture() -> void:
	var axe := HeldItems.item("axe")
	assert_false(axe.is_empty())
	var sheet := SpriteSheet.load_set(axe["set"])
	assert_not_null(sheet)
	assert_true(sheet.has_frame(axe["frame"]))
	var size := sheet.frame_size(axe["frame"])
	var grip: Vector2 = axe["grip"]
	assert_between(grip.x, -size.x / 2.0 - 8.0, size.x / 2.0 + 8.0)
	assert_between(grip.y, -size.y - 8.0, 8.0)

func test_the_smith_holds_a_hammer_and_tongs_and_has_a_scale_for_them() -> void:
	var smith := HeldItems.form("goblin_smith")
	assert_eq(smith["primary"], "hammer")
	assert_eq(smith["secondary"], "tongs")
	assert_between(float(smith["scale"]), 0.3, 3.0)

func test_the_base_goblin_and_the_empty_form_id_are_one_form_that_holds_nothing_but_has_a_scale() -> void:
	assert_eq(HeldItems.form(""), HeldItems.form("goblin"))
	assert_eq(HeldItems.form("goblin")["primary"], "")
	assert_eq(HeldItems.form("goblin")["secondary"], "")
	assert_gt(float(HeldItems.form("goblin")["scale"]), 0.0)
	assert_true(_table()["forms"].has("goblin"), "an entry of its own, so an item swapped in has a scale")

func test_an_unknown_item_or_form_is_safe() -> void:
	assert_true(HeldItems.item("nonesuch").is_empty())
	assert_eq(HeldItems.form("nonesuch"), {"scale": 1.0, "handed": "n", "primary": "", "secondary": ""})

func test_every_form_names_items_that_exist_and_every_item_set_loads_lit() -> void:
	var table := _table()
	for form_id in table["forms"]:
		var f := HeldItems.form(form_id)
		for role in ["primary", "secondary"]:
			if f[role] != "":
				assert_false(HeldItems.item(f[role]).is_empty(), "%s holds %s in %s" % [form_id, f[role], role])
	for id in table["items"]:
		var item := HeldItems.item(id)
		var sheet := SpriteSheet.load_set(item["set"])
		assert_not_null(sheet, id)
		assert_true(sheet.has_frame(item["frame"]), id)
		assert_true(sheet.has_normals(), "%s is lit" % id)

func test_every_animated_goblin_form_has_an_entry_and_its_sheet_has_hands_on_every_frame() -> void:
	var clips := SlimeAnimator.load_clips(Enemy.form_clips_path)
	var table := _table()
	var seen := 0
	for form in clips:
		if not str(form).begins_with("goblin_"):
			continue
		seen += 1
		assert_true(table["forms"].has(form), "%s has an entry" % form)
		var sheet := SpriteSheet.load_set("anim_" + str(form))
		for n in sheet.frame_names():
			assert_true(sheet.hands(n).has("n") and sheet.hands(n).has("f"), "%s/%s has both hands" % [form, n])
	assert_gt(seen, 20)

func test_the_base_goblins_sheet_has_hands_on_every_frame() -> void:
	var sheet := SpriteSheet.load_set("goblin")
	for n in sheet.frame_names():
		assert_true(sheet.hands(n).has("n") and sheet.hands(n).has("f"), n)

func test_the_table_has_two_handed_for_the_spear_and_the_staff_only() -> void:
	var variant := RegEx.create_from_string("_[0-9a-f]{6}$")   # a variant's id is its piece's name and a hash of its look: spear_26b9ab
	for id in _table()["items"]:
		var piece := variant.sub(id, "")
		assert_eq(HeldItems.item(id)["two_handed"], piece in ["spear", "staff"], id)

func test_every_form_has_handed_and_roles_and_the_paladin_is_far_handed() -> void:
	var table := _table()
	for form_id in table["forms"]:
		var f := HeldItems.form(form_id)
		assert_true(f["handed"] in ["n", "f"], form_id)
		assert_false(table["forms"][form_id].has("n") or table["forms"][form_id].has("f"), "%s: no near/far keys left" % form_id)
	var paladin := HeldItems.form("goblin_paladin")
	assert_eq([paladin["handed"], paladin["primary"], paladin["secondary"]], ["f", "club", "shield"])
	assert_eq(HeldItems.form("goblin_smith")["handed"], "n")
