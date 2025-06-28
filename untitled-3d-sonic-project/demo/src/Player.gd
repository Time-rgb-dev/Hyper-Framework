extends CharacterBody3D

@onready var model_default = $DefaultModel
@onready var model_spin = $SpinModel
@onready var camera = $TwistPivot/PitchPivot/Camera3D

# Constants
const ACC = 0.29875
const DEC = 5
const FRC = 0.46875
const SPIN_FRC = 0.1
const TOPACC = 22.0
const MAXSPD = 50.0
const JUMP_VELOCITY = 23.5
const GRAVITY = Vector3.DOWN * 35.8

# Slope
const SLOPE_DOWNHILL_BOOST = 60.0
const SLOPE_UPHILL_SLOW = 75.0
const SPIN_SLOPE_BOOST = 120.0
const SPIN_SLOPE_SLOW = 90.0
const MIN_GSP_UPHILL = 0.0

# Turn
const TURN_RESISTANCE_FACTOR = 1.0
const TURN_LOSS_MULTIPLIER = 0.5

# Spindash
const SPINDASH_CHARGE_RATE = 60.0
const SPINDASH_MAX = 480.0
const SPINDASH_RELEASE_MULT = 0.1

# Variables
var gsp = 0.0
var move_dir = Vector3.ZERO
var GROUNDED = true
var SPINNING = false
var SPINDASHING = false
var spindash_charge = 0.0

var ring_count = 0

func collect_ring(value: int):
	ring_count += value
	
	
	
	
# Slope-based jump vector
func get_jump_vector(normal: Vector3) -> Vector3:
	return (Vector3.UP + normal * 1.5).normalized()

func _physics_process(delta: float) -> void:
	floor_snap_length = 0.9
	var on_floor = is_on_floor()
	GROUNDED = on_floor

	# Gravity
	if not on_floor:
		velocity += GRAVITY * delta
	else:
		velocity.y = 0

	# Camera input
	var input = Input.get_vector("input_left", "input_right", "input_forward", "input_back")
	var cam_basis = camera.global_transform.basis
	var cam_forward = -cam_basis.z.normalized()
	var cam_right = cam_basis.x.normalized()
	var direction = (cam_forward * -input.y + cam_right * input.x).normalized()

	# Floor/slope data
	var slope_normal = get_floor_normal() if on_floor else Vector3.UP
	var slope_angle = acos(slope_normal.dot(Vector3.UP))

	# Jump
	if on_floor and Input.is_action_just_pressed("input_a") and not SPINDASHING:
		var jump_dir = get_jump_vector(slope_normal)
		velocity = jump_dir * JUMP_VELOCITY
		SPINNING = false

	# Spindash charging
	if on_floor and Input.is_action_pressed("input_b") and abs(gsp) < 0.2 and direction == Vector3.ZERO:
		SPINDASHING = true
		spindash_charge = clamp(spindash_charge + SPINDASH_CHARGE_RATE * delta, 0, SPINDASH_MAX)
	else:
		# Releasing the spindash
		if SPINDASHING and Input.is_action_just_released("input_b"):
			gsp = spindash_charge * SPINDASH_RELEASE_MULT
			move_dir = transform.basis.z.normalized() * -1.0
			SPINNING = true
			SPINDASHING = false
			spindash_charge = 0.0

	# Start roll if moving and tapping B
	if on_floor and Input.is_action_just_pressed("input_b") and abs(gsp) > 1.0:
		SPINNING = true

	# Stop rolling if slow or button not held (not while spindashing)
	if SPINNING and not SPINDASHING:
		if abs(gsp) < 0.5 or not Input.is_action_pressed("input_b"):
			SPINNING = false

	# Movement
	if on_floor:
		if direction != Vector3.ZERO and not SPINDASHING:
			var turn_speed = clamp(1.0 - (abs(gsp) / MAXSPD) * TURN_RESISTANCE_FACTOR, 0.05, 1.0)
			if move_dir == Vector3.ZERO:
				move_dir = direction
			move_dir = move_dir.slerp(direction, turn_speed)

			var dot = move_dir.dot(direction)
			if dot < 0.95:
				var turn_amount = 1.0 - dot
				gsp -= turn_amount * TURN_LOSS_MULTIPLIER
				gsp = max(gsp, 0)

			if dot > 0:
				gsp += ACC
				gsp = min(gsp, TOPACC)
			elif dot < 0:
				gsp -= DEC
				gsp = max(gsp, -TOPACC)
		else:
			var current_friction = SPIN_FRC if SPINNING else FRC
			if gsp > 0:
				gsp = max(gsp - current_friction, 0)
			elif gsp < 0:
				gsp = min(gsp + current_friction, 0)

		# Slope
		var slope_effect = slope_angle / (PI / 2)
		var slope_dir = (Vector3.DOWN - slope_normal).normalized()
		var slope_dot = move_dir.dot(slope_dir)

		var slope_boost = SPIN_SLOPE_BOOST if SPINNING else SLOPE_DOWNHILL_BOOST
		var slope_slow = SPIN_SLOPE_SLOW if SPINNING else SLOPE_UPHILL_SLOW

		if slope_dot < 0:
			gsp += slope_effect * slope_boost * delta
		elif slope_dot > 0:
			gsp -= slope_effect * slope_slow * delta
			gsp = max(gsp, MIN_GSP_UPHILL)

	# Clamp final speed
	gsp = clamp(gsp, -MAXSPD, MAXSPD)

	# Apply horizontal movement
	var move_vector = move_dir * gsp
	velocity.x = move_vector.x
	velocity.z = move_vector.z

	# Air control
	if not on_floor and direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * gsp, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * gsp, delta * 3.0)

	# Ground snap
	var snap_vector = Vector3.ZERO
	if GROUNDED and not SPINNING and velocity.y <= 0:
		snap_vector = Vector3.DOWN * 0.5

	move_and_slide()

	# Rotate model
	if move_dir != Vector3.ZERO:
		model_default.call("rotate_toward_direction", move_dir, delta)

	# Slope tilt
	if on_floor:
		var up = slope_normal
		var forward = move_dir
		var right = forward.cross(up).normalized()
		forward = up.cross(right).normalized()
		var target_rotation = Quaternion(Vector3.UP, slope_normal)

	# Model switch
	model_default.visible = not SPINNING
	model_spin.visible = SPINNING
