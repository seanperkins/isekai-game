extends SceneTree
## Frames of the Menagerie at a few stops along its length. Needs a real renderer. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/menagerie_shots.gd -- --room=menagerie
## Shots go to .tmp/menagerie-frames/stop_N.png. Every creature is held asleep and the player cannot be hurt, so a frame shows the
## creatures at rest and not a fight. The game is untyped: a -s script cannot see autoloads.

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
		_hush()
		game.player.global_position = Vector2(STOPS[stop], 300.0)
		game.player.velocity = Vector2.ZERO
	return false

## The keeper would wake whatever the player stands near; stop it, put every creature to sleep and make the player untouchable.
func _hush() -> void:
	var keeper = game.get_node_or_null("MenagerieKeeper")
	if keeper != null:
		keeper.set_physics_process(false)
	for n in game.get_tree().get_nodes_in_group("actors"):
		if n.get("dormant") != null:
			n.set("dormant", true)
	game.player.set("_invuln", 100000.0)
