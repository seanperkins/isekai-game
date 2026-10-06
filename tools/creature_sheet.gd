extends SceneTree
## One contact sheet of every creature, each drawn as the game draws it (its still or the frames it wears, in its tint, at rest) with its name
## under it. Needs a real renderer (Godot cannot render headless). Run:
##   tools/creature_sheet.sh
## which runs this through tools/shot_run.sh (a tiny off-screen window, muted), so nothing takes over the screen. The sheet lands in
## .tmp/creature-sheet/sheet.png (`--out=DIR` changes that). Creatures keep their relative size up to 2x and shrink only to fit their cell.
## Order: the shipped creatures, then the support monsters, then the twins by stage. The game is untyped here: a -s script cannot see
## autoloads, so Enemy and DefLoader are loaded after the first frame.

const COLUMNS := 14
const CELL := Vector2(140, 140)
const LABEL_H := 30.0
const HEAD_H := 44.0
const MAX_SCALE := 2.0
const SETTLE := 6
const BACKGROUND := Color(0.09, 0.09, 0.12)
const CELL_FILL := Color(0.14, 0.14, 0.18)
const ORIGIN_TINT := {"": Color(0.95, 0.95, 0.95), "support": Color(0.65, 0.9, 0.65), "twin": Color(0.95, 0.8, 0.5)}
const STAGE_TINT := {2: Color(0.95, 0.85, 0.55), 3: Color(0.95, 0.7, 0.45), 4: Color(0.95, 0.55, 0.5)}

var out := ProjectSettings.globalize_path("res://.tmp/creature-sheet")
var view: SubViewport
var frame := 0
var cells: Array = []  # [{"node": Node2D, "enemy": Node, "def": CreatureDef}]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			out = str(arg).trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		_build()
	elif frame == 3 + SETTLE:
		_fit()
	elif frame == 3 + SETTLE * 2:
		ShotStage.save(view, "%s/sheet.png" % out)
		print("creature sheet: %d creatures in %s/sheet.png" % [cells.size(), out])
		quit()
		return true
	return false

func _build() -> void:
	var loader = load("res://scripts/skills/def_loader.gd")
	var enemy_script = load("res://scripts/enemies/enemy.gd")
	var skills := {}
	for d in loader.load_dir("res://data/skills"):
		skills[d.id] = d
	var defs: Array = []
	for d in loader.load_dir("res://data/creatures"):
		if d.id != "water_pool":  # terrain, not a creature
			defs.append(d)
	defs.sort_custom(_before)
	var rows := ceili(float(defs.size()) / COLUMNS)
	view = ShotStage.open(root, Vector2i(int(COLUMNS * CELL.x), int(HEAD_H + rows * CELL.y)), Vector2i.ZERO)
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.size = Vector2(view.size)
	view.add_child(back)
	_heading(defs.size())
	for i in defs.size():
		var def: CreatureDef = defs[i]
		var origin := Vector2((i % COLUMNS) * CELL.x, HEAD_H + (i / COLUMNS) * CELL.y)
		var fill := ColorRect.new()
		fill.color = CELL_FILL
		fill.position = origin + Vector2(2, 2)
		fill.size = CELL - Vector2(4, 4)
		view.add_child(fill)
		var node := Node2D.new()
		node.position = origin + Vector2(CELL.x / 2.0, CELL.y - LABEL_H - 6.0)
		view.add_child(node)
		var enemy = enemy_script.new()
		enemy.setup(def, skills)
		enemy.dormant = true
		enemy.position = Vector2(0, -enemy_script.BODY_BOTTOM)  # its feet on the cell's ground
		node.add_child(enemy)
		enemy.set_physics_process(false)
		_name_label(def, origin)
		cells.append({"node": node, "enemy": enemy, "def": def})

## Shipped first, then support monsters, then twins by stage; by name within each.
func _before(a: CreatureDef, b: CreatureDef) -> bool:
	var ka := _rank(a)
	var kb := _rank(b)
	if ka != kb:
		return ka < kb
	return a.display_name.naturalnocasecmp_to(b.display_name) < 0

func _rank(d: CreatureDef) -> int:
	match d.origin:
		"":
			return 0
		"support":
			return 1
	return 10 + d.stage

func _tint(d: CreatureDef) -> Color:
	if d.origin == "twin":
		return STAGE_TINT.get(d.stage, ORIGIN_TINT["twin"])
	return ORIGIN_TINT.get(d.origin, Color.WHITE)

func _heading(count: int) -> void:
	var label := Label.new()
	label.text = "Every creature in the game (%d): shipped, support monster, twin of a form by stage (2, 3, 4). Resting, at most 2x, shrunk only to fit." % count
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(12, 12)
	view.add_child(label)

func _name_label(d: CreatureDef, origin: Vector2) -> void:
	var label := Label.new()
	label.text = d.display_name if d.display_name != "" else d.id
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", _tint(d))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.position = origin + Vector2(4, CELL.y - LABEL_H - 2.0)
	label.size = Vector2(CELL.x - 8, LABEL_H)
	view.add_child(label)

## Once a creature has drawn itself, scale its cell to the drawn size: up to 2x, down only as far as the cell needs.
func _fit() -> void:
	var room := Vector2(CELL.x - 12.0, CELL.y - LABEL_H - 14.0)
	for c in cells:
		var sprite := c["enemy"].get_node_or_null("Sprite") as Sprite2D
		var scale := MAX_SCALE
		if sprite != null and sprite.texture != null:
			var drawn: Vector2 = sprite.get_rect().size * sprite.scale.abs()
			if drawn.x > 0.0 and drawn.y > 0.0:
				scale = minf(MAX_SCALE, minf(room.x / drawn.x, room.y / drawn.y))
		else:
			push_warning("no sprite for %s" % c["def"].id)
		c["node"].scale = Vector2(scale, scale)
