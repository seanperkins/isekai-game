extends GutTest
## A model with saving off (the Menagerie) still records in memory but never reaches its store.

class FakeStore:
	var saves := 0
	func load_states(_names: Array) -> Dictionary:
		return {}
	func load_creatures() -> Dictionary:
		return {}
	func save_states(_states: Dictionary, _names: Array, _records: Dictionary) -> void:
		saves += 1

func test_saving_off_records_in_memory_and_never_saves() -> void:
	var store := FakeStore.new()
	var model := CompendiumModel.new([], [TestDefs.creature("bat")], store)
	model.saving = false
	model.on_creature_seen("bat")
	model.on_creature_defeated("bat")
	model.on_game_event(Events.PREDATED, {"source": "bat", "kind": "creature"})
	assert_eq(model.creature_record("bat")["defeated"], 1, "it still counts")
	assert_eq(model.creature_record("bat")["eaten"], 1)
	assert_eq(store.saves, 0, "but nothing is saved")

func test_saving_is_on_by_default() -> void:
	var store := FakeStore.new()
	var model := CompendiumModel.new([], [TestDefs.creature("bat")], store)
	assert_true(model.saving)
	model.on_creature_defeated("bat")
	assert_eq(store.saves, 1)
