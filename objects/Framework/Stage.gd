extends Node3D

# Sound Player
@onready var audio_player: AudioStreamPlayer3D = $StageMusic

@export var Stage_Name : String = "TEST HILL ZONE"
@export var Act_Number : int = 1

@export var Stage_Music : AudioStream
@export var Time_Limit  : bool = false
@export var Time_Limit_Time : float = 300.0

@export var Character : String = "Sonic"

@export var Title_Card : ItemList
@export var Allow_Pause : bool = true
@export var Allow_Restart : bool = true
@export var Allow_Exit : bool = true

@export var BUTTON_START: StringName = &"input_start"
@export var BUTTON_SELECT: StringName = &"input_select"

func _ready() -> void:
	visible = false
	audio_player.volume_db = 50
	Global.play_sfx(audio_player, Stage_Music)
	
func _process(delta: float) -> void:
	if Allow_Pause and Input.is_action_just_pressed(BUTTON_START):
		get_tree().paused = !get_tree().paused   # toggle pause on/off
