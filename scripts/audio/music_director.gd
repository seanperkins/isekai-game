class_name MusicDirector
extends Node
## The music and ambience beds. Each has two players so a biome change can crossfade: the new bed
## fades in while the old one fades out with equal power (sin / cos), so the blend has no dip.

const ASSET_DIR := "res://assets/audio/"
const FADE_SECONDS := 2.0
const SILENT_DB := -80.0
const FLOOR_LINEAR := 0.0001

var current_area := ""
var current_music := ""
var scheduler: OneshotScheduler
var _catalog: CueCatalog
var _music: Array = []
var _ambience: Array = []
var _front := 0  # which player of each pair is the audible bed
var _fade: Tween

func _init() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		_music.append(m)
		_ambience.append(a)

func _ready() -> void:
	for p in _music + _ambience:
		p.volume_db = SILENT_DB
		add_child(p)

func setup(catalog: CueCatalog, p_scheduler: OneshotScheduler) -> void:
	_catalog = catalog
	scheduler = p_scheduler

## Equal-power gains for a fade at t in 0..1: x fades in, y fades out.
static func fade_gains(t: float) -> Vector2:
	var a := clampf(t, 0.0, 1.0) * PI / 2.0
	return Vector2(sin(a), cos(a))

## True when the bed changed. The same area, or an area with no bed, changes nothing.
func set_biome(area: String) -> bool:
	if area == current_area:
		return false
	var bed: Dictionary = _catalog.biomes.get(area, {})
	if bed.is_empty():
		push_warning("MusicDirector: unknown biome '%s'" % area)
		return false
	var music := _load_loop(str(bed["music"]))
	var ambience := _load_loop(str(bed["ambience"]))
	if music == null or ambience == null:
		push_warning("MusicDirector: could not load the beds for '%s'" % area)
		return false
	current_area = area
	current_music = ASSET_DIR + str(bed["music"])
	_front = 1 - _front
	_start(_music[_front], music)
	_start(_ambience[_front], ambience)
	scheduler.set_biome(bed["oneshots"])
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_apply_fade, 0.0, 1.0, FADE_SECONDS)
	return true

func _start(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()

func _apply_fade(t: float) -> void:
	var g := fade_gains(t)
	for pair in [_music, _ambience]:
		pair[_front].volume_db = linear_to_db(maxf(g.x, FLOOR_LINEAR))
		pair[1 - _front].volume_db = linear_to_db(maxf(g.y, FLOOR_LINEAR))
		if t >= 1.0:
			pair[1 - _front].stop()

func _load_loop(file: String) -> AudioStream:
	var path := ASSET_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path).duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream
