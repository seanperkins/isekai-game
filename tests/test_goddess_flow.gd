extends GutTest
## Dying in the real scene: her line for what killed you, real key presses buying a level and a power in her menu, and the next
## life starting with them.

var saved := {}

func before_each() -> void:
	# loading the game resets session_points, and the flow writes the last choice and pending start: snapshot, then pin a known choice
	saved = {"choice": Compendium.progress.last_choice(), "pending": Compendium.progress.pending_start.duplicate(true),
		"session": Compendium.soul.session_points}
	Compendium.progress.set_last_choice("C1", "slime")
	Compendium.progress.pending_start = {}

func after_each() -> void:
	Compendium.progress.set_last_choice(saved["choice"]["pool"], saved["choice"]["species"])
	Compendium.progress.pending_start = saved["pending"]
	Compendium.soul.session_points = saved["session"]
	SkillRules.reset_run()
	Announcer.queue.clear()

## 20 soul points of her own, and a Compendium of its own where `leap` has been owned once (so it is on offer).
func _fixture_goddess() -> Goddess:
	var soul := SoulProgress.new()
	soul.points = 20
	var compendium := CompendiumModel.new(SkillRules.skill_defs, SkillRules.creature_defs)
	compendium.raise("leap", CompendiumModel.State.OWNED_ONCE)
	return Goddess.new(soul, load("res://data/soul/soul_rules.tres"), load("res://data/goddess/lines.tres"),
		SpeciesCatalog.load_all(), [], compendium, SkillRules.skill_defs)

func _push(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code  # Controls binds the physical key
	ev.pressed = true
	get_viewport().push_input(ev)

func test_dying_buys_a_head_start_and_the_next_life_has_it() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	var goddess := _fixture_goddess()
	game.run.goddess = goddess
	var restarts := [0]
	game.run.restart_requested.disconnect(game._restart)  # a real restart would reload the test runner's scene
	game.run.restart_requested.connect(func() -> void: restarts[0] += 1)
	game.player.receive_hit(9999, "physical", Vector2.INF, "bat")
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)
	assert_true(game.goddess_menu.is_open(), "20 soul points to spend: she opens her menu")
	var bat_lines: Array = (load("res://data/goddess/lines.tres") as GoddessLines).by_cause["bat"]
	assert_eq(game.goddess_menu.line_text(), bat_lines[posmod(1, bat_lines.size())], "her line for a bat, on the first death")
	_push(KEY_Q)  # to Head start
	_push(KEY_RIGHT)
	_push(KEY_RIGHT)  # two levels
	_push(KEY_DOWN)  # the power row
	_push(KEY_RIGHT)  # take leap
	_push(KEY_ENTER)
	assert_eq(restarts[0], 1)
	var pending: Dictionary = Compendium.progress.pending_start
	assert_eq(pending, {"pool": "C1", "species": "slime", "kit": {"skills": ["leap"], "level": 3}})
	assert_eq(goddess.soul.total_points(), 12, "20 minus 2, 3 and 3")
	var pools := RebirthChoice.pools(game.world.rooms)
	game.begin_life(Game.resolve_start(pools, pending, Compendium.progress.is_attuned))
	assert_eq(game.player.progression.level, 3)
	assert_true(SkillRules.owned().has("leap"))
