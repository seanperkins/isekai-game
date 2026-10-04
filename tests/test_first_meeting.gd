extends GutTest
## Run.open_first_meeting: the goddess's first meeting after the opening. It opens her menu with her first words even though there
## is nothing to choose, counts no death, and accepting it begins the Cave altar life and marks the opening seen.

class Mortal extends Node:
	signal died

var restarts := [0]

func before_each() -> void:
	restarts[0] = 0

func _goddess(with_species := true) -> Goddess:
	var soul := SoulProgress.new()
	var compendium := CompendiumModel.new(SkillRules.skill_defs, SkillRules.creature_defs)
	var catalog := SpeciesCatalog.load_all() if with_species else {}
	return Goddess.new(soul, load("res://data/soul/soul_rules.tres"), load("res://data/goddess/lines.tres"), catalog, [], compendium,
		SkillRules.skill_defs)

func _run(goddess: Goddess, progress = WorldProgress.new()) -> Run:
	var run := Run.new()
	add_child_autofree(run)
	var world := World.new()
	add_child_autofree(world)
	run.bind(autofree(Mortal.new()), world, progress, [{"id": "C1", "name": "Cave mouth"}], goddess)
	run.restart_requested.connect(func() -> void: restarts[0] += 1)
	return run

func test_it_opens_her_menu_with_the_line_and_counts_no_death() -> void:
	var goddess := _goddess()
	var run := _run(goddess)
	var seen := []
	run.goddess_needed.connect(func(model: GoddessModel, line: String) -> void: seen.append([model, line]))
	assert_true(run.open_first_meeting("first words"))
	assert_eq(seen.size(), 1)
	assert_true(seen[0][0] is GoddessModel)
	assert_eq(seen[0][1], "first words")
	assert_eq(goddess.soul.deaths, 0, "the truck is not a death")
	assert_false(goddess.soul.opening_seen, "not until she is accepted")
	assert_eq(restarts[0], 0)

func test_accepting_it_begins_the_cave_altar_life_and_marks_the_opening_seen() -> void:
	var goddess := _goddess()
	var progress := WorldProgress.new()
	var run := _run(goddess, progress)
	var models := []
	run.goddess_needed.connect(func(model: GoddessModel, _line: String) -> void: models.append(model))
	run.open_first_meeting("first words")
	var result: Dictionary = models[0].confirm()
	assert_false(result.is_empty(), "her menu can be confirmed with nothing to buy")
	run.accept(result)
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start, {"altar": "C1", "species": "slime", "kit": {}})
	assert_true(goddess.soul.opening_seen)
	run.accept(result)
	assert_eq(restarts[0], 1, "a second answer is ignored")

func test_it_refuses_in_every_guarded_case() -> void:
	assert_false(_run(null).open_first_meeting("x"), "no goddess")
	assert_false(_run(_goddess(), null).open_first_meeting("x"), "no progress (an editor Play)")
	var pending := _run(_goddess())
	pending.goddess_needed.connect(func(_model: GoddessModel, _line: String) -> void: pass)  # a menu listens, so the choice stays pending
	assert_true(pending.open_first_meeting("x"))
	assert_false(pending.open_first_meeting("x"), "a choice is already pending")
	var stuck := _goddess(false)
	assert_false(_run(stuck).open_first_meeting("x"), "no species could load, so her menu could never be confirmed")
	assert_false(stuck.soul.opening_seen)
	assert_eq(restarts[0], 0, "a refusal begins nothing")

func test_it_refuses_mid_death() -> void:
	var goddess := _goddess()
	var run := _run(goddess)
	var body: Mortal = run._player
	body.died.emit()
	assert_false(run.open_first_meeting("x"), "a death is already under way")
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)  # let the death card finish rather than free the run mid-await
	assert_eq(restarts[0], 1)

func test_with_no_listener_it_begins_directly() -> void:
	var goddess := _goddess()
	var progress := WorldProgress.new()
	var run := _run(goddess, progress)
	assert_true(run.open_first_meeting("x"))
	assert_eq(restarts[0], 1, "nobody to ask: the game never hangs")
	assert_eq(progress.pending_start["altar"], "C1")
	assert_true(goddess.soul.opening_seen)
