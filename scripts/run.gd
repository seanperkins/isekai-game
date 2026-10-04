class_name Run
extends Node
## One life. It owns what resets on death (which room you're in) and the death card, and it asks the game to restart. On death
## the goddess speaks for what killed you; when there is something to choose she opens her menu, and the choice decides where,
## as whom and with what head start the next life begins. The World handles space; the game reloads the scene on restart.

signal restart_requested
## There is something to choose: the menu shows `model` with her `line` and answers through accept().
signal goddess_needed(model: GoddessModel, line: String)

const DEATH_CARD_SECONDS := 1.5
const DEATH_TEXT := "You dissolve.\nA new life begins."

var room_id := ""
## Her scene. Null without one (an editor Play, or a Run bound without it): death then restarts at the last attuned place.
var goddess: Goddess
var _card := CanvasLayer.new()
var _card_label := Label.new()
var _ending := false
var _progress  # WorldProgress, or null
var _pools: Array = []
var _player: Node
var _model: GoddessModel
var _line := ""
var _opening := false  # the pending choice is her first meeting: accepting it ends the opening for good

func _ready() -> void:
	_card.layer = 30
	_card.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.75)
	shade.size = Vector2(640, 360)
	_card.add_child(shade)
	_card_label.text = DEATH_TEXT
	_card_label.size = Vector2(640, 360)
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.add_theme_font_size_override("font_size", 12)
	_card_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_card.add_child(_card_label)
	add_child(_card)

func bind(player: Node, world: Node, progress = null, altars: Array = [], p_goddess: Goddess = null) -> void:
	_progress = progress
	_pools = altars
	goddess = p_goddess
	_player = player
	player.died.connect(_on_player_died)
	world.room_entered.connect(func(id: String) -> void: room_id = id)
	room_id = world.current_id

func death_card_visible() -> bool:
	return _card.visible

## Her line for this death ("" before one, or without a goddess).
func line_text() -> String:
	return _line

func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	_line = _line_for_death()
	_card_label.text = _line if _line != "" else DEATH_TEXT
	_card.visible = true
	await get_tree().create_timer(DEATH_CARD_SECONDS).timeout
	_resolve()

## Counts the death and picks her line for what dealt the last blow.
func _line_for_death() -> String:
	if goddess == null:
		return ""
	var cause = _player.get("last_hit_cause") if _player != null else null
	return goddess.line_for_death(cause if typeof(cause) == TYPE_STRING else "")

## What happens after the death card: restart (with no progress, the old way), or start straight away when there is nothing to
## choose or nobody to ask, or open her menu and wait for accept().
func _resolve() -> void:
	if _progress == null:
		restart_requested.emit()
		return
	if goddess == null:
		_begin(_last_attuned_choice())
		return
	var model := goddess.model(_progress, _pools)
	var result := model.confirm()  # the pre-selected choice with an empty cart: the last place, free
	if result.is_empty() or not model.need_menu() or get_signal_connection_list("goddess_needed").is_empty():
		_begin(result)  # no menu is listening: take the pre-selected start so the game never hangs
		return
	_model = model
	goddess_needed.emit(model, _line)

## Her first meeting, after the opening's trucks: the menu opens with her first words `line` even though there is nothing to choose,
## no death is counted, and accepting it marks the opening seen and begins the Cave altar life. False, and nothing happens, with no
## goddess or progress (an editor Play), while a choice is pending or a death is under way, or when the menu could never be confirmed
## (no species loaded). With no menu listening it begins the pre-selected start, as _resolve does, so the game never hangs.
func open_first_meeting(line: String) -> bool:
	if _progress == null or goddess == null or _model != null or _ending:
		return false
	var model := goddess.model(_progress, _pools)
	var result := model.confirm()
	if result.is_empty():
		return false
	_opening = true
	_line = line
	if get_signal_connection_list("goddess_needed").is_empty():
		_begin(result)
		return true
	_model = model
	goddess_needed.emit(model, line)
	return true

## The menu's answer. Only a result exactly equal to what the pending model would give now counts, once: a forged, negative,
## underreported or stale kit and cost are ignored, and the menu stays open.
func accept(result: Dictionary) -> void:
	if _model == null or result.is_empty() or result != _model.confirm():
		return
	_model = null
	_begin(result)

func _last_attuned_choice() -> Dictionary:
	var last: Dictionary = _progress.last_choice()
	var altar := str(last["pool"])
	if not _progress.is_attuned(altar):
		altar = WorldProgress.DEFAULT_ALTAR
	return {"altar": altar, "species": str(last["species"]), "kit": {}, "cost": 0}

## Spends the cost, records the start (the saved choice keeps its `pool` key, which now holds an altar id) and asks for the restart.
func _begin(result: Dictionary) -> void:
	var altar := str(result.get("altar", WorldProgress.DEFAULT_ALTAR))
	var species := str(result.get("species", WorldProgress.DEFAULT_SPECIES))
	var kit: Dictionary = result["kit"] if typeof(result.get("kit")) == TYPE_DICTIONARY else {}
	var cost := int(result.get("cost", 0))
	if cost > 0 and (goddess == null or not goddess.soul.spend(cost)):
		kit = {}  # a purchase that cannot be paid for is not given
	_progress.pending_start = {"altar": altar, "species": species, "kit": kit}
	_progress.set_last_choice(altar, species)
	if _opening:
		_opening = false
		goddess.soul.finish_opening()
	restart_requested.emit()
