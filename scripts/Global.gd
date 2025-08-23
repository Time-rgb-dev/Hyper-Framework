extends Node

@onready var Score = 0
@onready var Rings = 0
@onready var Lives = 3


@onready var CHECKPOINT_DATA = 0

@onready var TIME_ENABLED = true
@onready var TIME = 0

@export var BUTTON_START: StringName = &"input_start"
@export var BUTTON_SELECT: StringName = &"input_select"


# Stage Time
var start_time:int
var sec_accum:float

func _physics_process(delta: float) -> void:
	if TIME_ENABLED:
		
		sec_accum += delta
		
		if sec_accum >= 1.0: #if a second or so has passed
			var STAGE_TIME:int = int(Time.get_unix_time_from_system())
			sec_accum = 0.0
			
			

	if TIME_ENABLED: 
		var TIME = delta
	else:
		var TIME = 0

# Audio Play function
func play_sfx(sfx_player: AudioStreamPlayer3D, sfx: AudioStream) -> void:
	if sfx:
		sfx_player.stream = sfx
		sfx_player.play()

# Pause function
	if Input.is_action_just_pressed(BUTTON_START):
		if process_mode:
			set_process(false)
		else:
			set_process(true)
	
