extends Node
## Global event channels.
## game_event: gameplay events. Only the player's components emit here. SkillRules and the
## Compendium count them.
## world_event: audio-only semantic moments (landings, hits, menus). Never counted; only Audio
## listens. Enemies and world objects may emit here: these are not gameplay events.

signal game_event(name: String, tags: Dictionary)
signal world_event(name: String, tags: Dictionary)
