extends GutTest
## State -> clip for every creature. Pure logic; the clip table is checked against the sheets in
## test_enemy_sheets.gd.

const ACTIVE := EnemyStatus.ACTIVE

func _pick(creature: String, o: Dictionary = {}) -> String:
	return EnemyState.pick(creature, o.get("status", ACTIVE), o.get("charge", ""), o.get("swoop", "idle"),
		o.get("spit_windup", false), o.get("spit_recent", false), o.get("on_ceiling", false),
		o.get("on_floor", true), o.get("moving", false), o.get("hurt", false))

func test_status_beats_behaviour_for_every_creature() -> void:
	for c in ["bat", "toad", "lizard", "spider"]:
		assert_eq(_pick(c, {"status": EnemyStatus.DOWNED, "charge": "charge", "swoop": "dive"}), "downed", c)
		assert_eq(_pick(c, {"status": EnemyStatus.STUNNED, "charge": "charge", "swoop": "dive"}), "stunned", c)
		assert_eq(_pick(c, {"hurt": true, "charge": "charge"}), "hurt", c)

func test_a_dying_creature_shows_its_hurt_pose_until_its_effect_takes_over() -> void:
	assert_eq(_pick("toad", {"status": EnemyStatus.DYING}), "hurt")

func test_bat_states() -> void:
	assert_eq(_pick("bat"), "fly")
	assert_eq(_pick("bat", {"swoop": "hover"}), "hover")
	assert_eq(_pick("bat", {"swoop": "warn"}), "warn")
	assert_eq(_pick("bat", {"swoop": "dive"}), "dive")
	assert_eq(_pick("bat", {"swoop": "climb"}), "fly")

func test_toad_states() -> void:
	assert_eq(_pick("toad"), "idle")
	assert_eq(_pick("toad", {"moving": true}), "walk")
	assert_eq(_pick("toad", {"spit_windup": true}), "puff")
	assert_eq(_pick("toad", {"spit_recent": true}), "spit")
	assert_eq(_pick("toad", {"spit_windup": true, "moving": true}), "puff", "puffing up beats walking")

func test_lizard_states() -> void:
	assert_eq(_pick("lizard"), "idle")
	assert_eq(_pick("lizard", {"moving": true}), "walk")
	assert_eq(_pick("lizard", {"charge": "windup"}), "windup")
	assert_eq(_pick("lizard", {"charge": "charge", "moving": true}), "charge")
	assert_eq(_pick("lizard", {"charge": "rest"}), "rest")

func test_spider_states() -> void:
	assert_eq(_pick("spider", {"on_ceiling": true}), "hang")
	assert_eq(_pick("spider", {"on_floor": false}), "drop")
	assert_eq(_pick("spider", {"moving": true}), "crawl")
	assert_eq(_pick("spider"), "crawl")

func test_an_unknown_creature_falls_back_to_idle() -> void:
	assert_eq(_pick("serpent"), "idle")
	assert_eq(_pick("serpent", {"status": EnemyStatus.DOWNED}), "downed")

func test_the_grotto_creatures_have_arms_and_do_not_fall_back_to_idle() -> void:
	assert_eq(_pick("spore_moth"), "fly")
	assert_eq(_pick("spore_moth", {"moving": true, "on_floor": false}), "fly")
	assert_eq(_pick("mushroom_crab", {"charge": "windup"}), "windup")
	assert_eq(_pick("mushroom_crab", {"charge": "charge", "moving": true}), "charge")
	assert_eq(_pick("mushroom_crab", {"charge": "rest"}), "rest")
	assert_eq(_pick("mushroom_crab", {"moving": true}), "walk")
	assert_eq(_pick("mushroom_crab"), "idle")
	assert_eq(_pick("vine_snake", {"charge": "windup", "on_ceiling": true}), "coil")
	assert_eq(_pick("vine_snake", {"charge": "charge", "on_ceiling": true, "moving": true}), "lunge")
	assert_eq(_pick("vine_snake", {"charge": "rest", "on_ceiling": true, "moving": true}), "rest")
	assert_eq(_pick("vine_snake", {"on_ceiling": true}), "hide")
	assert_eq(_pick("vine_snake", {"status": EnemyStatus.STUNNED, "charge": "charge"}), "stunned")
	assert_eq(_pick("pale_moth"), "fly")
