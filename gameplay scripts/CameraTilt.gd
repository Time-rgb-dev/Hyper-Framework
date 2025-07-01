extends Node3D

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
	
	target_pitch *= -2.5
	
	# Smoothly apply the tilt
	rotation.x = lerp_angle(rotation.x, -target_pitch, delta * TILT_SPEED)
