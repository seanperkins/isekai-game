extends GutTest
## Every kind of verb the game can cast says which gesture its animation plays (tools/verb_anims.json): a kind added to VerbKinds needs a row there.

func _table() -> Dictionary:
	var f := FileAccess.open("res://tools/verb_anims.json", FileAccess.READ)
	assert_not_null(f, "tools/verb_anims.json exists")
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func test_every_kind_has_a_gesture() -> void:
	var kinds: Dictionary = _table().get("kinds", {})
	for kind: String in VerbKinds.KINDS:
		assert_true(kinds.has(kind), "%s needs a gesture in tools/verb_anims.json" % kind)
		assert_true(str(kinds.get(kind, "")) != "", kind)

func test_the_table_names_no_kind_the_game_does_not_have() -> void:
	for kind: String in _table().get("kinds", {}):
		assert_true(VerbKinds.KINDS.has(kind), "%s is not a verb kind" % kind)

func test_the_kinds_an_enemy_casts_are_among_them() -> void:
	for kind: String in VerbKinds.ENEMY_KINDS:
		assert_true(_table().get("kinds", {}).has(kind), kind)
