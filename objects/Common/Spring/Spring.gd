@tool
extends Area3D

class_name Spring

const spring_material_index: int = 2

const data_table: Dictionary = {
	&"Red": {
		&"Color": Color.RED,
		&"Launch": 120.0
	},
	&"Yellow": {
		&"Color": Color.YELLOW,
		&"Launch": 85.0
	},
	&"Blue": {
		&"Color": Color.BLUE,
		&"Launch": 65.0
	}
}

const map := [&"Custom", &"Red", &"Yellow", &"Blue"]

enum Type {
	CUSTOM,
	RED,
	YELLOW,
	BLUE
};

# Sound Player
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

@export var spring_type:Type:
	set(new_type):
		spring_type = new_type
		setup()

@export var target_name: StringName = &"Player"

@export_group("Type Overrides", "custom_")
@export var custom_launch_speed:float = 80.0
@export var custom_spring_color:Color = Color.BLUE:
	set(new_color):
		custom_spring_color = new_color
		setup()
@export var CarryMomentum: bool = false

var launch_speed:float
var dummy:Node3D

func setup() -> void:
	var mesh:MeshInstance3D = $MeshInstance3D
	var spring_mat := StandardMaterial3D.new()
	
	if spring_type == Type.CUSTOM:
		launch_speed = custom_launch_speed
		spring_mat.albedo_color = custom_spring_color
	else:
		launch_speed = data_table[ map[spring_type] ] [&"Launch"]
		spring_mat.albedo_color = data_table[ map[spring_type] ] [&"Color"]
	
	mesh.set_surface_override_material(spring_material_index, spring_mat)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	dummy = Node3D.new()
	add_child(dummy)
	
	dummy.position.y = 1.0

func _on_body_entered(body: Node) -> void:
	if body.name == target_name:
		# Launch upward by modifying vertical velocity
		body.velocity.y = launch_speed
		if not CarryMomentum:
			body.gsp = 0.0
		body.velocity.x = 0
		body.velocity.z = 0
		body.GROUNDED = false
		body.SPINLOCK = false
		body.SPINNING = false
		body.JUMPING = false
		audio_player.play()
		
		print("Spring \"", name, "\" activated for \"", body.name, "\"")
