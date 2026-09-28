class_name Hud
extends CanvasLayer
## HP, active slots, the Great Sage pop-up, the ticker, and the inspect/status panel.

const PANEL_SECONDS := 4.0
const TICKER_SECONDS := 3.0

var _player: Player
var _rules
var _queue: AnnouncerQueue
var _hp := Label.new()
var _slots := Label.new()
var _popup := Label.new()
var _popup_panel := PanelContainer.new()
var _ticker := Label.new()
var _panel := Label.new()
var _panel_left := 0.0
var _ticker_lines: Array = []  # [[text, seconds_left]]

func bind(player: Player, rules, _compendium: CompendiumModel, queue: AnnouncerQueue) -> void:
	_player = player
	_rules = rules
	_queue = queue
	player.inspect_report.connect(_on_inspect_report)

func _ready() -> void:
	_hp.position = Vector2(12, 8)
	_slots.position = Vector2(12, 28)
	_popup.position = Vector2(320, 24)
	_ticker.position = Vector2(12, 300)
	_panel.position = Vector2(700, 60)
	# Great Sage window: translucent blue with a glowing border.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.1, 0.28, 0.85)
	style.border_color = Color(0.45, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_popup_panel.add_theme_stylebox_override("panel", style)
	_popup_panel.position = Vector2(360, 16)
	_popup.position = Vector2.ZERO
	_popup_panel.add_child(_popup)
	for l in [_hp, _slots, _popup_panel, _ticker, _panel]:
		add_child(l)

func _process(delta: float) -> void:
	if _player == null:
		return
	_hp.text = hp_text()
	_slots.text = StatusText.slot_line(_player.skillset.slots, _rules, Controls.slot_labels())
	_popup.text = popup_text()
	_popup_panel.visible = _popup.text != ""
	var entry := _queue.pop_ticker()
	while not entry.is_empty():
		_ticker_lines.append([StatusText.ticker_text(entry, _rules), TICKER_SECONDS])
		entry = _queue.pop_ticker()
	for line in _ticker_lines:
		line[1] -= delta
	_ticker_lines = _ticker_lines.filter(func(l): return l[1] > 0.0)
	_ticker.text = "\n".join(_ticker_lines.map(func(l): return l[0]))
	_panel_left = maxf(0.0, _panel_left - delta)
	_panel.visible = _panel_left > 0.0

func hp_text() -> String:
	return "HP %d/%d" % [_player.health.hp, _player.health.max_hp]

func popup_text() -> String:
	var current := _queue.current()
	return current.get("text", "") if not current.is_empty() else ""

func _on_inspect_report(lines: PackedStringArray) -> void:
	_panel.text = "\n".join(lines)
	_panel_left = PANEL_SECONDS
