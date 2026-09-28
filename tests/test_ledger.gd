extends GutTest

var ledger: Ledger

func before_each() -> void:
	ledger = Ledger.new()

func test_counter_uses_superset_tag_matching() -> void:
	ledger.record("damaged", {"damage_type": "poison"})
	ledger.record("damaged", {"damage_type": "physical"})
	ledger.record("jumped", {"from": "ground"})
	assert_eq(ledger.counter("damaged", {}), 2)
	assert_eq(ledger.counter("damaged", {"damage_type": "poison"}), 1)
	assert_eq(ledger.counter("jumped", {"from": "wall"}), 0)

func test_extra_event_tags_still_match_and_missing_keys_never_match() -> void:
	# Review Focus 5
	ledger.record("inspected", {"target": "bat", "first_time": true, "appraisal_target": true, "extra": 1})
	ledger.record("inspected", {"target": "self"})
	assert_eq(ledger.counter("inspected", {"first_time": true, "appraisal_target": true}), 1)
	assert_eq(ledger.counter("inspected", {"no_such_key": true}), 0)

func test_reset_counter_counts_since_last_reset_event() -> void:
	for i in 4:
		ledger.record("predated", {"kind": "creature"})
	ledger.record("damaged", {"damage_type": "physical"})
	ledger.record("predated", {"kind": "terrain"})
	ledger.record("predated", {"kind": "creature"})
	ledger.record("jumped", {})
	ledger.record("predated", {"kind": "creature"})
	assert_eq(ledger.reset_counter("predated", {"kind": "creature"}, "damaged"), 2)
	assert_eq(ledger.counter("predated", {"kind": "creature"}), 6)

func test_reset_counter_with_no_reset_event_counts_everything() -> void:
	ledger.record("predated", {"kind": "creature"})
	assert_eq(ledger.reset_counter("predated", {}, "damaged"), 1)

func test_clear_empties_all_counts() -> void:
	ledger.record("jumped", {})
	ledger.clear()
	assert_eq(ledger.counter("jumped", {}), 0)

func test_recorded_tags_are_copied() -> void:
	var tags := {"damage_type": "poison"}
	ledger.record("damaged", tags)
	tags["damage_type"] = "physical"
	assert_eq(ledger.counter("damaged", {"damage_type": "poison"}), 1)
