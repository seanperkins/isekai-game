extends GutTest
## An altar's menu as pure state: attune once, bank essence per element, buy the local perk. Banking and buying need an attuned altar.

var engine: SkillRulesEngine
var soul: SoulProgress
var progress: WorldProgress
var rules := SoulRules.new()
var attuned_calls := [0]

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test(msg)
	engine.setup(skills)
	engine.start_run()
	soul = SoulProgress.new(null, ["stats"])
	progress = WorldProgress.new()
	attuned_calls = [0]

func _perk() -> PerkDef:
	var p := PerkDef.new()
	p.id = "stats"
	p.display_name = "Stronger base stats"
	p.price_base = 5
	p.price_step = 3
	return p

func _model(altar_id := "C1", with_perk := true) -> AltarModel:
	return AltarModel.new(altar_id, _perk() if with_perk else null, progress, soul, rules, engine,
		func() -> void: attuned_calls[0] += 1)

func _absorb(element: String, n: int) -> void:
	for i in n:
		engine.handle_event("absorbed", {"essence": element, "source": "test"})

func _kinds(m: AltarModel) -> Array:
	return m.rows().map(func(r: Dictionary) -> String: return r["kind"])

func test_rows_are_attune_five_elements_then_the_perk() -> void:
	assert_eq(_kinds(_model()), ["attune", "element", "element", "element", "element", "element", "perk"])
	assert_eq(_model().rows().slice(1, 6).map(func(r: Dictionary) -> String: return r["element"]), Essences.ALL)
	assert_eq(_kinds(_model("C1", false)), ["attune", "element", "element", "element", "element", "element"], "no perk, no perk row")

func test_attuning_records_it_once_and_calls_back() -> void:
	var m := _model("G1")
	assert_false(m.attuned())
	assert_true(m.act())
	assert_true(progress.is_attuned("G1"))
	assert_eq(attuned_calls[0], 1)
	assert_eq(m.message, "Attuned.")
	assert_false(m.act(), "a second attune does nothing")
	assert_eq(attuned_calls[0], 1)

func test_the_default_altar_is_already_attuned() -> void:
	var m := _model("C1")
	assert_true(m.rows()[0]["done"])
	assert_false(m.act())

func test_banking_and_buying_do_nothing_until_attuned() -> void:
	_absorb("water", 27)
	soul.add(20)
	var m := _model("G1")
	m.move(1)
	m.adjust(1)
	m.adjust(1)
	assert_false(m.act())
	assert_eq(m.message, "Attune first.")
	assert_eq(engine.held("water"), 27)
	assert_eq(soul.total_points(), 20)
	for i in 5:
		m.move(1)
	assert_eq(m.row(), 6)
	assert_false(m.act())
	assert_eq(m.message, "Attune first.")
	assert_eq(soul.perk_count("stats"), 0)

func test_adjust_steps_by_the_bank_rate_within_what_is_held() -> void:
	_absorb("water", 27)
	var m := _model()
	m.move(1)  # Water
	var units := func() -> int: return m.rows()[1]["units"]
	m.adjust(1)
	assert_eq(units.call(), 10)
	m.adjust(1)
	assert_eq(units.call(), 20)
	m.adjust(1)
	assert_eq(units.call(), 20, "27 held banks at most 20")
	m.adjust(-1)
	m.adjust(-1)
	assert_eq(units.call(), 0)
	m.adjust(-1)
	assert_eq(units.call(), 0)
	m.move(1)  # Earth: nothing held
	m.adjust(1)
	assert_eq(m.rows()[2]["units"], 0)

func test_banking_an_element_turns_the_amount_into_points() -> void:
	_absorb("water", 27)
	var m := _model()
	m.move(1)
	m.adjust(1)
	m.adjust(1)
	assert_eq(m.rows()[1]["points"], 2)
	assert_true(m.act())
	assert_eq(soul.total_points(), 2)
	assert_eq(engine.held("water"), 7)
	assert_eq(m.rows()[1]["units"], 0)
	assert_eq(m.message, "Banked 2 soul points.")
	assert_false(m.act(), "nothing chosen to bank")
	assert_eq(m.message, "Nothing to bank.")

func test_buying_the_perk_follows_the_price_curve() -> void:
	soul.add(20)
	var m := _model()
	for i in 6:
		m.move(1)
	assert_eq(m.rows()[6]["price"], 5)
	assert_true(m.act())
	assert_eq(soul.total_points(), 15)
	assert_eq(m.message, "Stronger base stats bought. It applies from your next life.")
	assert_true(m.act())
	assert_eq(soul.total_points(), 7, "the second costs 8")
	assert_false(m.act(), "the third costs 11")
	assert_eq(m.message, "Not enough soul points.")
	assert_eq(soul.total_points(), 7)
	assert_eq(m.rows()[6]["times"], 2)
	assert_eq(m.rows()[6]["price"], 11)

func test_move_clamps() -> void:
	var m := _model()
	m.move(-1)
	assert_eq(m.row(), 0)
	m.move(99)
	assert_eq(m.row(), 6)
	var plain := _model("C1", false)
	plain.move(99)
	assert_eq(plain.row(), 5, "without a perk the last row is Dark")

func test_points_reads_the_souls_total() -> void:
	soul.add(7)
	assert_eq(_model().points(), 7)
