extends SceneTree
## Real-renderer shots of the channel and effect looks. Run from the project root (windowed, unsandboxed):
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/vfx_shots.gd
## Writes .tmp/vfx/*.png: the web tether on an enemy, the rope on rock, the water stream, Water Blade and Binding Web.

const OUT := "res://.tmp/vfx/"
var game
var frame := 0
var dummy

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _ability(id: String, values: Array) -> Ability:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % id).instantiate()
	game.player.add_child(a)
	a.setup(game.player, values, 1)
	return a

func _process(_delta: float) -> bool:
	var p = game.player
	var rules = root.get_node("SkillRules")
	frame += 1
	match frame:
		20:
			for i in 3:
				rules.handle_event("absorbed", {"essence": "thread", "source": "shots"})  # Sticky Thread, slot 0
			for i in 4:
				rules.handle_event("absorbed", {"essence": "water", "source": "shots"})  # Hydraulic Propulsion, slot 1
			var rect: Rect2 = game.world.current_rect()
			p.global_position = rect.position + Vector2(300, 300)
			p.velocity = Vector2.ZERO
			for n in root.get_tree().get_nodes_in_group("actors"):
				if n.has_method("receive_thread") and n != p:
					if dummy == null:
						dummy = n  # an enemy the room already spawned, moved in front of the slime and held still
					else:
						n.global_position += Vector2(0, -3000)  # everyone else out of the shot
					n.set_physics_process(false)
			dummy.global_position = p.global_position + Vector2(80, 0)
			dummy.set_physics_process(false)
		40:
			Input.action_press("active_1")  # hold the web on the toad
		70:
			_shot("web_tether")
			Input.action_release("active_1")
		75:
			p.global_position = game.world.current_rect().position + Vector2(300, 300)
			p.velocity = Vector2.ZERO
			p.attach_rope(p.global_position + Vector2(70, -90), 120.0, 60.0, 1.0)
		95:
			_shot("rope_on_rock")
			p.drop_rope()
			p.global_position = game.world.current_rect().position + Vector2(300, 300)
			p.velocity = Vector2.ZERO
		120:
			Input.action_press("active_2")  # hold the water stream to the right
		135:
			_shot("water_stream")
			Input.action_release("active_2")
		170:
			p.global_position = game.world.current_rect().position + Vector2(300, 300)
			p.velocity = Vector2.ZERO
			dummy.global_position = p.global_position + Vector2(90, 0)
			p.facing = 1
			var blade := _ability("water_blade", [3])
			blade.aim = Vector2(1, 0)
			blade.activate()
		174:
			_shot("water_blade")
		200:
			var web := _ability("binding_web", [2])
			web.aim = Vector2(1, 0)
			web.activate()
		215:
			_shot("binding_web_patch")
			quit()
	return false
