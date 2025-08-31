extends Camera3D

@export var player: CharacterBody3D

@export var camera_delay_frames: int = 0
@export var lerp_back_speed: float = 5.0

var _saved_transform: Transform3D
var _delay_active: bool = false
var _returning: bool = false
var _initial_relative_transform: Transform3D


func _process(delta):
	# --- Handle camera delay ---
	if camera_delay_frames > 0:
		if !_delay_active:
			_saved_transform = global_transform
			_delay_active = true
		camera_delay_frames -= 1
		global_transform = _saved_transform
		return
	elif _delay_active:
		_delay_active = false
		_returning = true

	# --- Return smoothly to original relative transform ---
	if _returning:
		var target_transform = player.global_transform * _initial_relative_transform

		# Lerp origin
		var new_origin = _saved_transform.origin.lerp(target_transform.origin, delta * lerp_back_speed)
		# Slerp rotation
		var new_basis = _saved_transform.basis.slerp(target_transform.basis, delta * lerp_back_speed)

		global_transform = Transform3D(new_basis, new_origin)

		# Stop returning when close enough
		if new_origin.distance_to(target_transform.origin) < 0.01:
			_returning = false

		_saved_transform = global_transform
		return

	# --- Regular camera logic here ---
	# For example, adjust FOV and tilt relative to player
	var target_fov = 70.0
	if player.abs_gsp >= 20.0:
		target_fov += player.abs_gsp * 0.3
	fov = lerp(fov, target_fov, delta * 2.5)
