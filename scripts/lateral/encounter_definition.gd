extends Resource
@export var encounter_id: String
@export_enum("NORMAL", "ARENA") var mode: int = 1
@export var title: String
@export var arena_scene: String
@export var enemy_scene: String
@export var selection_allowed: bool = false
@export var boss: bool = false

@export var music: AudioStream
