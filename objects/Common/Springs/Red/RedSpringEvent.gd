extends Area3D

# Sound Player
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@export var sfx_spring: AudioStream

@export var SPRING_LAUNCH_SPEED := 120.0  # Adjust this as needed
@export var target_name: String = "Player"


func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if body.name == target_name:
		print("Spring activated for:", body.name)

		# Launch upward by modifying vertical velocity
		body.velocity.y = SPRING_LAUNCH_SPEED
		body.gsp = 0
		body.velocity.x = 0
		body.velocity.z = 0
		body.GROUNDED = false
		body.SPINNING = false
		body.JUMPING = false
		Global.play_sfx(audio_player, sfx_spring)
