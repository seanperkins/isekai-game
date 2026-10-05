extends GutTest
## The bestiary page (docs/bestiary, built by tools/build_bestiary.py) draws the game's own numbers: its body sizes are copied
## from the code and its sheets from assets/sheets, so a change in either must be followed by a rebuild.

const BUILDER := "res://tools/build_bestiary.py"
const DATA := "res://docs/bestiary/bestiary-data.js"

func _builder_pair(name: String) -> Vector2:
	var m := RegEx.create_from_string(name + r" = \((\d+), (\d+)\)").search(FileAccess.get_file_as_string(BUILDER))
	assert_not_null(m, name)
	return Vector2(float(m.get_string(1)), float(m.get_string(2)))

func test_the_page_uses_the_games_body_sizes() -> void:
	assert_eq(_builder_pair("ENEMY_BODY"), Enemy.BODY_SIZE, "every enemy's terrain body")
	assert_eq(_builder_pair("PLAYER_BODY"), BodyConfig.size(), "the player's body")

## The sheet ids the builder leaves off the page: sprites that are not creatures (the opening's battle).
func _not_creatures() -> Array:
	var m := RegEx.create_from_string(r"NOT_CREATURES = \{([^}]*)\}").search(FileAccess.get_file_as_string(BUILDER))
	assert_not_null(m, "NOT_CREATURES")
	var ids: Array = []
	for hit in RegEx.create_from_string(r'"(\w+)"').search_all(m.get_string(1)):
		ids.append(hit.get_string(1))
	return ids

func test_every_sheet_is_on_the_page_and_the_copies_are_current() -> void:
	var data := FileAccess.get_file_as_string(DATA)
	var sheets := DirAccess.get_files_at("res://assets/sheets")
	var skipped := _not_creatures()
	assert_true(skipped.has("commuter") and skipped.has("truck"), "the opening's battle sprites are not creatures")
	var count := 0
	for file in sheets:
		if not file.ends_with(".png"):
			continue
		var id := file.get_basename()
		if skipped.has(id):
			assert_false(data.contains('"id":"%s"' % id), "%s is not a creature, so it is not on the page" % id)
			continue
		count += 1
		assert_true(data.contains('"id":"%s"' % id), "%s is in the page data (rebuild: python3 tools/build_bestiary.py)" % id)
		assert_eq(FileAccess.get_md5("res://docs/bestiary/sheets/%s.png" % id), FileAccess.get_md5("res://assets/sheets/%s.png" % id), "%s.png is current" % id)
	assert_gt(count, 20)
