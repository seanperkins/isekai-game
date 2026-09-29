class_name EnemyScenarios
extends RefCounted
## The scripted scenarios the enemy characterization runs. A scenario is a Dictionary:
##   name, creature (a def id), start (Vector2, the body centre; the floor top is at y 6), facing (1 or -1), ticks,
##   seed (for the enemy's RNG), player: [[tick, Vector2], ...] (the stub player's moves), acts: scripted interruptions:
##   ["stun", tick, seconds], ["slow", tick, seconds], ["stun_when", key, value, delay, seconds],
##   ["kill_when", key, value, delay], ["player_when", key, value, delay, Vector2]
## where key is one of charge_state, swoop_state, anim_state, telegraphing. Positions are kept off exact thresholds
## (the charger's 120 px, the snake's 80 px reach) because float32 rounding decides those.

static func _s(name: String, creature: String, start: Vector2, player: Array, ticks: int, acts: Array = [], facing := 1) -> Dictionary:
	return {"name": name, "creature": creature, "start": start, "player": player, "ticks": ticks, "acts": acts,
		"facing": facing, "seed": 1234}

static func all() -> Array:
	var far := Vector2(3000, 0)
	return [
		# walker: the serpent has no sheet, so anim_state() is "" for it
		_s("walker_patrol", "serpent", Vector2(0, 0), [[0, far]], 400),
		_s("walker_chase", "serpent", Vector2(0, 0), [[0, Vector2(100, 0)], [150, Vector2(-100, 0)]], 300),
		# spitter
		_s("toad_spit", "toad", Vector2(0, 0), [[0, Vector2(70, 0)]], 300),
		_s("toad_stunned_right_after_spitting", "toad", Vector2(0, 0), [[0, Vector2(70, 0)]], 420,
			[["stun_when", "anim_state", "spit", 2, 1.5]]),
		_s("toad_stunned_mid_puff", "toad", Vector2(0, 0), [[0, Vector2(70, 0)]], 300, [["stun_when", "telegraphing", true, 5, 0.5]]),
		_s("toad_killed_mid_puff", "toad", Vector2(0, 0), [[0, Vector2(70, 0)]], 200, [["kill_when", "telegraphing", true, 5]]),
		# armored chargers
		_s("lizard_plain", "lizard", Vector2(0, 0), [[0, Vector2(90, 0)]], 300),
		_s("lizard_stunned_mid_windup", "lizard", Vector2(0, 0), [[0, Vector2(90, 0)]], 240, [["stun_when", "charge_state", "windup", 10, 0.5]]),
		_s("lizard_stunned_mid_charge", "lizard", Vector2(0, 0), [[0, Vector2(90, 0)]], 240, [["stun_when", "charge_state", "charge", 10, 0.5]]),
		_s("lizard_stunned_mid_rest", "lizard", Vector2(0, 0), [[0, Vector2(90, 0)]], 240, [["stun_when", "charge_state", "rest", 10, 0.5]]),
		_s("lizard_killed_in_windup", "lizard", Vector2(0, 0), [[0, Vector2(90, 0)]], 200, [["kill_when", "charge_state", "windup", 10]]),
		_s("lizard_slowed", "lizard", Vector2(0, 0), [[0, Vector2(90, 0)]], 300, [["slow", 20, 2.0]]),
		_s("crab_plain", "mushroom_crab", Vector2(0, 0), [[0, Vector2(90, 0)]], 300),
		# swooper
		_s("bat_plain", "bat", Vector2(0, -100), [[0, Vector2(30, 0)]], 500),
		_s("bat_stunned_in_warn", "bat", Vector2(0, -100), [[0, Vector2(30, 0)]], 400, [["stun_when", "swoop_state", "warn", 5, 0.5]]),
		_s("bat_stunned_in_dive", "bat", Vector2(0, -100), [[0, Vector2(30, 0)]], 400, [["stun_when", "swoop_state", "dive", 5, 0.5]]),
		_s("bat_killed_in_warn", "bat", Vector2(0, -100), [[0, Vector2(30, 0)]], 250, [["kill_when", "swoop_state", "warn", 5]]),
		_s("bat_alert_lost_then_found_again", "bat", Vector2(0, -100), [[0, Vector2(30, 0)], [300, Vector2(120, -20)]], 480, [["player_when", "swoop_state", "hover", 10, far]]),
		_s("bat_slowed", "bat", Vector2(0, -100), [[0, Vector2(30, 0)]], 500, [["slow", 100, 2.0]]),
		# dropper
		_s("spider_drop", "spider", Vector2(0, -100), [[0, Vector2(10, 0)]], 300),
		_s("spider_stunned_hanging", "spider", Vector2(0, -100), [[0, far], [100, Vector2(10, 0)]], 320, [["stun", 5, 1.0]]),
		# drifter
		_s("moth_plain", "spore_moth", Vector2(0, -100), [[0, Vector2(100, -100)]], 520),
		_s("moth_leaves_and_returns", "spore_moth", Vector2(0, -100), [[0, Vector2(100, -100)], [100, Vector2(3000, -100)], [130, Vector2(100, -100)]], 420),
		_s("moth_killed_in_flash", "spore_moth", Vector2(0, -100), [[0, Vector2(100, -100)]], 300, [["kill_when", "telegraphing", true, 5]]),
		_s("moth_stunned_in_flash", "spore_moth", Vector2(0, -100), [[0, Vector2(100, -100)]], 420, [["stun_when", "telegraphing", true, 5, 1.0]]),
		_s("moth_player_leaves_mid_flash", "spore_moth", Vector2(0, -100), [[0, Vector2(100, -100)]], 400, [["player_when", "telegraphing", true, 5, Vector2(3000, -100)]]),
		# snake
		_s("snake_plain", "vine_snake", Vector2(0, -100), [[0, Vector2(12, 0)]], 400),
		_s("snake_killed_in_lunge", "vine_snake", Vector2(0, -100), [[0, Vector2(12, 0)]], 250, [["kill_when", "charge_state", "charge", 3]]),
		_s("snake_stunned_in_coil", "vine_snake", Vector2(0, -100), [[0, Vector2(12, 0)]], 400, [["stun_when", "charge_state", "windup", 3, 0.5]]),
		_s("snake_stunned_in_lunge", "vine_snake", Vector2(0, -100), [[0, Vector2(12, 0)]], 400, [["stun_when", "charge_state", "charge", 3, 0.5]]),
		_s("snake_stunned_in_retreat", "vine_snake", Vector2(0, -100), [[0, Vector2(12, 0)]], 400, [["stun_when", "charge_state", "rest", 3, 0.5]]),
	]
