extends SceneTree
## Real-renderer shots of one room from chosen camera spots. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/room_shots.gd -- C1 300,180 1000,180
## Writes .tmp/room-shots/<room>_<n>.png. Positions are local room px (where the slime stands).

const OUT := "res://.tmp/room-shots/"
var game
var frame := 0
var room_id := "C1"
var spots: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	room_id = args[0] if args.size() > 0 else "C1"
	for a in args.slice(1):
		var p := a.split(",")
		spots.append(Vector2(float(p[0]), float(p[1])))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _place(local: Vector2) -> void:
	var p = game.player
	var rect: Rect2 = game.world.current_rect()
	p.global_position = rect.position + local
	p.velocity = Vector2.ZERO
	game.world.camera.global_position = game.world.view_center(rect, p.global_position)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game.world.enter(room_id)
		game.world.set_physics_process(false)
		game.player.set_physics_process(false)
	elif frame >= 40 and (frame - 40) % 20 == 0:
		var i := (frame - 40) / 20
		if i > 0:
			root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s_%d.png" % [OUT, room_id, i - 1]))
		if i >= spots.size():
			quit()
		else:
			_place(spots[i])
	return false
