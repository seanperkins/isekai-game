extends GutTest

var events: Array
var h: Health

func before_each() -> void:
	events = []
	h = Health.new(30)
	h.emit_event = func(n: String, t: Dictionary) -> void: events.append([n, t])

func _names() -> Array:
	return events.map(func(e): return e[0])

func test_hit_reduces_hp_and_emits_damaged_once() -> void:
	h.take_hit(3, "physical")
	assert_eq(h.hp, 27)
	assert_eq(events, [["damaged", {"damage_type": "physical"}]])

func test_low_band_enters_below_30_percent_only_once() -> void:
	h.take_hit(21, "physical")  # 9: not below 30% of 30
	assert_false(_names().has("hp_low_entered"))
	h.take_hit(1, "physical")   # 8
	h.take_hit(1, "physical")   # 7, still latched
	assert_eq(_names().count("hp_low_entered"), 1)

func test_low_band_exits_at_60_percent_after_entry() -> void:
	h.take_hit(22, "physical")  # 8 -> entered
	h.heal(9)                   # 17: not yet
	assert_false(_names().has("hp_low_exited"))
	h.heal(1)                   # 18 = 60%
	assert_eq(_names().count("hp_low_exited"), 1)
	h.heal(5)
	assert_eq(_names().count("hp_low_exited"), 1)

func test_exit_requires_prior_entry() -> void:
	h.take_hit(5, "physical")
	h.heal(5)
	assert_false(_names().has("hp_low_exited"))

func test_raising_max_hp_re_evaluates_bands_without_healing() -> void:
	h.take_hit(21, "physical")  # 9 of 30: not low
	h.set_max_hp(33)            # 9 of 33 is below 30% (9.9)
	assert_eq(h.hp, 9)
	assert_eq(_names().count("hp_low_entered"), 1)

func test_lowering_max_hp_clamps_hp() -> void:
	# Review Focus 4
	h.set_max_hp(20)
	assert_eq(h.hp, 20)
	assert_eq(h.max_hp, 20)

func test_ticks_floor_at_one_and_never_emit_damaged() -> void:
	h.take_hit(27, "poison")  # 3
	events.clear()
	h.take_tick(2)
	h.take_tick(2)
	assert_eq(h.hp, 1)
	assert_false(_names().has("damaged"))
	assert_false(h.is_dead())

func test_death_emits_died_once_and_ignores_further_changes() -> void:
	var deaths := [0]
	h.died.connect(func() -> void: deaths[0] += 1)
	h.take_hit(40, "physical")
	h.take_hit(5, "physical")
	h.heal(10)
	assert_eq(h.hp, 0)
	assert_true(h.is_dead())
	assert_eq(deaths[0], 1)

func test_heal_caps_at_max() -> void:
	h.take_hit(4, "physical")
	h.heal(99)
	assert_eq(h.hp, 30)

func test_no_emitter_means_no_events() -> void:
	var enemy_health := Health.new(5)
	enemy_health.take_hit(4, "physical")
	enemy_health.heal(1)
	assert_eq(enemy_health.hp, 2)
