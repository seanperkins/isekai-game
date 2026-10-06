extends Node2D
## A stand-in for a weak gate in a test: it counts how often it was dissolved.

var dissolved := 0

func dissolve() -> void:
	dissolved += 1
