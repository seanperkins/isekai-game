class_name RoomBarrier
extends RoomBlock
## A wall the dissolve verb removes (the group `dissolvable`, `dissolve()`): it stands in front of a side room, and the verb says
## `barrier_broken` when it opens it. A room built again puts it back: it is a door to a side room, not a shortcut.

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	add_to_group("dissolvable")

func dissolve() -> void:
	remove_from_group("dissolvable")
	queue_free()
