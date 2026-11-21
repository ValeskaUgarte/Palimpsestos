extends Resource

# Fractions of the actual clip duration (including weighted frame durations).
# Contact is [start, end); production sheets author these markers in Inspector.
@export var animation: StringName = &"attack_1"
@export var fallback_animation: StringName = &"attack"
@export_range(0.0, 1.0) var swing_at: float = 0.25
@export_range(0.0, 1.0) var contact_start: float = 0.5
@export_range(0.0, 1.0) var contact_end: float = 0.75
@export_range(0.5, 1.5) var playback_speed: float = 1.0
@export var advance_pixels: float = 8.0
@export var hitbox_size: Vector2 = Vector2(88, 100)
@export var hitbox_offset: Vector2 = Vector2(64, -145)
@export var impact_strength: float = 0.7
@export var impact_direction: Vector2 = Vector2(1, -0.12)
@export var swing_cue: StringName = &"attack_swing"
@export var hit_cue: StringName = &"attack_hit"

func clip_duration(frames: SpriteFrames, clip: StringName) -> float:
	var units: float = 0.0
	for frame in frames.get_frame_count(clip):
		units += frames.get_frame_duration(clip, frame)
	return units / maxf(frames.get_animation_speed(clip) * playback_speed, 0.01)

func clip_progress(sprite: AnimatedSprite2D) -> float:
	var units: float = 0.0
	var elapsed: float = 0.0
	for frame in sprite.sprite_frames.get_frame_count(sprite.animation):
		var weight: float = sprite.sprite_frames.get_frame_duration(sprite.animation, frame)
		units += weight
		if frame < sprite.frame:
			elapsed += weight
		elif frame == sprite.frame:
			elapsed += weight * sprite.frame_progress
	return elapsed / maxf(units, 0.01)
