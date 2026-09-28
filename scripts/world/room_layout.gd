class_name RoomLayout
extends RefCounted
## The vertical-slice test room as data: solids, spawns and the player start.
## It holds the spec's per-run food minimums, so every skill in the slice is reachable.

const TEST_ROOM := {
	"player": Vector2(60, 290),
	"solids": [
		Rect2(0, 320, 1600, 40),      # floor
		Rect2(-20, 0, 20, 360),       # left wall
		Rect2(1600, 0, 20, 360),      # right wall
		Rect2(0, -20, 1600, 20),      # ceiling
		# Platforms step up at most 54 px (base jump apex ~60 px), each within reach of the one below.
		Rect2(260, 266, 120, 12),     # platform (54 px above the floor)
		Rect2(420, 214, 100, 12),     # platform (52 px above the previous)
		Rect2(760, 140, 16, 180),     # wall-cling column
		Rect2(900, 266, 140, 12),     # platform
		Rect2(1060, 214, 100, 12),    # platform
		Rect2(1200, 162, 120, 12),    # platform
	],
	"spawns": [
		{"id": "bat", "pos": Vector2(300, 200)},
		{"id": "bat", "pos": Vector2(470, 170)},
		{"id": "bat", "pos": Vector2(980, 180)},
		{"id": "toad", "pos": Vector2(200, 300)},
		{"id": "toad", "pos": Vector2(420, 300)},
		{"id": "toad", "pos": Vector2(680, 300)},
		{"id": "toad", "pos": Vector2(1100, 300)},
		{"id": "lizard", "pos": Vector2(860, 300)},
		{"id": "lizard", "pos": Vector2(1300, 300)},
		{"id": "lizard", "pos": Vector2(1450, 300)},
		{"id": "spider", "pos": Vector2(340, 12)},
		{"id": "spider", "pos": Vector2(1000, 12)},
		{"id": "spider", "pos": Vector2(1380, 12)},
		{"id": "water_pool", "pos": Vector2(150, 316)},
		{"id": "water_pool", "pos": Vector2(1250, 316)},
	],
}
