class_name PalimFoleyBank
extends Resource
@export var forest: Array[AudioStream] = []
@export var stone: Array[AudioStream] = []
@export var wood: Array[AudioStream] = []
@export var dirt: Array[AudioStream] = []
@export var grass: Array[AudioStream] = []
@export var wet: Array[AudioStream] = []
@export var interactions: Dictionary[StringName, AudioStream] = {}
func steps(surface: String) -> Array[AudioStream]:
	match surface:
		"forest": return forest
		"stone": return stone
		"wood": return wood
		"dirt": return dirt
		"grass": return grass
		"wet": return wet
	return []
