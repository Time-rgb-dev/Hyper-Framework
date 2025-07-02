extends Node3D

@export var player: CharacterBody3D
@export var tilt_speed := 5.0
@onready var pitch_pivot := $PitchPivot

var last_player_yaw := 0.0
var rotation_change_timer := 0.0

@export var pitch_delay_threshold := 1.0  # seconds
@export var slope_pitch_dampening := 25.0  # Minimum change required to update
@export var slope_max_angle := 0.35       # Max slope angle to tilt to (in radians)


var pitch := 0.0
var smoothed_pitch := 0.0

func _process(delta: float) -> void:
	# --- Input
	var input_y := Input.get_axis("input_cursor_left", "input_cursor_right")
	var input_x := Input.get_axis("input_cursor_down", "input_cursor_up")

	# --- Yaw (TwistPivot - left/right)
	rotate_y(input_y * 0.025)

	# --- Pitch (PitchPivot - up/down)
	pitch -= input_x * 0.025
	pitch = clamp(pitch, deg_to_rad(-45), deg_to_rad(75))  # prevents flipping
	pitch_pivot.rotation.x = pitch

	# --- OPTIONAL: Slope-aware auto-tilt (blended with pitch)
	if player and player.has_node("CollisionShape3D2/DefaultModel"):
		var model = player.get_node("CollisionShape3D2/DefaultModel")
		var player_yaw = model.global_transform.basis.get_euler().y

		# Detect rotation change
		if abs(player_yaw - last_player_yaw) > 0.01:
			rotation_change_timer = 0.0  # Reset timer on change
		else:
			rotation_change_timer += delta

		last_player_yaw = player_yaw

		# Apply pitch tilt only after delay
		if rotation_change_timer > pitch_delay_threshold:
			var forward = -model.global_transform.basis.z.normalized()
			var flat_forward = Vector3(forward.x, 0, forward.z).normalized()

			var slope_angle = forward.angle_to(flat_forward)
			if forward.y < 0:
				slope_angle = -slope_angle

			# Clamp slope angle and apply dampening threshold
			slope_angle = clamp(slope_angle, -slope_max_angle, slope_max_angle)

			if abs(slope_angle - smoothed_pitch) > slope_pitch_dampening:
				smoothed_pitch = lerp(smoothed_pitch, slope_angle, delta * tilt_speed)

			# Optionally blend with manual pitch
			var final_pitch = lerp(pitch, smoothed_pitch, delta * tilt_speed)
			pitch_pivot.rotation.x = final_pitch  # Uncomment to apply
const ROTATION_SPEED = 10.0
const TILT_SPEED = 3.0

func rotate_toward_direction(direction: Vector3, delta: float) -> void:
	var target_yaw = atan2(direction.x, direction.z)
	var current_yaw = rotation.y
	rotation.y = lerp_angle(current_yaw, target_yaw, delta * ROTATION_SPEED)

func tilt_to_normal(normal: Vector3, delta: float) -> void:
	var forward = -transform.basis.z.normalized()

	# Check if on flat ground
	if normal.dot(Vector3.UP) >= 0.999:
		# Smoothly reset tilt to 0
		rotation.x = lerp_angle(rotation.x, 0.0, delta * TILT_SPEED)
		return

	# Determine slope in forward direction
	var slope_forward = normal.normalized().dot(forward)

	# Compute pitch angle — limit to a reasonable range (e.g., 0.35 rad ≈ 20 degrees)
	var max_tilt = deg_to_rad(180)
	var target_pitch = -clamp(slope_forward * max_tilt, -max_tilt, max_tilt)

	target_pitch = -1.5

	smoothed_pitch = lerp_angle(smoothed_pitch, target_pitch, delta * tilt_speed)

# Smoothly apply the tilt
	rotation.x = lerp_angle(rotation.x, -smoothed_pitch, delta * TILT_SPEED)

	if Input.is_action_just_pressed("input_lb"):
		rotation.x = 0
		rotation.y = 0 
		rotation.z = 0
		
