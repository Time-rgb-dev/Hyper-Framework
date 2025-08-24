extends Area3D

# Sound Player
@onready var audio_player: AudioStreamPlayer3D = $StaticBody3D/AudioPlayer
@export var sfx_spring: AudioStream

@export var target_name: String = "Player"

func _ready():
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node):
	if body.name == target_name:
		print("Spike Activated for:", body.name)

		# Launch upward by modifying vertical velocity
		body.player_damage(false,false,true,false)
		Global.play_sfx(audio_player, sfx_spring)
