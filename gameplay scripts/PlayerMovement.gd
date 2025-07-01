extends CharacterBody3D

@onready var model =  $MeshInstance3D
@onready var camera = $TwistPivot/PitchPivot/Camera3D

# Constants
const ACC = 0.066875
const DEC = 0.5
const START_SPEED = 1.0
const TOPACC = 16.0
const JUMP_VELOCITY = -9

var SPD = 0.0

var GROUNDED = false
var SPINNING = false

func _physics_process(delta: float) -> void:
	var input = Input.get_vector("input_left", "input_right", "input_forward", "input_back")
	var cam_basis = camera.global_transform.basis
	var cam_forward = -cam_basis.z.normalized()
	var cam_right = cam_basis.x.normalized()

	var input_dir = (cam_forward * -input.y + cam_right * input.x)
	var input_magnitude = input_dir.length()
	
	# Normalize input_dir only if input magnitude is not zero to avoid division by zero
	if input_magnitude > 0:
		input_dir = input_dir.normalized()
	
	# Acceleration / Deceleration logic with smoothing
	if input_magnitude > 0:
		# Accelerate toward TOPACC with ACC rate
		SPD = min(SPD + ACC, TOPACC)
	else:
		# Gradually reduce speed by DEC until zero, don't invert speed
		SPD = max(SPD - DEC, 0)

	# Apply movement direction scaled by speed
	var move_vector = input_dir * SPD
	velocity.x = move_vector.x
	velocity.z = move_vector.z

	# Update grounded flag
	var was_grounded = GROUNDED
	GROUNDED = is_on_floor()

	# Gravity
	if not GROUNDED:
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		# Jump on "Input_a" press
		if Input.is_action_just_pressed("input_a"):
			velocity.y = JUMP_VELOCITY
			SPINNING = true  # Enable spinning on jump

	# If player just landed, disable spinning
	if GROUNDED and !was_grounded:
		SPINNING = false

	move_and_slide()

	# Rotate model to face movement direction (not body)
	if input_magnitude > 0:
		model.call("rotate_toward_direction", input_dir, delta)
