extends GutTest

var biped: MovementProfile
var slime: MovementProfile
var wolf: MovementProfile

func before_each() -> void:
	biped = MovementProfile.of("biped")
	slime = MovementProfile.of("slime")
	wolf = MovementProfile.of("wolf")

func test_the_base_jump_is_what_the_sim_measures() -> void:
	var b := MovementSim.flat_jump(MovementSim.base_profile())
	assert_almost_eq(b["rise"], 63.25, 0.05)
	assert_almost_eq(b["airtime"], 0.75, 0.001)
	assert_almost_eq(b["distance"], 105.0, 0.1)

func test_every_profile_keeps_the_base_rise() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	for p in [biped, slime, wolf]:
		var j := MovementSim.flat_jump(p)
		assert_almost_eq(j["rise"], base["rise"], 1.0, p.id)
		assert_gte(j["rise"], RoomLint.REACH_RISE, p.id)

func test_biped_is_the_base_held_jump_and_slime_matches_its_airtime() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	var j := MovementSim.flat_jump(biped)
	for key in base:
		assert_almost_eq(j[key], base[key], 0.0001, key)
	assert_almost_eq(MovementSim.flat_jump(slime)["airtime"], base["airtime"], 1.0 / 60.0 + 0.0001)

func test_the_wolf_trades_airtime_for_travel() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	var w := MovementSim.flat_jump(wolf)
	assert_lt(w["airtime"], base["airtime"])
	assert_gte(w["distance"], 1.2 * base["distance"])

func test_biped_and_slime_keep_the_standstill_gap() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	for p in [biped, slime]:
		assert_gte(MovementSim.flat_jump(p, 1.0, 100.0, 0.0)["distance"], 0.9 * base["distance"], p.id)

func test_the_jump_height_stat_still_scales_rise() -> void:
	for p in [biped, slime, wolf]:
		var ratio: float = MovementSim.flat_jump(p, sqrt(1.85))["rise"] / MovementSim.flat_jump(p)["rise"]
		assert_between(ratio, 1.7, 1.95, p.id)
