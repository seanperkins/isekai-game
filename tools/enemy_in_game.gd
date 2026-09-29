extends SceneTree
## Real-Cave frames of the creatures and of each death cause. Needs a real renderer. Run from the
## project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/enemy_in_game.gd
## Shots go to .tmp/enemy-frames/game_*.png. Enemies are untyped: a -s script cannot see autoloads.

const OUT := "res://.tmp/enemy-frames/"
var game
var frame := 0
var row := []      # the creatures shown at rest
var victims := {}  # cause -> enemy

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%sgame_%s.png" % [OUT, n]))

func _spawn(id: String, dx: float, still: bool = true):
	var p = game.player
	var e = game._spawn(id, Vector2(p.global_position.x + dx, p.global_position.y))
	game.world.room.add_child(e)
	e.global_position = Vector2(p.global_position.x + dx, p.global_position.y)
	if still:
		e.set_physics_process(false)
	return e

func _process(_delta: float) -> bool:
	frame += 1
	var p = game.player
	match frame:
		20:
			for spec in [["bat", 70.0], ["toad", 120.0], ["lizard", 175.0], ["spider", 240.0]]:
				row.append(_spawn(spec[0], spec[1]))
		45:
			_shot("row")
			for e in row:
				e.queue_free()
			row.clear()
			victims["tackle"] = _spawn("toad", 30.0, false)
			victims["poison"] = _spawn("toad", 90.0, false)
			victims["blade"] = _spawn("toad", 150.0, false)
			victims["other"] = _spawn("toad", 210.0, false)
			for v in victims.values():
				v.status.stun()  # they stand still until the blow lands
		70:
			victims["tackle"].receive_tackle(9999, false, p.global_position)
			victims["poison"].receive_hit(9999, "poison", p.global_position, "poison")
			victims["blade"].receive_hit(9999, "physical", p.global_position, "blade")
			victims["other"].receive_hit(9999, "physical", p.global_position, "other")
		80:
			_shot("death_a")
		92:
			_shot("death_b")
		110:
			_shot("death_c")
		190:
			_shot("death_end")
			for v in victims.values():
				print("STATE ", v.status.state, " dist ", snappedf(v.global_position.distance_to(p.global_position), 0.1))
			quit()
	return false
