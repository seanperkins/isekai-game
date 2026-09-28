class_name Tablet
extends Node2D
## A carved stone. Reading it (Inspect) shows a line of lore and hints at a skill in the
## Compendium. Tablets you've read are remembered across runs.

var id := ""
var title := ""
var text := ""
var hint := ""
var _progress
var _compendium

func setup(f: Dictionary, ctx: Dictionary) -> void:
	id = f.get("id", "")
	title = f.get("title", "Tablet")
	text = f.get("text", "")
	hint = f.get("hint", "")
	position = f["pos"]
	_progress = ctx.get("progress")
	_compendium = ctx.get("compendium")
	add_to_group("interactable")

func _ready() -> void:
	if get_child_count() == 0:
		var stone := ColorRect.new()
		stone.color = Color(0.35, 0.38, 0.45)
		stone.size = Vector2(12, 18)
		stone.position = Vector2(-6, -18)
		add_child(stone)
		var unread: bool = _progress == null or not _progress.is_read(id)
		add_child(Art.light(Color(0.4, 1.0, 0.9) if unread else Color(0.3, 0.35, 0.5), 0.8, 0.8))

func prompt() -> String:
	return "read"

func interact(player: Node) -> void:
	player.inspect_report.emit(PackedStringArray([title, text]))
	if hint != "" and _compendium != null:
		_compendium.raise(hint, CompendiumModel.State.HINTED)
	if _progress != null:
		_progress.read_tablet(id)
