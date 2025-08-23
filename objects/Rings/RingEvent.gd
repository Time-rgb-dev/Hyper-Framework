extends Area3D

@export var spin_speed = 125.0
@export var ring_value = 1

# Sound Player
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var model : MeshInstance3D = $CollisionShape3D/MeshInstance3D
@onready var collision : CollisionShape3D = $CollisionShape3D
@export var sfx_ring: AudioStream

func _ready():
	connect("body_entered", _on_body_entered)

func _process(delta):
	rotation.y += deg_to_rad(spin_speed) * delta

func _on_body_entered(body):
	Global.play_sfx(audio_player, sfx_ring)
	Global.Rings += ring_value

	# Disable visuals & collision
	if model: model.visible = false
	if collision: collision.disabled = true

	# Wait for sound to finish before freeing
	audio_player.connect("finished", Callable(self, "_on_sfx_finished"))

func _on_sfx_finished():
	queue_free()
