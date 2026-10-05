extends SceneTree
## Real-renderer shots of the aim reticle and the mouse scheme. Run from the project root:
##   tools/shot_run.sh tools/aim_shots.gd
## The cursor is simulated by pushing a mouse-motion event to the stage; the real cursor is never moved.
## Writes .tmp/aim/*.png: the reticle on the right stick at two angles, on an enlarged form, following the real cursor, the HUD
## chips with the mouse live, and a skill-screen card with the mouse live.

const OUT := "res://.tmp/aim/"
var view: SubViewport  # the stage the game is drawn on (tools/shot_stage.gd)
var game
var frame := 0

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	view = ShotStage.mount(root, game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _axis(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _stick(x: float, y: float) -> void:
	_axis(JOY_AXIS_RIGHT_X, x)
	_axis(JOY_AXIS_RIGHT_Y, y)

func _process(_delta: float) -> bool:
	var p = game.player
	var rules = root.get_node("SkillRules")
	var controls = root.get_node("Controls")  # autoloads are not compile-time names in a -s script
	frame += 1
	match frame:
		20:
			for i in 8:
				rules.handle_event("absorbed", {"essence": "water", "source": "shots"})  # Hydraulic Propulsion, slot 1
			for i in 3:
				rules.handle_event("predated", {"source": "spider", "kind": "creature"})  # Sticky Thread
			p.global_position = game.world.current_rect().position + Vector2(300, 300)
			p.velocity = Vector2.ZERO
			for n in root.get_tree().get_nodes_in_group("actors"):
				if n != p and n is Node2D:
					n.global_position += Vector2(0, -3000)  # everyone else out of the shots
					if n.has_method("set_physics_process"):
						n.set_physics_process(false)
		30:
			_stick(0.866, -0.5)  # 30 degrees up and to the right
		36:
			_shot("stick_up_right")
			_stick(-0.7, 0.7)
		42:
			_shot("stick_down_left")
			_stick(0.0, 0.0)
			p.advance_form("weaver", true)  # size 1.12 and its own art
			p._evolve_time = 0.0
			_stick(1.0, 0.0)
		50:
			_shot("stick_weaver")
			_stick(0.0, 0.0)
			controls.mouse_aim = true  # a warp may send no motion event: say the mouse is the aimer
			controls.using_joypad = false
			var motion := InputEventMouseMotion.new()  # the cursor at (430, 110) of the game's 640x360, without touching the real one
			motion.position = Vector2(430, 110)
			view.push_input(motion, true)
		56:
			print("cursor world ", p.get_global_mouse_position(), " player ", p.global_position, " free_aim ", p.free_aim())
			_shot("cursor")
		60:
			_shot("hud_mouse_chips")
		62:
			game.skill_screen.open()
			var guard := 0
			while game.skill_screen.selected_id() != "hydraulic_propulsion" and guard < 20:
				game.skill_screen.move(1)
				guard += 1
		70:
			_shot("skill_card_mouse")
			quit()
	return false
