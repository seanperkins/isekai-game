extends GutTest
## First match wins, in the order of the spec's table (1.1).

func _pick(over: Dictionary = {}) -> String:
	var a := {"eating": false, "hurt": false, "roped": false, "wall": false, "dashing": false,
		"spread": false, "on_floor": true, "vy": 0.0, "land": 0.0, "speed": 0.0}
	a.merge(over, true)
	return SlimeState.pick(a["eating"], a["hurt"], a["roped"], a["wall"], a["dashing"], a["spread"],
		a["on_floor"], a["vy"], a["land"], a["speed"])

func test_each_row_of_the_table() -> void:
	assert_eq(_pick(), "idle")
	assert_eq(_pick({"speed": 60.0}), "run")
	assert_eq(_pick({"speed": -60.0}), "run")
	assert_eq(_pick({"speed": 2.0}), "idle")
	assert_eq(_pick({"land": 0.05}), "land")
	assert_eq(_pick({"on_floor": false, "vy": -100.0}), "rise")
	assert_eq(_pick({"on_floor": false, "vy": 100.0}), "fall")
	assert_eq(_pick({"spread": true}), "spread")
	assert_eq(_pick({"dashing": true}), "tackle")
	assert_eq(_pick({"wall": true, "on_floor": false}), "wall")
	assert_eq(_pick({"roped": true, "on_floor": false}), "rope")
	assert_eq(_pick({"hurt": true}), "hurt")
	assert_eq(_pick({"eating": true}), "cover")

func test_earlier_rows_beat_later_ones() -> void:
	var everything := {"eating": true, "hurt": true, "roped": true, "wall": true, "dashing": true,
		"spread": true, "on_floor": false, "vy": -1.0, "land": 0.1, "speed": 99.0}
	assert_eq(_pick(everything), "cover")
	everything["eating"] = false
	assert_eq(_pick(everything), "hurt")
	everything["hurt"] = false
	assert_eq(_pick(everything), "rope")
	everything["roped"] = false
	assert_eq(_pick(everything), "wall")
	everything["wall"] = false
	assert_eq(_pick(everything), "tackle")
	everything["dashing"] = false
	assert_eq(_pick(everything), "spread")
	everything["spread"] = false
	assert_eq(_pick(everything), "rise")

func test_all_lists_every_state_once() -> void:
	assert_eq(SlimeState.ALL.size(), 11)
	var seen := {}
	for s in SlimeState.ALL:
		assert_false(seen.has(s))
		seen[s] = true
