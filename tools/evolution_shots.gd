extends SceneTree
## Real-renderer shots of the evolution flow. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/evolution_shots.gd
## Writes .tmp/evolution/*.png: the HUD prompt, the Form tab, and each Weaver-lineage stage plus a tinted form.

const OUT := "res://.tmp/evolution/"
var game
var frame := 0
var steps: Array = []

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _cap() -> void:
	var p = game.player
	p.debug_grant_xp(Progression.stage_total(p.progression.stage))

func _process(_delta: float) -> bool:
	var p = game.player
	if frame >= 75 and p.evolving() and frame not in [75]:
		return false  # wait for the evolution moment to settle before the next step
	frame += 1
	match frame:
		30:
			# eat a bit of everything so the offers include every lineage
			for e in ["water", "dark", "air", "earth"]:
				for i in 14:
					root.get_node("SkillRules").handle_event("absorbed", {"essence": e, "source": "shots"})
			for i in 3:
				root.get_node("SkillRules").handle_event("predated", {"source": "spider", "kind": "creature"})
			_cap()
		50:
			_shot("hud_prompt")
			game.skill_screen.open()
			game.skill_screen.switch_tab(5)
		60:
			_shot("form_tab")
			game.skill_screen.accept()  # evolves into the first offer
			game.skill_screen.close()
			game.player.set_physics_process(true)
		75:
			_shot("moment")
		140:
			_shot("stage2")
			_cap()
			p.advance_form("snare")
		220:
			_shot("stage3_snare")
			_cap()
			p.advance_form("silkbound")
		300:
			_shot("stage4_silkbound")
		310:
			quit()
	return false
