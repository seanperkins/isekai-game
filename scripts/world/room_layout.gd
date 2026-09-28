class_name RoomLayout
extends RefCounted
## The starting cave as data: solids, decor, spawns and the player start.
## It holds the spec's per-run food minimums, so every skill in the slice is reachable.
##
## Five screens wide, three tall. Four bands, all reachable by plain jumps from the floor:
##   lower hall (floor y 1040)  - the original room, then an east hall under a rock arch
##   middle tier (y ~700-740)   - via the stair tower at x 1360
##   upper tier (y ~400-480)    - via the east stair tower at x 3000, or the west stairs
##   top gallery (y 170)        - via the stairs above the upper tier
## Between the upper tier's west and east halves is a swing gap under three anchor rocks:
## thread users cross it on a rope; everyone else walks round.

const TEST_ROOM := {
	"size": Vector2(3200, 1080),
	"player": Vector2(60, 1010),
	"solids": [
		Rect2(0, 1040, 3200, 40),     # floor (first: tests rely on it)
		Rect2(-20, 0, 20, 1080),      # left wall
		Rect2(3200, 0, 20, 1080),     # right wall
		Rect2(0, -20, 3200, 20),      # ceiling
		# --- Lower hall, west: the original room. Steps rise at most 54 px (base apex ~60). ---
		Rect2(260, 986, 120, 12),
		Rect2(420, 934, 100, 12),
		Rect2(760, 860, 16, 180),     # wall-cling column
		Rect2(900, 986, 140, 12),
		Rect2(1060, 934, 100, 12),
		Rect2(1200, 882, 120, 12),
		# Stair tower up to the middle tier.
		Rect2(1360, 990, 70, 12),
		Rect2(1470, 940, 70, 12),
		Rect2(1360, 890, 70, 12),
		Rect2(1470, 840, 70, 12),
		Rect2(1360, 790, 70, 12),
		# --- Lower hall, east ---
		Rect2(1700, 986, 120, 12),
		Rect2(1880, 934, 120, 12),
		Rect2(2000, 620, 500, 24),    # rock arch: a ceiling to swing from, a floor above
		Rect2(2300, 880, 16, 160),    # column
		Rect2(2450, 986, 140, 12),
		Rect2(2640, 934, 120, 12),
		Rect2(2820, 882, 120, 12),
		# East stair tower up to the upper tier.
		Rect2(3000, 830, 70, 12),
		Rect2(3110, 780, 70, 12),
		Rect2(3000, 730, 70, 12),
		Rect2(3110, 680, 70, 12),
		Rect2(3000, 630, 70, 12),
		Rect2(3110, 580, 70, 12),
		Rect2(3000, 530, 70, 12),
		# --- Middle tier ---
		Rect2(1440, 740, 300, 12),
		Rect2(1000, 740, 380, 12),
		Rect2(560, 720, 380, 12),
		Rect2(100, 700, 400, 12),
		Rect2(1800, 700, 160, 12),
		Rect2(1900, 650, 60, 12),     # step onto the arch
		# West stairs from the middle tier to the upper tier.
		Rect2(120, 650, 70, 12),
		Rect2(230, 600, 70, 12),
		Rect2(120, 550, 70, 12),
		Rect2(230, 500, 70, 12),
		Rect2(120, 450, 70, 12),
		# --- Upper tier ---
		Rect2(220, 400, 520, 12),     # west half
		Rect2(2600, 480, 340, 12),
		Rect2(2200, 440, 340, 12),
		Rect2(1780, 420, 360, 12),
		Rect2(1360, 440, 360, 12),    # east half ends here; the swing gap is to the west
		# Anchor rocks over the swing gap (x 740-1360), too high to stand on.
		Rect2(770, 282, 90, 28),
		Rect2(1000, 282, 90, 28),
		Rect2(1230, 282, 90, 28),
		# Stairs from the upper tier up to the top gallery.
		Rect2(1800, 370, 70, 12),
		Rect2(1910, 320, 70, 12),
		Rect2(1800, 270, 70, 12),
		Rect2(1910, 220, 70, 12),
		# --- Top gallery ---
		Rect2(1400, 170, 450, 12),
	],
	"decor": [
		# Lower hall, west (the original room).
		{"id": "crystal_teal", "pos": Vector2(110, 1040), "light": Color(0.3, 1.0, 0.9)},
		{"id": "crystal_purple", "pos": Vector2(610, 1040), "light": Color(0.8, 0.4, 1.0)},
		{"id": "crystal_blue", "pos": Vector2(1010, 1040), "light": Color(0.3, 0.5, 1.0)},
		{"id": "crystal_teal", "pos": Vector2(1580, 1040), "light": Color(0.3, 1.0, 0.9)},
		{"id": "crystal_purple", "pos": Vector2(470, 934), "light": Color(0.8, 0.4, 1.0)},
		{"id": "torch", "pos": Vector2(330, 956), "light": Color(1.0, 0.6, 0.25)},
		{"id": "torch", "pos": Vector2(1260, 870), "light": Color(1.0, 0.6, 0.25)},
		{"id": "vine", "pos": Vector2(300, 998), "anchor": "top"},
		{"id": "vine", "pos": Vector2(980, 998), "anchor": "top"},
		{"id": "vine", "pos": Vector2(1280, 894), "anchor": "top"},
		{"id": "stalactite", "pos": Vector2(470, 946), "anchor": "top"},
		{"id": "stalactite", "pos": Vector2(1110, 946), "anchor": "top"},
		# Lower hall, east.
		{"id": "crystal_blue", "pos": Vector2(2080, 1040), "light": Color(0.3, 0.5, 1.0)},
		{"id": "crystal_teal", "pos": Vector2(2700, 1040), "light": Color(0.3, 1.0, 0.9)},
		{"id": "crystal_purple", "pos": Vector2(3120, 1040), "light": Color(0.8, 0.4, 1.0)},
		{"id": "torch", "pos": Vector2(2880, 852), "light": Color(1.0, 0.6, 0.25)},
		{"id": "vine", "pos": Vector2(2150, 644), "anchor": "top"},
		{"id": "vine", "pos": Vector2(2420, 644), "anchor": "top"},
		{"id": "stalactite", "pos": Vector2(2280, 644), "anchor": "top"},
		# Middle tier.
		{"id": "crystal_purple", "pos": Vector2(300, 700), "light": Color(0.8, 0.4, 1.0)},
		{"id": "crystal_teal", "pos": Vector2(1100, 740), "light": Color(0.3, 1.0, 0.9)},
		{"id": "torch", "pos": Vector2(1600, 710), "light": Color(1.0, 0.6, 0.25)},
		{"id": "torch", "pos": Vector2(760, 690), "light": Color(1.0, 0.6, 0.25)},
		# Upper tier and the arch top.
		{"id": "crystal_blue", "pos": Vector2(2400, 620), "light": Color(0.3, 0.5, 1.0)},
		{"id": "torch", "pos": Vector2(2700, 450), "light": Color(1.0, 0.6, 0.25)},
		{"id": "crystal_purple", "pos": Vector2(1500, 440), "light": Color(0.8, 0.4, 1.0)},
		{"id": "crystal_teal", "pos": Vector2(500, 400), "light": Color(0.3, 1.0, 0.9)},
		{"id": "stalactite", "pos": Vector2(2350, 452), "anchor": "top"},
		# Vines hang from the anchor rocks: a hint that the thread can stick there.
		{"id": "vine", "pos": Vector2(815, 310), "anchor": "top"},
		{"id": "vine", "pos": Vector2(1045, 310), "anchor": "top"},
		{"id": "vine", "pos": Vector2(1275, 310), "anchor": "top"},
		# Top gallery.
		{"id": "torch", "pos": Vector2(1500, 140), "light": Color(1.0, 0.6, 0.25)},
		{"id": "crystal_blue", "pos": Vector2(1700, 170), "light": Color(0.3, 0.5, 1.0)},
	],
	"spawns": [
		# Bats fly; ground enemies stand 20 px above their ledge; spiders hang 12 px under rock.
		{"id": "bat", "pos": Vector2(300, 920)},
		{"id": "bat", "pos": Vector2(470, 890)},
		{"id": "bat", "pos": Vector2(980, 900)},
		{"id": "bat", "pos": Vector2(1620, 600)},
		{"id": "bat", "pos": Vector2(2300, 320)},
		{"id": "bat", "pos": Vector2(900, 560)},
		{"id": "toad", "pos": Vector2(200, 1020)},
		{"id": "toad", "pos": Vector2(420, 1020)},
		{"id": "toad", "pos": Vector2(680, 1020)},
		{"id": "toad", "pos": Vector2(1100, 1020)},
		{"id": "toad", "pos": Vector2(1760, 1020)},
		{"id": "toad", "pos": Vector2(700, 700)},
		{"id": "toad", "pos": Vector2(2350, 420)},
		{"id": "lizard", "pos": Vector2(860, 1020)},
		{"id": "lizard", "pos": Vector2(1300, 1020)},
		{"id": "lizard", "pos": Vector2(1600, 1020)},
		{"id": "lizard", "pos": Vector2(2100, 1020)},
		{"id": "lizard", "pos": Vector2(2600, 1020)},
		{"id": "lizard", "pos": Vector2(1200, 720)},
		{"id": "lizard", "pos": Vector2(1550, 420)},
		{"id": "spider", "pos": Vector2(340, 724)},
		{"id": "spider", "pos": Vector2(1150, 764)},
		{"id": "spider", "pos": Vector2(1500, 464)},
		{"id": "spider", "pos": Vector2(2200, 656)},
		{"id": "spider", "pos": Vector2(600, 424)},
		{"id": "water_pool", "pos": Vector2(150, 1036)},
		{"id": "water_pool", "pos": Vector2(1250, 1036)},
		{"id": "water_pool", "pos": Vector2(2740, 1036)},
	],
}
