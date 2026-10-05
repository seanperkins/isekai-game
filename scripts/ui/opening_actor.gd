class_name OpeningActor
extends Node2D
## One combatant in the opening's battle: a sprite sheet (assets/sheets/<set>.png) played through named clips (the set's entry in
## data/opening_clips.json), the same machinery the creatures use. The origin is at the feet, so a sprite stands on the floor line
## it is placed on. `flip` mirrors the art: the sheets are drawn facing right and the commuter faces the truck, so he is flipped.

const CLIPS := "res://data/opening_clips.json"

var set_name := ""
var flip := false:
	set(value):
		flip = value
		_sprite.flip_h = value

var _sheet: SpriteSheet
var _animator: SlimeAnimator
var _sprite := Sprite2D.new()

func _init() -> void:
	add_child(_sprite)

## Loads the set's sheet and clips. False when either is missing (the actor then draws nothing).
func setup(p_set: String) -> bool:
	set_name = p_set
	var clips := SlimeAnimator.load_clips(CLIPS)
	_sheet = SpriteSheet.load_set(p_set)
	if _sheet == null or not clips.has(p_set):
		return false
	_animator = SlimeAnimator.new(clips[p_set])
	_animator.play("idle")
	_show(_animator.frame())
	return true

## Starts a clip. An unknown clip name changes nothing; the clip already playing is not restarted.
func play(clip_name: String) -> void:
	if _animator != null:
		_animator.play(clip_name)
		_show(_animator.frame())

func clip() -> String:
	return _animator.state() if _animator != null else ""

## The name of the frame on screen.
func frame() -> String:
	return _animator.frame() if _animator != null else ""

## How tall the frame on screen is, scale included (0 when nothing is loaded).
func height() -> float:
	if _sheet == null or _animator == null or not _sheet.has_frame(_animator.frame()):
		return 0.0
	return _sheet.frame_size(_animator.frame()).y * scale.y

func clip_names() -> Array:
	return _animator.clips.keys() if _animator != null else []

func _process(delta: float) -> void:
	if _animator == null:
		return
	_animator.advance(delta)
	_show(_animator.frame())

func _show(frame_name: String) -> void:
	if _sheet == null or not _sheet.has_frame(frame_name):
		return
	_sprite.texture = _sheet.frame_texture(frame_name)
	_sprite.position.y = -_sheet.frame_size(frame_name).y / 2.0  # the bottom of the frame on the origin
