class_name Run
extends Node
## One life. It owns what resets on death (which room you're in) and the death card, and it
## asks the game to restart. The World handles space; the game reloads the scene on restart.

signal restart_requested

const DEATH_CARD_SECONDS := 1.5

var room_id := ""
var _card := CanvasLayer.new()
var _ending := false

func _ready() -> void:
	_card.layer = 30
	_card.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.75)
	shade.size = Vector2(640, 360)
	_card.add_child(shade)
	var label := Label.new()
	label.text = "You dissolve.\nA new life begins."
	label.size = Vector2(640, 360)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_card.add_child(label)
	add_child(_card)

func bind(player: Node, world: Node) -> void:
	player.died.connect(_on_player_died)
	world.room_entered.connect(func(id: String) -> void: room_id = id)
	room_id = world.current_id

func death_card_visible() -> bool:
	return _card.visible

func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	_card.visible = true
	await get_tree().create_timer(DEATH_CARD_SECONDS).timeout
	restart_requested.emit()
