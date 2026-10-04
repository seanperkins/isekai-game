extends GutTest
## The game's soul wiring: the --soul=N dev flag, session points set (never added) at start, and bought perks applied at life start.

var saved := {}

func before_each() -> void:
	saved = {"points": Compendium.soul.points, "perks": Compendium.soul.perks.duplicate(), "deaths": Compendium.soul.deaths,
		"session": Compendium.soul.session_points}

func after_each() -> void:
	Compendium.soul.points = saved["points"]
	Compendium.soul.perks = saved["perks"]
	Compendium.soul.deaths = saved["deaths"]
	Compendium.soul.session_points = saved["session"]
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_soul_points_arg() -> void:
	assert_eq(Game.soul_points_arg(["--soul=5"]), 5)
	assert_eq(Game.soul_points_arg(["--soul=-3"]), 0, "negative reads 0")
	assert_eq(Game.soul_points_arg(["--soul=x"]), 0, "not a number reads 0")
	assert_eq(Game.soul_points_arg(["--soul=99999"]), 9999, "clamped")
	assert_eq(Game.soul_points_arg([]), 0)
	assert_eq(Game.soul_points_arg(["--evolve", "--soul=7"]), 7)

func test_begin_life_applies_bought_perks_after_the_kit() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	Compendium.soul.perks = {}
	game.begin_life({"default": true, "kit": {}, "species": "slime"})
	var base: int = game.player.health.max_hp
	Compendium.soul.perks = {"stats": 1}
	game.begin_life({"default": true, "kit": {}, "species": "slime"})
	assert_eq(game.player.health.max_hp, base + 2, "the stats perk adds 2 max HP per purchase")

func test_game_ready_sets_session_points_rather_than_adding() -> void:
	Compendium.soul.session_points = 5
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	assert_eq(Compendium.soul.session_points, 0, "the flag is absent, and _ready sets rather than adds")
