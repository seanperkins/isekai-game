class_name MusicDirector
extends Node
## The music and ambience beds. Each has two players so a biome change can crossfade: the new bed
## fades in while the old one fades out with equal power (sin / cos), so the blend has no dip.
## A theme (the opening's battle music) is a third player that takes over: the beds are held silent under it
## and fade back in when it ends. Beds started or switched meanwhile stay silent until then.

const ASSET_DIR := "res://assets/audio/"
const FADE_SECONDS := 2.0
const SILENT_DB := -80.0
const FLOOR_LINEAR := 0.0001

var current_area := ""
var current_music := ""
var theme_id := ""
var scheduler: OneshotScheduler
var _catalog: CueCatalog
var _music: Array = []
var _ambience: Array = []
var _front := 0  # which player of each pair is the audible bed
var _fade: Tween
var _theme: AudioStreamPlayer
var _theme_tween: Tween
var _theme_gain := 0.0  # 0 = silent, 1 = full
var _bed_gain := 1.0  # 1 = the beds at their level, 0 = held silent under a theme
var _xfade_t := 1.0  # where the biome crossfade has got to

func _init() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		_music.append(m)
		_ambience.append(a)
	_theme = AudioStreamPlayer.new()
	_theme.bus = "Music"

func _ready() -> void:
	for p in _music + _ambience + [_theme]:
		p.volume_db = SILENT_DB
		add_child(p)

func setup(catalog: CueCatalog, p_scheduler: OneshotScheduler) -> void:
	_catalog = catalog
	scheduler = p_scheduler

func theme_gain() -> float:
	return _theme_gain

func bed_gain() -> float:
	return _bed_gain

## The audible music bed's volume in dB (-80 is silent).
func bed_volume_db() -> float:
	return _music[_front].volume_db

func theme_player() -> AudioStreamPlayer:
	return _theme

## Equal-power gains for a fade at t in 0..1: x fades in, y fades out.
static func fade_gains(t: float) -> Vector2:
	var a := clampf(t, 0.0, 1.0) * PI / 2.0
	return Vector2(sin(a), cos(a))

## Equal-power gains for a theme's fade at t in 0..1, as (theme, beds): entering fades the theme in and the beds out, leaving
## the other way round.
static func theme_gains(t: float, entering: bool) -> Vector2:
	var g := fade_gains(t)
	return Vector2(g.x, g.y) if entering else Vector2(g.y, g.x)

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
	_xfade_t = 0.0  # a new crossfade starts here, so anything that refreshes the beds before its first step (a reset) sees t = 0, not the last one's end
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
	_xfade_t = t
	_refresh_beds()

## The beds' volumes: the biome crossfade's gains, times how far a theme has let them back.
func _refresh_beds() -> void:
	var g := fade_gains(_xfade_t)
	for pair in [_music, _ambience]:
		pair[_front].volume_db = linear_to_db(maxf(g.x * _bed_gain, FLOOR_LINEAR))
		pair[1 - _front].volume_db = linear_to_db(maxf(g.y * _bed_gain, FLOOR_LINEAR))
		if _xfade_t >= 1.0:
			pair[1 - _front].stop()

## Starts the theme `id` (from the catalog's themes), fading it in while the beds fade out. False when it is already playing or
## cannot be loaded.
func start_theme(id: String) -> bool:
	if id == theme_id:
		return false
	var rule: Dictionary = _catalog.themes.get(id, {})
	var stream := _load_loop(str(rule.get("music", ""))) if not rule.is_empty() else null
	if stream == null:
		push_warning("MusicDirector: cannot start the theme '%s'" % id)
		return false
	theme_id = id
	_theme.stream = stream
	_theme.volume_db = SILENT_DB
	_theme.play()
	_fade_theme(true, float(rule.get("fade_in", 0.5)))
	return true

## Fades the playing theme out and the beds back in. False when no theme is playing.
func stop_theme() -> bool:
	if theme_id == "":
		return false
	_fade_theme(false, float(_catalog.themes.get(theme_id, {}).get("fade_out", 1.5)))
	return true

## Ends the theme at once and gives the beds back: a new run, a death, a reload.
func end_theme() -> void:
	if _theme_tween != null:
		_theme_tween.kill()
	theme_id = ""
	_theme.stop()
	_theme_gain = 0.0
	_bed_gain = 1.0
	_theme.volume_db = SILENT_DB
	_refresh_beds()

## Fades from wherever the theme is now, so stopping part-way through a fade in does not jump to full volume first.
func _fade_theme(entering: bool, seconds: float) -> void:
	if _theme_tween != null:
		_theme_tween.kill()
	var now := clampf(_theme_gain, 0.0, 1.0)
	var t0 := asin(now) * 2.0 / PI if entering else acos(now) * 2.0 / PI
	var duration := seconds * (1.0 - t0)
	if duration <= 0.001:
		_apply_theme(1.0, entering)
		return
	_theme_tween = create_tween()
	_theme_tween.tween_method(_apply_theme.bind(entering), t0, 1.0, duration)

func _apply_theme(t: float, entering: bool) -> void:
	var g := theme_gains(t, entering)
	_theme_gain = g.x
	_bed_gain = g.y
	_theme.volume_db = linear_to_db(maxf(g.x, FLOOR_LINEAR))
	_refresh_beds()
	if t >= 1.0 and not entering:
		_theme.stop()
		theme_id = ""

func _load_loop(file: String) -> AudioStream:
	var path := ASSET_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path).duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream
