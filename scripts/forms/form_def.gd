class_name FormDef
extends Resource
## One evolved body. Content lives in res://data/forms/, generated once by tools/build_forms.gd and
## editable by hand afterwards (24 hand-tuned forms do not need a generator at runtime).

@export var id := ""
@export var display_name := ""
## 2 to 4; stage 1 is the base slime (not a FormDef).
@export var stage := 2
## weaver | tide | toxic | bulwark | echo | greater (the neutral fallback)
@export var lineage := ""
## The forms this one grows from: ["slime"] at stage 2, the stage-2 form at stage 3, the two stage-3
## forms of the lineage at stage 4.
@export var parents: Array = []
## The essences that make this lineage's affinity (stage-2 forms only).
@export var essences: Array = []
## The skills that open this lineage (stage-2 lineage forms only): reaching any of them, or having evolved one, offers the lineage.
@export var powers: Array = []
## stat id -> amount added (StatKeys)
@export var stats := {}
## FormEffects.TRAITS ids
@export var traits: Array = []
## Player skill ids this body grants on arrival.
@export var grants: Array = []
## Multiplies the base sheet when the form has no art of its own.
@export var tint := Color.WHITE
## The sprite is this much larger (never the collision box).
@export var size := 1.0
## A sheet set in res://assets/sheets/ (e.g. "form_weaver"), or "" for the tinted base sheet.
@export var sprite_set := ""
@export var blurb := ""
