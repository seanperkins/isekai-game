extends GutTest
## A Run is one life: it follows the room you're in, shows the death card, then asks the game
## to restart exactly once.

class Mortal extends Node:
	signal died

func test_death_shows_the_card_then_asks_for_one_restart() -> void:
	var run := Run.new()
	add_child_autofree(run)
	var body: Mortal = autofree(Mortal.new())
	var world := World.new()
	add_child_autofree(world)
	run.bind(body, world)
	var restarts := [0]
	run.restart_requested.connect(func() -> void: restarts[0] += 1)
	body.died.emit()
	body.died.emit()
	assert_true(run.death_card_visible())
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)
	assert_eq(restarts[0], 1)

func test_the_run_follows_the_room() -> void:
	var run := Run.new()
	add_child_autofree(run)
	var world := World.new()
	add_child_autofree(world)
	run.bind(autofree(Mortal.new()), world)
	world.room_entered.emit("C2")
	assert_eq(run.room_id, "C2")

func test_the_menu_is_ignored_while_dead_and_a_restart_unpauses() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	game.player.health.take_hit(999, "physical")
	var esc := InputEventAction.new()
	esc.action = "menu"
	esc.pressed = true
	game.skill_screen._unhandled_input(esc)
	assert_false(game.skill_screen.is_open())
	get_tree().paused = true  # however it happened, a restart must not carry it over
	game._prepare_restart()
	assert_false(get_tree().paused)
	SkillRules.reset_run()
	Announcer.queue.clear()
