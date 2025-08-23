extends MeshInstance3D
@export var player : CharacterBody3D
@export var spin_speed = 125.0


func _ready():
	visible = false

func _process(delta):
	rotation.y += deg_to_rad(spin_speed) * delta

func _physics_process(delta):
	
	if player.BARRIER and !player.IFRAMES:
		visible = true
	else:
		visible = false
