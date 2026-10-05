extends SceneTree
## Frames of the Menagerie at a few stops along its length. Needs a real renderer (Godot cannot render headless). Run:
##   tools/menagerie_shots.sh
## which runs this through tools/shot_run.sh (a tiny off-screen window, the game drawn into a 1280x720 stage), so nothing takes over
## the screen. Frames land in .tmp/menagerie-frames/stop_N.png (`--out=DIR` changes that). Every creature is held asleep and the player cannot be hurt, so a
## frame shows the creatures at rest and not a fight. The game is untyped: a -s script cannot see autoloads.

const DEFAULT_STOPS := [60.0, 420.0, 1000.0, 1700.0, 4400.0, 7000.0, 9200.0, 10300.0]
const SETTLE := 25
var stops: Array = DEFAULT_STOPS.duplicate()  # where the player stands for each frame; `--stops=1000,4400` changes them
var out := ProjectSettings.globalize_path("res://.tmp/menagerie-frames")
var view: SubViewport
var game
var frame := 0
var stop := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			out = str(arg).trim_prefix("--out=")
		elif str(arg).begins_with("--stops="):
			stops = []
			for x in str(arg).trim_prefix("--stops=").split(",", false):
				stops.append(float(x))
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/main.tscn").instantiate()
	view = ShotStage.mount(root, game)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5 or (frame > 5 and (frame - 5) % SETTLE == 0):
		if frame > 5:
			view.get_texture().get_image().save_png("%s/stop_%d.png" % [out, stop])
			stop += 1
			if stop >= stops.size():
				quit()
				return true
		_hush()
		game.player.global_position = Vector2(stops[stop], 300.0)
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
