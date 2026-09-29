class_name Run
extends Node
## One life. It owns what resets on death (which room you're in) and the death card, and it
## asks the game to restart. The World handles space; the game reloads the scene on restart.

signal restart_requested
## More than one pool is unlocked: the menu (Plan 7) shows `decision` (RebirthChoice.decide) and calls choose().
signal choice_needed(decision: Dictionary)

const DEATH_CARD_SECONDS := 1.5

var room_id := ""
var _card := CanvasLayer.new()
var _ending := false
var _progress  # WorldProgress, or null
var _pools: Array = []
var _decision := {}

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

func bind(player: Node, world: Node, progress = null, pools: Array = []) -> void:
	_progress = progress
	_pools = pools
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
	_resolve()

## What happens after the death card: restart (with no rebirth data the old way), or start at the only
## unlocked pool, or ask which one.
func _resolve() -> void:
	if _progress == null:
		restart_requested.emit()
		return
	var attuned: Array = [WorldProgress.DEFAULT_POOL]
	for id in _progress.rebirths:
		if not attuned.has(id):
			attuned.append(id)
	var decision := RebirthChoice.decide(_pools, attuned, str(_progress.last_choice()["pool"]))
	if decision.has("direct"):
		_begin(decision["direct"])
		return
	_decision = decision
	if get_signal_connection_list("choice_needed").is_empty():
		# no menu is listening (it ships with the second pool's content): take the pre-selected pool
		choose(decision["options"][decision["selected"]]["id"])
		return
	choice_needed.emit(decision)

## The player's pick from the choice. Only an unlocked pool of the pending decision counts, once.
func choose(pool_id: String) -> void:
	if _decision.is_empty() or pool_id == "":
		return
	for i in _decision["options"].size():
		var o: Dictionary = _decision["options"][i]
		if not o["locked"] and o["id"] == pool_id:
			_begin(pool_id)
			return

func _begin(pool_id: String) -> void:
	var species: String = str(_progress.last_choice()["species"])
	_progress.pending_start = {"pool": pool_id, "species": species}
	_progress.set_last_choice(pool_id, species)
	_decision = {}
	restart_requested.emit()
