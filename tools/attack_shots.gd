extends SceneTree
## A creature attacking in a real room, frame by frame: it spawns beside the player, wakes, and every STRIDE-th frame of its windup, its blow and its recovery is
## saved, cropped to the fight. Needs a real renderer. Run from the project root:
##   tools/shot_run.sh tools/attack_shots.gd -- --id=twin_goblin_giant_killer --out=$PWD/.tmp/attack-shots/giant_killer [--dx=44] [--frames=150]
## Writes <out>/NNN.png. The player cannot be hurt, so the creature keeps attacking.

const STRIDE := 3
const CROP := Vector2i(360, 200)
const CANVAS_WIDTH := 640.0   # the game's own width: the stage is drawn at a multiple of it

var view: SubViewport  # the stage the game is drawn on (tools/shot_stage.gd)
var game
var frame := 0
var enemy
var out := ""
var id := "twin_goblin_giant_killer"
var dx := 44.0
var frames := 150
var shots := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			id = a.substr(5)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--dx="):
			dx = float(a.substr(5))
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	if out == "":
		out = ProjectSettings.globalize_path("res://.tmp/attack-shots/" + id)
	game = load("res://scenes/main.tscn").instantiate()
	view = ShotStage.mount(root, game)
	DirAccess.make_dir_recursive_absolute(out)

func _process(_delta: float) -> bool:
	frame += 1
	var p = game.player
	if frame == 20:
		p.set("_invuln", 1.0e9)  # a blow that lands does not hurt, so the next one comes
		enemy = game._spawn(id, Vector2(p.global_position.x + dx, p.global_position.y))
		game.world.room.add_child(enemy)
		enemy.global_position = Vector2(p.global_position.x + dx, p.global_position.y)
	elif frame > 20 and enemy != null and is_instance_valid(enemy):
		p.set("_invuln", 1.0e9)
		if (frame - 20) % STRIDE == 0:
			var img: Image = view.get_texture().get_image()
			var mid: Vector2 = (p.get_global_transform_with_canvas().origin + enemy.get_global_transform_with_canvas().origin) / 2.0
			var centre := Vector2i(mid * (float(img.get_width()) / CANVAS_WIDTH)) - Vector2i(0, 30)
			var rect := Rect2i(clampi(centre.x - CROP.x / 2, 0, maxi(0, img.get_width() - CROP.x)), clampi(centre.y - CROP.y / 2, 0, maxi(0, img.get_height() - CROP.y)), CROP.x, CROP.y)
			img.get_region(rect).save_png("%s/%03d.png" % [out, shots])
			shots += 1
		if frame >= 20 + frames:
			print("SHOTS ", shots, " state ", enemy.get("_verb_state"), " casts ", enemy.get("verb_casts"))
			quit()
	return false
