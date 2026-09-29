extends Node
## The Audio autoload: the one place where events become sound. Gameplay emits semantic events
## (EventBus.game_event, EventBus.world_event) and never names a cue, a bus or a file;
## data/audio/cues.json maps each event to a cue. Registered after Compendium (the settings live
## in its Profile) and SkillRules (its signals feed the stingers).

const VOICES := 16
const CATALOG_PATH := "res://data/audio/cues.json"
const DUCK_DB := -4.0
const DUCK_ATTACK := 0.15
const DUCK_RELEASE := 0.6
const REVERB_SECONDS := 1.0

var catalog: CueCatalog
var settings := AudioSettings.new()
var director: MusicDirector
var last_cue := ""  # the last cue that started; tests and the preview tool read it
var _clock: Callable
var _pool: VoicePool
var _combo: ComboPitch
var _rng := RandomNumberGenerator.new()
var _voices: Array = []   # per slot: [AudioStreamPlayer, AudioStreamPlayer2D]
var _loops := {}          # looping cue id -> slot
var _streams := {}        # "path|loop" -> AudioStream, or null for a file that would not load
var _duck_holds := 0
var _duck_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the duck and crossfade tweens run while the game is paused
	_rng.randomize()
	catalog = CueCatalog.load_file(CATALOG_PATH)
	for e in catalog.validate(func(p: String) -> bool: return ResourceLoader.exists(p)):
		push_error("audio: " + e)
	_clock = func() -> float: return Time.get_ticks_msec() / 1000.0
	_pool = VoicePool.new(VOICES, _clock)
	_combo = ComboPitch.new(_clock)
	for i in VOICES:
		var flat := AudioStreamPlayer.new()
		var spatial := AudioStreamPlayer2D.new()
		flat.finished.connect(_on_voice_finished.bind(i))
		spatial.finished.connect(_on_voice_finished.bind(i))
		add_child(flat)
		add_child(spatial)
		_voices.append([flat, spatial])
	director = MusicDirector.new()
	director.setup(catalog, OneshotScheduler.new(_rng))
	add_child(director)
	settings.load_from(Compendium.profile)
	settings.apply()
	EventBus.game_event.connect(_on_event)
	EventBus.world_event.connect(_on_event)
	SkillRules.skill_unlocked.connect(func(id: String) -> void: _on_event("skill_unlocked", {"id": id}))
	SkillRules.skill_leveled.connect(func(id: String, level: int) -> void: _on_event("skill_leveled", {"id": id, "level": level}))
	SkillRules.evolution_ready.connect(func(id: String) -> void: _on_event("evolution_ready", {"id": id}))
	SkillRules.run_started.connect(reset)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for shot in director.scheduler.advance(delta):
		play_cue(shot["cue"], player.global_position + shot["offset"])

func set_biome(area: String) -> void:
	if director.set_biome(area):
		_fade_reverb(float(catalog.biomes[area]["reverb_wet"]))

func adjust_setting(key: String, direction: int) -> void:
	settings.adjust(key, direction)
	settings.apply()

## Silences everything and forgets cooldowns and combos: every voice stops, every loop ends and
## the duck lets go. A new run, a death and a scene reload all start from here.
func reset() -> void:
	for cue_id in _loops.keys():
		stop_loop(cue_id)
	for pair in _voices:
		for voice in pair:
			voice.stop()
	_pool = VoicePool.new(VOICES, _clock)
	_combo = ComboPitch.new(_clock)
	_duck_holds = 0
	_fade_duck(0.0, DUCK_RELEASE)

func is_looping(cue_id: String) -> bool:
	return _loops.has(cue_id)

func stop_loop(cue_id: String) -> void:
	if not _loops.has(cue_id):
		return
	var slot: int = _loops[cue_id]
	_loops.erase(cue_id)
	for voice in _voices[slot]:
		voice.stop()
	_pool.release(slot)

func play_cue(cue_id: String, pos: Vector2 = Vector2.INF) -> void:
	var rule: Dictionary = catalog.cues.get(cue_id, {})
	if rule.is_empty():
		return
	var loop := bool(rule.get("loop", false))
	if loop and _loops.has(cue_id):
		return
	var stream := _stream(catalog.pick_file(cue_id, _rng), loop)
	if stream == null:
		return
	var volume := float(rule.get("volume_db", 0.0))
	var slot := _pool.acquire(cue_id, volume, float(rule.get("cooldown", 0.0)))
	if slot == -1:
		return
	for looping in _loops.keys():  # a stolen voice ends the loop it was carrying
		if _loops[looping] == slot:
			_loops.erase(looping)
	var spatial := bool(rule.get("positional", false)) and pos != Vector2.INF
	var pair: Array = _voices[slot]
	pair[0].stop()
	pair[1].stop()
	var voice = pair[1] if spatial else pair[0]
	voice.stream = stream
	voice.bus = str(rule["bus"])
	voice.volume_db = volume
	voice.process_mode = Node.PROCESS_MODE_ALWAYS if str(rule["bus"]) == "UI" else Node.PROCESS_MODE_PAUSABLE
	voice.pitch_scale = _pitch(cue_id, rule)
	if spatial:
		voice.global_position = pos
	voice.play()
	if loop:
		_loops[cue_id] = slot
	last_cue = cue_id
	if bool(rule.get("duck", false)):
		_duck_for(stream.get_length())

func _on_event(event_name: String, tags: Dictionary) -> void:
	if event_name == "player_died":
		reset()  # the heartbeat and the run loop end before the death cue plays
	if event_name == "menu_opened":
		_hold_duck()
	elif event_name == "menu_closed":
		_release_duck()
		if settings.dirty:
			settings.save_to(Compendium.profile)
	var routed := catalog.route(event_name, tags)
	if routed.has("cue"):
		play_cue(routed["cue"], tags.get("pos", Vector2.INF))
	elif routed.has("stop"):
		stop_loop(routed["stop"])

func _on_voice_finished(slot: int) -> void:
	_pool.release(slot)

func _pitch(cue_id: String, rule: Dictionary) -> float:
	var pitch := 1.0 + _rng.randf_range(-1.0, 1.0) * float(rule.get("pitch_jitter", 0.0))
	var combo: Dictionary = rule.get("combo", {})
	if not combo.is_empty():
		var steps := _combo.next(cue_id, float(combo["window"]), int(combo["max_steps"]))
		pitch *= pow(2.0, steps * float(combo["step"]) / 12.0)  # step is in semitones
	return pitch

func _stream(path: String, loop: bool) -> AudioStream:
	var key := "%s|%s" % [path, loop]
	if _streams.has(key):
		return _streams[key]
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path).duplicate()
		if loop and stream is AudioStreamOggVorbis:
			stream.loop = true
	else:
		push_warning("audio: cannot load '%s'" % path)
	_streams[key] = stream  # a failure is cached too, so it warns once
	return stream

func _hold_duck() -> void:
	_duck_holds += 1
	_fade_duck(DUCK_DB, DUCK_ATTACK)

func _release_duck() -> void:
	_duck_holds = maxi(0, _duck_holds - 1)
	if _duck_holds == 0:
		_fade_duck(0.0, DUCK_RELEASE)

func _duck_for(seconds: float) -> void:
	_hold_duck()
	get_tree().create_timer(seconds, true).timeout.connect(_release_duck)

func _fade_duck(target_db: float, seconds: float) -> void:
	var i := AudioServer.get_bus_index("Music")
	if i == -1 or AudioServer.get_bus_effect_count(i) == 0:
		return
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(AudioServer.get_bus_effect(i, 0), "volume_db", target_db, seconds)

func _fade_reverb(wet: float) -> void:
	var i := AudioServer.get_bus_index("SFX_World")
	if i == -1 or AudioServer.get_bus_effect_count(i) == 0:
		return
	create_tween().tween_property(AudioServer.get_bus_effect(i, 0), "wet", wet, REVERB_SECONDS)
