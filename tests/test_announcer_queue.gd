extends GutTest

var q: AnnouncerQueue

func before_each() -> void:
	q = AnnouncerQueue.new()

func test_shows_one_popup_at_a_time_in_order() -> void:
	q.push_unlock("a", "A!")
	q.push_unlock("b", "B!")
	assert_eq(q.current()["id"], "a")
	q.advance(2.4)
	assert_eq(q.current()["id"], "a")
	q.advance(0.1)
	assert_eq(q.current()["id"], "b")
	q.advance(2.5)
	assert_eq(q.current(), {})

func test_overflow_merges_into_more_without_losing_count() -> void:
	for id in ["a", "b", "c", "d", "e", "f"]:
		q.push_unlock(id, id)
	var p := q.pending()
	assert_eq(p.size(), 4)
	assert_eq(p.slice(0, 3).map(func(e): return e["id"]), ["a", "b", "c"])
	assert_eq(p[3]["kind"], "more")
	assert_eq(p[3]["count"], 3)
	assert_eq(p[3]["text"], "+3 more (see Compendium)")

func test_levels_and_slot_replacements_go_to_ticker_only() -> void:
	q.push_level("leap", 2)
	q.push_slot_replaced("water_blade", "poison_breath")
	assert_eq(q.current(), {})
	assert_eq(q.pop_ticker(), {"kind": "level", "id": "leap", "level": 2})
	assert_eq(q.pop_ticker(), {"kind": "slot_replaced", "new_id": "water_blade", "old_id": "poison_breath"})
	assert_eq(q.pop_ticker(), {})

func test_clear_empties_everything() -> void:
	q.push_unlock("a", "A")
	q.push_level("leap", 2)
	q.clear()
	assert_eq(q.current(), {})
	assert_eq(q.pop_ticker(), {})
