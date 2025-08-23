extends Area3D

@export var item: String = "10 Rings"
@onready var item_sound = sfx_destroy

# Models
@onready var normal_model: MeshInstance3D = $CollisionShape3D/ModelNormal
@onready var broken_model: MeshInstance3D = $CollisionShape3D/ModelBroken

# Collision & Sound
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var audio_player2: AudioStreamPlayer3D = $AudioPlayer2

@export var sfx_destroy:    AudioStream
@export var sfx_ring:       AudioStream
@export var sfx_barrier:    AudioStream
@export var sfx_extra_life: AudioStream

@export var target_name: String = "Player"



func _ready() -> void:
	# Broken model should be invisible at start
	broken_model.visible = false
	normal_model.visible = true
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	# Only react to the correct body
	if body.name != target_name:
		return
	
	# Only break if the player is spinning and box is not already broken
	if body.SPINNING and normal_model.visible:
		# ==== ITEM SWITCH ====
		match item:
			"10 Rings":
				Global.Rings += 10
				item_sound = sfx_ring
				# TODO: Add rings to player
				pass
			"Barrier":
				item_sound = sfx_barrier
				# TODO: Give shield to player
				pass
			"Extra Life":
				item_sound = sfx_extra_life
				# TODO: Give 1-up to player
				pass
		
		# ==== MONITOR BREAK LOGIC ====
		# Disable collision so player doesn't stick
		collision.disabled = true

		# Toggle models
		normal_model.visible = false
		broken_model.visible = true 	

		# Bounce the player upward
		body.velocity.y = 30.0

		# Play break SFX
		Global.play_sfx(audio_player, sfx_destroy)
		
		if item_sound:
			Global.play_sfx(audio_player2, item_sound)
