extends SceneTree
## Real-renderer shots of a tall room from its top, middle and bottom, to check the layers' vertical
## parallax. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/tall_room_shots.gd
## Writes .tmp/tall-room/{top,middle,bottom}.png.

const OUT := "res://.tmp/tall-room/"
var game
var frame := 0

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _report(n: String) -> void:
	var rm = game.world.room
	var cam = game.world.camera
	var fr = rm.get_node_or_null("far_rock")
	var sp = fr.get_child(0) if fr != null else null
	print("SHOT ", n, " room=", game.world.current_id, " room_pos=", rm.global_position, " cam=", cam.global_position, " player=", game.player.global_position,
		" far_rock tex_h=", fr.texture.get_height() if fr != null else -1, " sprite_y=", sp.global_position.y if sp != null else -1)

func _shot(n: String) -> void:
	_report(n)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _place(local_y: float) -> void:
	var p = game.player
	var rect: Rect2 = game.world.current_rect()
	p.global_position = Vector2(rect.position.x + 300.0, rect.position.y + local_y)
	p.velocity = Vector2.ZERO
	game.world.camera.global_position = game.world.view_center(rect, p.global_position)

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		30:
			game.world.enter("C5")
			game.world.set_physics_process(false)  # this script places the camera itself
			game.player.set_physics_process(false)
		40:
			_place(60.0)
		60:
			_shot("top")
			_place(540.0)
		80:
			_shot("middle")
			_place(1000.0)
		100:
			_shot("bottom")
			quit()
	return false
