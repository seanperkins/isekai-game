class_name SlimeAnimator
extends RefCounted
## Plays the slime's clips (data/slime_clips.json): state -> frame name. A one-shot holds its last
## frame; a loop wraps. A clip with an "exit" list plays those frames (at EXIT_FPS) when it is left,
## which is how Spread un-squashes instead of snapping.

const CLIPS := "res://data/slime_clips.json"
const EXIT_FPS := 20.0

var clips := {}
var _state := ""
var _time := 0.0
var _exit: Array = []
var _exit_time := 0.0

func _init(p_clips: Dictionary) -> void:
	clips = p_clips

static func load_clips(path: String = CLIPS) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("SlimeAnimator: cannot read %s" % path)
		return {}
	return json.data

func state() -> String:
	return _state

func play(state_name: String) -> void:
	if state_name == _state or not clips.has(state_name):
		return
	var old: Dictionary = clips.get(_state, {})
	if old.has("exit"):
		_exit = old["exit"]
		_exit_time = 0.0
	_state = state_name
	_time = 0.0

func advance(delta: float) -> void:
	if not _exit.is_empty():
		_exit_time += delta
		if int(_exit_time * EXIT_FPS) >= _exit.size():
			_exit = []
		return
	_time += delta

func frame() -> String:
	if not _exit.is_empty():
		return _exit[mini(int(_exit_time * EXIT_FPS), _exit.size() - 1)]
	var clip: Dictionary = clips[_state]
	var frames: Array = clip["frames"]
	var index := int(_time * float(clip["fps"]))
	if bool(clip["loop"]):
		return frames[posmod(index, frames.size())]
	return frames[mini(index, frames.size() - 1)]
