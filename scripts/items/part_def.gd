class_name PartDef
extends Resource
## One part a body can carry or wear. Content lives in res://data/parts/, generated from tools/parts.json.

@export var id := ""
@export var display_name := ""
## "graft" (worn by the undead for its passive and a nudge toward a path), "held" (carried, asked for by a form) or "key" (carried,
## opens a form another way).
@export var kind := "graft"
## A graft's place on the body ("ribs", "claw", ...); "" for a part that is not worn.
@export var slot := ""
## How many of it can be worn at once (1, or 2 for claws and wrappings).
@export var worn_max := 1
## The passive a worn graft gives: stat key -> amount.
@export var stats: Dictionary = {}
@export var text := ""
## The pickup's colour, until the parts have art.
@export var color := Color.WHITE
