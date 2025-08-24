extends Node

@onready var Score = 0
@onready var Rings = 0
@onready var Lives = 3

@onready var CHECKPOINT_DATA = 0

@onready var TIME_ENABLED = true
@onready var TIME = 0

@export var BUTTON_START: StringName = &"input_start"
@export var BUTTON_SELECT: StringName = &"input_select"

# Audio Play function
func play_sfx(sfx_player: AudioStreamPlayer3D, sfx: AudioStream, pitch: float = 1) -> void:
	if sfx:
		sfx_player.stream = sfx
		sfx_player.pitch_scale = pitch
		sfx_player.play()
		sfx_player.pitch_scale = 1

# Pause function
	if Input.is_action_just_pressed(BUTTON_START):
		if process_mode:
			set_process(false)
		else:
			set_process(true)
	
