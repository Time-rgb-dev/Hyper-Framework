extends MeshInstance3D

const barrier_material_index: int = 0

@export var player : CharacterBody3D
@export var spin_speed = 125.0

var ShieldMaterial = 0
@export var barrier_material : Material
@export var water_barrier_material : Material 
@export var thunder_barrier_material : Material 
@export var fire_barrier_material : Material 

func _ready():
	visible = false

func _process(delta):
	rotation.y += deg_to_rad(spin_speed) * delta

func _physics_process(delta):
	
	if player.BARRIER and !player.IFRAMES:
		match player.BARRIER_TYPE:
			"Normal":
				ShieldMaterial = barrier_material
			"Water":
				ShieldMaterial = water_barrier_material
			"Thunder":
				ShieldMaterial = thunder_barrier_material
			"Fire":
				ShieldMaterial = fire_barrier_material
		material_override = ShieldMaterial
		visible = true
	else:
		visible = false
