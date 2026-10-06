extends SceneTree
## What an animated twin looks like in the game: one strip per state (idle, walk, run, windup, recover, hurt, downed) drawn by the real Enemy at
## the speed the game plays it, then the same form in a dark room with a lamp beside it, to see the normal map work. Needs a real renderer
## (Godot cannot render headless). Run:
##   tools/shot_run.sh tools/form_anim_shots.gd -- --form=goblin_redcap [--out=DIR] [--step=0.08]
## Shots go to DIR/strip.png and DIR/lit.png (default .tmp/form-anim/<form>). Untyped, like the other shot tools: a -s script cannot see autoloads.

const COLUMNS := 10
const ZOOM := 2
const ROW_PAD := 14.0
const STATES := ["idle", "walk", "run", "windup", "recover", "hurt", "downed"]

var form := ""
var out := ""
var step := 0.08
var frame := 0
var views: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--form="):
			form = a.trim_prefix("--form=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
	if out == "":
		out = ProjectSettings.globalize_path("res://.tmp/form-anim/%s" % form)
	DirAccess.make_dir_recursive_absolute(out)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		_build()
	elif frame == 12:
		ShotStage.save(views[0], "%s/strip.png" % out)
		ShotStage.save(views[1], "%s/lit.png" % out)
		print("form shots: %s in %s" % [form, out])
		quit()
		return true
	return false

func _def(loader):
	for d in loader.load_dir("res://data/creatures"):
		if d.form == form and d.origin == "twin":
			return d
	return null

func _enemy(def, skills, enemy_script):
	var e = enemy_script.new()
	e.setup(def, skills)
	e.facing = 1
	return e

func _apply(e, state: String) -> void:
	match state:
		"walk":
			e.velocity.x = 20.0
		"run":
			e.velocity.x = 400.0
		"windup":
			e._verb_state = "windup"
		"recover":
			e._verb_state = "recover"
		"hurt":
			e._hurt_t = 10.0
		"downed":
			e.status.down()

func _build() -> void:
	var loader = load("res://scripts/skills/def_loader.gd")
	var enemy_script = load("res://scripts/enemies/enemy.gd")
	var skills := {}
	for d in loader.load_dir("res://data/skills"):
		skills[d.id] = d
	var def = _def(loader)
	if def == null:
		push_error("no twin wears form %s" % form)
		quit(1)
		return
	var probe = _enemy(def, skills, enemy_script)
	root.add_child(probe)
	probe._update_visual(0.0)
	var sprite := probe.get_node("Sprite") as Sprite2D
	var cell := Vector2(sprite.get_rect().size.x * sprite.scale.x + 8.0, sprite.get_rect().size.y * sprite.scale.y + ROW_PAD)
	probe.queue_free()
	var size := Vector2i(int(cell.x * COLUMNS), int(cell.y * STATES.size()) + 8)
	var strip: SubViewport = ShotStage.open(root, size * ZOOM, size)
	_background(strip, size)
	for r in STATES.size():
		for c in COLUMNS:
			var holder := Node2D.new()
			holder.position = Vector2(cell.x * (c + 0.5), cell.y * (r + 1) - 4.0)
			strip.add_child(holder)
			var e = _enemy(def, skills, enemy_script)
			e.position = Vector2(0, -enemy_script.BODY_BOTTOM)
			holder.add_child(e)
			e.set_physics_process(false)  # after it is in the tree: _ready turns it on
			_apply(e, STATES[r])
			e._update_visual(0.0)
			e._update_visual(step * c)
		var label := Label.new()
		label.text = STATES[r]
		label.add_theme_font_size_override("font_size", 8)
		label.position = Vector2(2, cell.y * (r + 1) - cell.y + 2.0)
		strip.add_child(label)
	views.append(strip)
	var lit_size := Vector2i(int(cell.x * 4), int(cell.y) + 40)
	var lit: SubViewport = ShotStage.open(root, lit_size * ZOOM, lit_size)
	_background(lit, lit_size)
	var dark := CanvasModulate.new()
	dark.color = Color(0.30, 0.30, 0.40)
	lit.add_child(dark)
	for i in 4:
		var holder := Node2D.new()
		holder.position = Vector2(cell.x * (i + 0.5), cell.y + 30.0)
		lit.add_child(holder)
		var e = _enemy(def, skills, enemy_script)
		e.position = Vector2(0, -enemy_script.BODY_BOTTOM)
		e.facing = 1 if i % 2 == 0 else -1
		holder.add_child(e)
		e.set_physics_process(false)
		e._update_visual(0.0)
		var lamp = load("res://scripts/ui/art.gd").light(Color(1.0, 0.82, 0.55), 1.3, 1.6)
		lamp.position = Vector2([-34.0, 34.0, 0.0, -20.0][i], [-40.0, -40.0, -64.0, -20.0][i])
		holder.add_child(lamp)
	views.append(lit)

func _background(view: SubViewport, size: Vector2i) -> void:
	var back := ColorRect.new()
	back.color = Color(0.14, 0.14, 0.18)
	back.size = Vector2(size)
	view.add_child(back)
