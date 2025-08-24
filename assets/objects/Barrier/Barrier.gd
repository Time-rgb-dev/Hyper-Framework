extends MeshInstance3D

const barrier_material_index: int = 4

@export var player : CharacterBody3D
@export var spin_speed = 125.0

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
				set_surface_override_material(barrier_material_index, barrier_material)
			"Water":
				set_surface_override_material(barrier_material_index, water_barrier_material)
			"Thunder":
				set_surface_override_material(barrier_material_index, thunder_barrier_material)
			"Fire":
				set_surface_override_material(barrier_material_index, fire_barrier_material)
		
		visible = true
	else:
		visible = false
