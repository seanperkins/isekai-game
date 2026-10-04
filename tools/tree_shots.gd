extends SceneTree
## Real-renderer shots of the Tree tab at both zooms with nothing, some and everything discovered. Run from the project
## root with the windowed renderer (--headless has no texture to read):
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/tree_shots.gd
## Writes .tmp/tree/*.png. It saves nothing: the Compendium's store is detached before anything is raised.

const OUT := "res://.tmp/tree/"
var game
var frame := 0

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _compendium() -> CompendiumModel:
	return root.get_node("Compendium").model

## Every slot back to Unknown, in memory only, then the starting power Owned-once, as a new soul has it.
func _forget_everything() -> void:
	var c := _compendium()
	c.store = null
	for id in c.states():
		c._states[id] = CompendiumModel.State.UNKNOWN
	c.raise("appraisal", CompendiumModel.State.OWNED_ONCE)

func _discover_some() -> void:
	var c := _compendium()
	root.get_node("SkillRules").grant("hydraulic_propulsion")
	c.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	c.raise("poison_breath", CompendiumModel.State.NAMED)
	c.raise("leap", CompendiumModel.State.HINTED)

func _discover_everything() -> void:
	var c := _compendium()
	for id in c.states():
		c.raise(id, CompendiumModel.State.OWNED_ONCE)

func _process(_delta: float) -> bool:
	var screen = game.skill_screen  # untyped: a -s script compiles before the autoloads exist, and SkillScreen names Controls
	frame += 1
	match frame:
		30:
			_forget_everything()
			screen.open()
			screen.switch_tab(1)
		36:
			_shot("nothing_normal")
			screen.set_tree_overview(true)
		42:
			_shot("nothing_overview")
			_discover_some()
			screen.switch_tab(1)
		48:
			_shot("some_normal")
			screen.set_tree_overview(true)
		54:
			_shot("some_overview")
			_discover_everything()
			screen.switch_tab(1)
		60:
			_shot("everything_normal")
			screen.select_tree_node("spore_cloud")
		66:
			_shot("everything_spore_cloud")
			screen.set_tree_overview(true)
		72:
			_shot("everything_overview")
		78:
			quit()
	return false
