extends Node
## Global gameplay event channel. Only the player's components emit here.

signal game_event(name: String, tags: Dictionary)
