class_name OpeningStage
extends Node2D
## The truck dodge's picture, drawn in code (placeholder art, restyled later): a dark road strip, the truck sliding in from the left
## and a small figure on the road. `approach` (0 to 1) is the truck's progress, `hit` hides the figure once the truck connects,
## and `flash` (1 down to 0) is a white flash over the screen. OpeningScene sets all three; this only draws them.

const ROAD := Rect2(0, 190, 640, 64)
const FIGURE_X := 470.0
const TRUCK_FROM := -170.0
const TRUCK_TO := 300.0  # the truck's left edge when it stops at the figure
const COL_ROAD := Color(0.1, 0.1, 0.13)
const COL_LINE := Color(0.55, 0.5, 0.2)
const COL_TYRE := Color(0.05, 0.05, 0.06)

var approach := 0.0
var flash := 0.0
var hit := false

func _draw() -> void:
	draw_rect(ROAD, COL_ROAD)
	for i in 8:
		draw_rect(Rect2(20.0 + i * 80.0, ROAD.position.y + 30.0, 40.0, 4.0), COL_LINE)
	var feet := ROAD.position.y + 44.0
	if not hit:
		_figure(feet)
	_truck(lerpf(TRUCK_FROM, TRUCK_TO, approach), feet)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, flash))

func _figure(feet: float) -> void:
	draw_circle(Vector2(FIGURE_X, feet - 34.0), 6.0, Color(0.9, 0.8, 0.7))
	draw_rect(Rect2(FIGURE_X - 5.0, feet - 28.0, 10.0, 20.0), Color(0.35, 0.5, 0.8))
	draw_rect(Rect2(FIGURE_X - 5.0, feet - 8.0, 4.0, 8.0), Color(0.2, 0.2, 0.3))
	draw_rect(Rect2(FIGURE_X + 1.0, feet - 8.0, 4.0, 8.0), Color(0.2, 0.2, 0.3))

func _truck(x: float, feet: float) -> void:
	draw_rect(Rect2(x, feet - 52.0, 110.0, 44.0), Color(0.75, 0.75, 0.78))  # the box
	draw_rect(Rect2(x + 110.0, feet - 38.0, 44.0, 30.0), Color(0.8, 0.25, 0.2))  # the cab
	draw_rect(Rect2(x + 126.0, feet - 34.0, 22.0, 12.0), Color(0.6, 0.85, 0.95))  # its window
	draw_circle(Vector2(x + 30.0, feet - 6.0), 9.0, COL_TYRE)
	draw_circle(Vector2(x + 128.0, feet - 6.0), 9.0, COL_TYRE)
	draw_circle(Vector2(x + 152.0, feet - 20.0), 4.0, Color(1.0, 0.95, 0.6))  # a headlight
