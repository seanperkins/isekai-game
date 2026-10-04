extends GutTest
## The goddess's scene as pure state: three panels, a cart, what it costs, and what confirming returns.

const P := GoddessModel.Pane

func _model(points: int, place_count := 2) -> GoddessModel:
	var places: Array = [{"id": "C1", "name": "Cave mouth"}, {"id": "G1", "name": "Grotto"}].slice(0, place_count)
	var soul := SoulProgress.new()
	soul.points = points
	return GoddessModel.new(places, [{"id": "slime", "name": "Slime"}], [{"id": "leap", "name": "Leap"}], soul, SoulRules.new())

func _head_start(m: GoddessModel) -> GoddessModel:
	m.switch_panel(-1)
	return m

func test_last_choice_preselects_its_rows() -> void:
	var places: Array = [{"id": "C1", "name": "Cave mouth"}, {"id": "G1", "name": "Grotto"}]
	var m := GoddessModel.new(places, [{"id": "slime", "name": "Slime"}], [], SoulProgress.new(), SoulRules.new(), {"pool": "G1", "species": "slime"})
	assert_eq(m.selected_place(), "G1")
	assert_eq(m.row(P.WHERE), 1)
	assert_eq(_model(0).selected_place(), "C1", "no last choice starts at the first")

func test_panels_wrap_and_rows_clamp() -> void:
	var m := _model(0)
	assert_eq(m.panel, P.WHERE)
	m.switch_panel(-1)
	assert_eq(m.panel, P.HEAD_START)
	m.switch_panel(1)
	assert_eq(m.panel, P.WHERE)
	m.move(-1)
	assert_eq(m.row(P.WHERE), 0)
	m.move(1)
	m.move(1)
	assert_eq(m.row(P.WHERE), 1, "clamped at the last of two places")
	m.switch_panel(1)
	m.move(1)
	assert_eq(m.row(P.WHO), 0, "one species, one row")
	m.switch_panel(-1)
	assert_eq(m.row(P.WHERE), 1, "each panel keeps its own row")

func test_levels_are_bought_up_to_the_cap() -> void:
	var m := _head_start(_model(0))
	m.adjust(1)
	m.adjust(1)
	assert_eq(m.cart["levels"], 2)
	assert_eq(m.cost(), 5, "2 + 3")
	for i in 3:
		m.adjust(1)
	assert_eq(m.cart["levels"], 4, "four prices, four levels")
	for i in 6:
		m.adjust(-1)
	assert_eq(m.cart["levels"], 0)

func test_a_power_is_taken_once_and_dropped() -> void:
	var m := _head_start(_model(0))
	m.move(1)
	m.adjust(1)
	m.adjust(1)
	assert_eq(m.cart["powers"], ["leap"])
	assert_eq(m.cost(), 3)
	m.adjust(-1)
	assert_eq(m.cart["powers"], [])

func test_head_start_rows_describe_the_cart() -> void:
	var m := _head_start(_model(0))
	assert_eq(m.rows(P.HEAD_START)[0], {"kind": "level", "levels": 0, "max": 4, "next_price": 2})
	assert_eq(m.rows(P.HEAD_START)[1], {"kind": "power", "id": "leap", "name": "Leap", "taken": false, "price": 3})
	for i in 4:
		m.adjust(1)
	assert_eq(m.rows(P.HEAD_START)[0]["next_price"], -1, "nothing left to buy at the cap")

func test_adjust_outside_head_start_does_nothing() -> void:
	var m := _model(0)
	m.adjust(1)
	assert_eq(m.cart, {"levels": 0, "powers": []})

func test_confirm_needs_the_points_and_does_not_spend() -> void:
	var poor := _head_start(_model(4))
	poor.adjust(1)
	poor.adjust(1)
	assert_false(poor.can_afford())
	assert_eq(poor.confirm(), {})
	var m := _head_start(_model(5))
	m.adjust(1)
	m.adjust(1)
	assert_eq(m.confirm(), {"altar": "C1", "species": "slime", "kit": {"level": 3}, "cost": 5})
	assert_eq(m.soul.total_points(), 5, "confirming spends nothing; the death flow does")

func test_an_empty_cart_still_confirms() -> void:
	assert_eq(_model(0).confirm(), {"altar": "C1", "species": "slime", "kit": {}, "cost": 0})

func test_nothing_to_choose_between_does_not_confirm() -> void:
	var m := GoddessModel.new([], [{"id": "slime", "name": "Slime"}], [], SoulProgress.new(), SoulRules.new())
	assert_eq(m.confirm(), {})

func test_need_menu() -> void:
	assert_false(_model(1, 1).need_menu(), "one place, one species, and 1 point buys nothing")
	assert_true(_model(2, 1).need_menu(), "2 points reach the first level's price")
	assert_true(_model(0).need_menu(), "two places to choose between")
	var no_levels := SoulRules.new()
	no_levels.level_prices = []
	var soul := SoulProgress.new()
	soul.points = 99
	var nothing_for_sale := GoddessModel.new([{"id": "C1", "name": "Cave mouth"}], [{"id": "slime", "name": "Slime"}], [], soul, no_levels)
	assert_false(nothing_for_sale.need_menu(), "points but nothing to spend them on")
