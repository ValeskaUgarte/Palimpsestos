class_name PalimAmbienceProfile
extends Resource
@export_enum("forest", "stone", "wood", "dirt", "grass", "wet") var surface_type: String = "forest"
@export var loop: AudioStream
@export var events: Array[AudioStream] = []
@export_range(3,120) var minimum_interval: float = 12.0
@export_range(3,120) var maximum_interval: float = 32.0
@export_range(-40,0) var volume_db: float = -18.0
