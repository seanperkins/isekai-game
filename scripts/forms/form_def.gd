class_name FormDef
extends Resource
## One evolved body. Content lives in res://data/forms/, generated once by tools/build_forms.gd and
## editable by hand afterwards (24 hand-tuned forms do not need a generator at runtime).

@export var id := ""
@export var display_name := ""
## Which species this body belongs to (Form.SPECIES). A file with no `species` line is a slime form.
@export var species := "slime"
## 2 to 4; stage 1 is the species' base (not a FormDef).
@export var stage := 2
## weaver | tide | toxic | bulwark | echo | greater (the neutral fallback)
@export var lineage := ""
## The forms this one grows from: ["slime"] at stage 2, the stage-2 form at stage 3, the two stage-3
## forms of the lineage at stage 4.
@export var parents: Array = []
## The skills that open this lineage (stage-2 lineage forms only): reaching any of them, or having evolved one, offers the lineage.
@export var powers: Array = []
## The diet that shows this lineage in the Tree tab (`reveal`) and puts it on the stage-2 menu (`offer`): element id to the
## amount absorbed this life. Only a lineage form has them, and the offer names the same elements at the same amounts or more.
@export var reveal := {}
@export var offer := {}
## stat id -> amount added (StatKeys)
@export var stats := {}
## FormEffects.TRAITS ids
@export var traits: Array = []
## Player skill ids this body grants on arrival.
@export var grants: Array = []
## The form_verb skill this body's verb is (also in `grants`), or "" for none. It takes the previous form's verb's slot.
@export var verb := ""
## Multiplies the base sheet when the form has no art of its own.
@export var tint := Color.WHITE
## The sprite is this much larger (never the collision box).
@export var size := 1.0
## A sheet set in res://assets/sheets/ (e.g. "form_weaver"), or "" for the tinted base sheet.
@export var sprite_set := ""
@export var blurb := ""
## The essences this body reads (Essences.ALL): the elements that open it and that its kit leans on.
@export var reads: Array = []
## The areas (FormValidator.AREAS) it is found in, as a form of its own and as the creature it is in the world.
@export var host: Array = []
## The legend or tradition it is drawn from.
@export var source := ""
## What its verb does, and what it gives up: words for the Tree tab until the verb system gives them behaviour.
@export var verb_text := ""
@export var gives_up := ""
## How it opens: the diet, power, lesson, graft or condition the design asks for.
@export var opened_by := ""
