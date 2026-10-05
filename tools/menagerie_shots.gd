extends SceneTree
## Frames of the Menagerie at a few stops along its length. Needs a real renderer. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/menagerie_shots.gd -- --room=menagerie
## Shots go to .tmp/menagerie-frames/stop_N.png. The game is untyped: a -s script cannot see autoloads.

const OUT := "res://.tmp/menagerie-frames/"
const STOPS := [60.0, 420.0, 1000.0, 1700.0, 4400.0, 7000.0, 9200.0, 10300.0]
const SETTLE := 25
var game
var frame := 0
var stop := 0

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5 or (frame > 5 and (frame - 5) % SETTLE == 0):
		if frame > 5:
			root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%sstop_%d.png" % [OUT, stop]))
			stop += 1
			if stop >= STOPS.size():
				quit()
				return true
		game.player.global_position = Vector2(STOPS[stop], 300.0)
		game.player.velocity = Vector2.ZERO
	return false
