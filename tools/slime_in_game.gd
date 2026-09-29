extends SceneTree
## Full frames of the slime in the real Cave: idle, running, jumping, spreading, and covering a stunned
## toad. Needs a real renderer. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/slime_in_game.gd

const OUT := "res://.tmp/slime-frames/"
var game
var frame := 0
var enemy  # untyped: a -s script cannot see autoloads, and the Player and Enemy scripts use them

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%sgame_%s.png" % [OUT, n]))

func _process(_delta: float) -> bool:
	frame += 1
	var p = game.player
	match frame:
		30:
			_shot("idle")
			Input.action_press("move_right")
		50:
			_shot("run")
			Input.action_release("move_right")
			Input.action_press("jump")
		56:
			Input.action_release("jump")
		62:
			_shot("jump")
		140:
			Input.action_press("aim_down")
		165:
			_shot("spread")
			Input.action_release("aim_down")
			enemy = game._spawn("toad", Vector2(p.global_position.x + 24.0, p.global_position.y))
			game.world.room.add_child(enemy)
			enemy.global_position = Vector2(p.global_position.x + 24.0, p.global_position.y)
			enemy.status.stun()
		200:
			Input.action_press("predate")
		230:
			_shot("cover")
			Input.action_release("predate")
		250:
			quit()
	return false
