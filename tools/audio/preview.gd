extends Control
## Audition every biome bed and every cue. Run from the project root:
##   godot --path . res://tools/audio/preview.tscn
## Loop cues toggle: press once to start, again to stop.

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_header(box, "Biome beds (music + ambience)")
	for area in CueCatalog.BIOMES:
		_button(box, "biome: " + area, func() -> void: Audio.set_biome(area))
	var by_bus := {}
	for id in Audio.catalog.cues:
		var bus: String = Audio.catalog.cues[id]["bus"]
		if not by_bus.has(bus):
			by_bus[bus] = []
		by_bus[bus].append(id)
	for bus in by_bus:
		_header(box, "Cues on " + bus)
		for id in by_bus[bus]:
			var looping: bool = Audio.catalog.cues[id].get("loop", false)
			_button(box, id + ("  (loop)" if looping else ""), func() -> void: _play(id, looping))

func _play(id: String, looping: bool) -> void:
	if looping and Audio.is_looping(id):
		Audio.stop_loop(id)
	else:
		Audio.play_cue(id)

func _header(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	box.add_child(l)

func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	box.add_child(b)
