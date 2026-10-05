extends SceneTree
## Frames of the Menagerie at a few stops along its length. Needs a real renderer (Godot cannot render headless). Run:
##   tools/menagerie_shots.sh
## The wrapper runs this in a throwaway copy of the project whose window is a tiny, borderless one that cannot take focus, and the
## game is drawn into a 1280x720 SubViewport that this script saves, so nothing takes over the screen. Frames land in
## .tmp/menagerie-frames/stop_N.png (`--out=DIR` changes that). Every creature is held asleep and the player cannot be hurt, so a
## frame shows the creatures at rest and not a fight. The game is untyped: a -s script cannot see autoloads.

const VIEW_SIZE := Vector2i(1280, 720)
const GAME_SIZE := Vector2i(640, 360)  # the game's own resolution, drawn at twice the size
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
	print("shots: window mode=%d size=%s" % [DisplayServer.window_get_mode(), DisplayServer.window_get_size()])  # the wrapper checks this
	view = SubViewport.new()
	view.size = VIEW_SIZE
	view.size_2d_override = GAME_SIZE
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)

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
