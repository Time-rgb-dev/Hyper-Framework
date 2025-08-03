extends Node3D

@export var target_path: NodePath
@export var min_zoom_distance: float = 4.0
@export var max_zoom_distance: float = 10.0
@export var zoom_speed_factor: float = 0.9
@export var follow_distance: float = 7.0
@export var vertical_offset: float = 4.0
@export var rotation_lerp_speed: float = 8.0
@export var tilt_lerp_speed: float = 6.0
@export var sensitivity: Vector2 = Vector2(0.015, 0.015)

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var pivot: Node3D = $CameraPivot
var target: Node3D
var yaw := 0.0
var pitch: float = 0.0
var current_zoom: float = 1.0

const ROTATION_SPEED = 10.0
const TILT_SPEED = 3.0

func _ready():
	target = get_node_or_null(target_path)
	if not target:
		push_error("CameraTilt: Target node not found")
	camera.position = Vector3(0, vertical_offset, follow_distance)

func _physics_process(delta):
	if not target:
		return
	
	var player = target as CharacterBody3D
	
	# Follow target position
	var follow_target_pos = player.global_transform.origin + player.up_direction * vertical_offset
	global_position = follow_target_pos
	
	# Rotate camera to be behind the move direction or velocity
	#var facing_dir = player.move_dir if player.move_dir.length() > 0.1 else player.velocity.normalized()
	#facing_dir = (Vector3.UP).normalized()

	#if facing_dir.length() > 0.01:
		#var desired_yaw = atan2(facing_dir.x, facing_dir.z)
		#var current_yaw = rotation.y
		#rotation.y = lerp_angle(current_yaw, desired_yaw, delta * rotation_lerp_speed)

	# Zoom based on speed
	var speed = player.abs_gsp
	var zoom = lerp(min_zoom_distance, max_zoom_distance, clamp(speed / player.MAXSPD, 0.0, 1.0))
	current_zoom = lerp(current_zoom, zoom, delta * 5.0)


func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("mouse_rotate"):
		yaw -= event.relative.x * sensitivity.x
		pitch = clamp(pitch - event.relative.y * sensitivity.y, deg_to_rad(-60), deg_to_rad(80))

func _process(delta):
	if not target:
		return

	global_position = target.global_transform.origin

	# Apply rotation to pivot
	pivot.rotation = Vector3(pitch, yaw, 0)

	# Optional: Make camera look at the player (if needed)
	camera.look_at(global_position, Vector3.UP)
