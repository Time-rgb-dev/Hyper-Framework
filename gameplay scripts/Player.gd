extends CharacterBody3D

@onready var anim_player: AnimationPlayer = $CollisionShape3D2/DefaultModel/GeneralSkeleton/AnimationPlayer
@onready var model_default = $CollisionShape3D2/DefaultModel
@onready var spinball_mesh = $CollisionShape3D2/DefaultModel/GeneralSkeleton/SonicFSpin
@onready var model_rotation_base: Node3D = $CollisionShape3D2
@onready var camera = $TwistPivot/PitchPivot/Camera3D
@onready var ground_ray: RayCast3D = $GroundRay
@onready var twist = $TwistPivot
@onready var pitch = $TwistPivot/PitchPivot

# Constants
@export var ACC: float = 0.20895 # 85% Classic Accurate
@export var DEC: float = 0.25
@export var FRC: float = 0.15 # 80% Classic Accurate

@export var SPIN_FRC: float = 0.05

@export var TOPACC: float = 35.0
@export var MAXSPD: float = 200.0

@export var JUMP_VELOCITY: float = 45.0
@export var GRAVITY: float = 75.0
@export var GRAVITY_NORMAL: Vector3 = Vector3.UP

@export var SLOPE_DOWNHILL_BOOST: float = 100.0
@export var SLOPE_UPHILL_SLOW: float    = 50.0
@export var SPIN_SLOPE_BOOST: float     = 350.0
@export var SPIN_SLOPE_SLOW: float      = 125.0

@export var MIN_GSP_UPHILL: float = 0.0

@export var AIR_ACC: float = 22.20895
@export var AIR_CONTROL: float = 5.0

@export var TURN_RESISTANCE_FACTOR: float = 5.0
@export var WALL_THRESHOLD:float = - 0.9

@export var SPINDASH_CHARGE_RATE: float = 50.0
@export var SPINDASH_MAX: float = 75.0
@export var SPINDASH_RELEASE_MULT = 1
@export var SPINDASH_SLOWDOWN_THRESHOLD: float = 1.5

@export var ROLLTYPE = 1

@export var BUTTON_ROLL: StringName = &"input_rt"
@export var BUTTON_JUMP: StringName = &"input_a"
@export var BUTTON_LEFT: StringName = "input_left"
@export var BUTTON_RIGHT: StringName = "input_right"
@export var BUTTON_UP: StringName = "input_forward"
@export var BUTTON_DOWN: StringName = "input_back"

# State
var gsp: float = 0.0
var abs_gsp: float = 0.0
var move_dir = Vector3.ZERO
var last_input_dir = Vector3.ZERO
var GROUNDED: bool = true

var SPINNING: bool = false
var CROUCHING: bool = false
var JUMPING: bool  = false
var DROPDASHING: bool = false
var SPINDASHING: bool = false
var SKIDDING: bool = false

var spindash_charge: float = 0.0
var roll_toggle_lock: bool = false

var prev_spinning: bool = false

var accel_speed: float = 0.0
var slope_speed: float = 0.0

var slope_normal: Vector3 = Vector3.UP

var camera_smoothed_pitch: float

static func rotate_toward_direction(object: Node3D, direction: Vector3, delta: float, rotation_speed: float) -> void:
	var target_yaw: float = atan2(direction.x, direction.z)
	var current_yaw: float = object.rotation.y
	object.rotation.y = lerp_angle(current_yaw, target_yaw, delta * rotation_speed)

func tilt_to_normal(object:Node3D, delta: float, tilt_speed: float, max_angle: float, pitch_mult: float) -> void:
	var forward: Vector3 = -object.transform.basis.z.normalized()

	# Check if on flat ground
	if get_floor_normal().dot(GRAVITY_NORMAL) >= 0.999:
		# Smoothly reset tilt to 0
		object.rotation.x = lerp_angle(object.rotation.x, 0.0, delta * tilt_speed)
		return

	# Determine slope in forward direction
	var slope_forward: float = get_floor_normal().normalized().dot(forward)

	# Compute pitch angle — limit to a reasonable range (e.g., 0.35 rad ≈ 20 degrees)
	var max_tilt: float = deg_to_rad(max_angle)
	var target_pitch: float = clampf(slope_forward * max_tilt, -max_tilt, max_tilt)
	
	target_pitch *= pitch_mult
	
	if object == twist: #TwistPivot variant code. TODO: Make this less hacky
		camera_smoothed_pitch = lerp_angle(camera_smoothed_pitch, target_pitch, delta * tilt_speed)
		target_pitch = -camera_smoothed_pitch
	
	# Smoothly apply the tilt
	object.rotation.x = lerp_angle(object.rotation.x, -target_pitch, delta * tilt_speed)

func update_ground_info() -> void:
	if ground_ray.is_colliding():
		GROUNDED = true
		slope_normal = ground_ray.get_collision_normal()
	else:
		GROUNDED = false
		slope_normal = GRAVITY_NORMAL
		
		# Align the raycast rotation with the model
		var forward: Vector3 = -model_default.transform.basis.z.normalized()
		ground_ray.look_at(ground_ray.global_transform.origin - forward)

func _physics_process(delta: float) -> void:
	#update_ground_info()
	
	# Calculate rotation that aligns body "down" with floor normal
	var axis: Vector3 = GRAVITY_NORMAL.cross(slope_normal).normalized()
	
	if not axis.is_zero_approx():
		var quat_rotate: Quaternion = Quaternion(axis, acos(slope_normal.dot(GRAVITY_NORMAL)))
		model_rotation_base.rotation = quat_rotate.get_euler()
	else:
		# Floor normal and up vector are the same (flat ground)
		model_rotation_base.rotation = Vector3.ZERO
	
	# Input
	var input: Vector2 = Input.get_vector(BUTTON_LEFT, BUTTON_RIGHT, BUTTON_DOWN, BUTTON_UP)
	
	var cam_basis: Basis = camera.global_transform.basis
	var cam_forward: Vector3 = -cam_basis.z.normalized()
	var cam_right: Vector3 = cam_basis.x.normalized()
	
	var input_dir: Vector3 = Vector3(cam_forward * input.y + cam_right * input.x).normalized()
	var has_input: bool = not input_dir.is_zero_approx() if not input.is_zero_approx() else false
	
	# Predict intended direction if no new move_dir yet
	if has_input and move_dir.is_zero_approx():
		move_dir = input_dir
	
	var move_dot: float = move_dir.normalized().dot(input_dir)
	var vel_move_dot: float = input_dir.dot(velocity.normalized())
	
	if GROUNDED:
		#STEP 1: Check for crouching, balancing, etc.
		CROUCHING = Input.is_action_pressed(BUTTON_ROLL) and abs_gsp <= 5.0
		
		var can_move:bool = not (SPINDASHING or CROUCHING)
		
		#STEP 2: Check for starting a spindash
		if CROUCHING and Input.is_action_pressed(BUTTON_JUMP):
			if not SPINDASHING:
				SPINNING = true
				SPINDASHING = true
				spindash_charge = gsp * 0.55
			
			if has_input:
				rotate_toward_direction(model_default, last_input_dir, delta * 3, 10.0)
			
			if abs_gsp > SPINDASH_SLOWDOWN_THRESHOLD:
				var stop_friction: float = 1.0 * abs_gsp / 10.0
				accel_speed = move_toward(accel_speed, 0.0, stop_friction)
				slope_speed = move_toward(slope_speed, 0.0, stop_friction)
			else:
				spindash_charge = clampf(spindash_charge + SPINDASH_CHARGE_RATE * delta, 0, SPINDASH_MAX)
		elif SPINDASHING:
			var dash_dir: Vector3 = input_dir if has_input else last_input_dir
			if not dash_dir.is_zero_approx():
				move_dir = dash_dir
				slope_speed = spindash_charge * SPINDASH_RELEASE_MULT
				SPINNING = true
				CROUCHING = false
			else:
				# Fallback if no input direction
				slope_speed = spindash_charge * SPINDASH_RELEASE_MULT
				SPINNING = true
			SPINDASHING = false
			spindash_charge = 0.0
			SPINNING = true
		
		#STEP 3: Slope factors
		if not SPINDASHING:
			# Get slope tilt from model forward tilt
			var forward_vec: Vector3 = -model_default.transform.basis.z.normalized()
			var slope_strength: float = forward_vec.y
			
			if absf(slope_strength) < 0.01:
				slope_strength = 0.0
			
			if SPINNING:
				if slope_strength < 0: # Downhill
					slope_speed += absf(slope_strength) * SPIN_SLOPE_BOOST * delta
				elif slope_strength > 0: # Uphill
					slope_speed -= slope_strength * SPIN_SLOPE_SLOW * delta
					# Removed MIN_GSP_UPHILL clamp here
			else:
				if slope_strength < 0: # Downhill
					slope_speed += absf(slope_strength) * SLOPE_DOWNHILL_BOOST * delta
				elif slope_strength > 0: # Uphill
					slope_speed -= slope_strength * SLOPE_UPHILL_SLOW * delta
					# Removed MIN_GSP_UPHILL clamp here
			
			# Clamp slope speed
			slope_speed = clampf(slope_speed, -MAXSPD, MAXSPD)
		
		#STEP 4: Check for starting a jump
		if Input.is_action_just_pressed(BUTTON_JUMP) and can_move:
			SPINNING = true
			JUMPING  = true
			SKIDDING = false
		
		#STEP 5: Direction input factors, friction/deceleration
		
		var current_friction: float = SPIN_FRC if SPINNING else FRC
		
		# Detect skidding
		if not SPINNING and not CROUCHING and has_input:
			if move_dir != Vector3.ZERO:
				if vel_move_dot <= -0.16 and abs_gsp > 15:
					SKIDDING = true
				elif vel_move_dot > 0.25:
					SKIDDING = false
		
		if SKIDDING:
			# Stop skidding if speed is very low
			if abs_gsp < 1.0:
				SKIDDING = false
			else:
				# Apply extra friction while skidding
				var stop_friction: float = abs_gsp / 15.0 * 0.7
				accel_speed = move_toward(accel_speed, 0.0, stop_friction)
				slope_speed = move_toward(slope_speed, 0.0, stop_friction)
		
		elif can_move: 
			if has_input:
				# Rotate toward new input direction
				var turn_speed: float = clampf(1.0 - (abs_gsp / MAXSPD) * TURN_RESISTANCE_FACTOR, 0.05, 1.0)
				
				move_dir = move_dir.slerp(input_dir, turn_speed).normalized()
				#recompute this
				move_dot = move_dir.normalized().dot(input_dir)
				
				# Accelerate
				if not SPINNING and not CROUCHING and not SKIDDING:
					if move_dot > 0:
						accel_speed = minf(accel_speed + ACC, TOPACC)
					elif move_dot < 0:
						accel_speed = maxf(accel_speed - DEC, -TOPACC)
			else:
				# Apply friction when no input
				accel_speed = move_toward(accel_speed, 0.0, current_friction)
				slope_speed = move_toward(slope_speed, 0.0, current_friction)
		
		#Rolling friction
		if SPINNING:
			if has_input:
				accel_speed = move_toward(accel_speed, 0.0, current_friction)
				slope_speed = move_toward(slope_speed, 0.0, current_friction)
		
		#STEP 6: Check crouching, balancing, etc.
		
		#STEP 7: Push/wall sensors
		
		if is_on_wall():
			var forward: Vector3 = -model_default.global_transform.basis.z.normalized()
			var wall_normal: Vector3 = get_wall_normal()
			var wall_dot: float = forward.dot(wall_normal)
			
			if wall_dot < WALL_THRESHOLD:  # Almost head-on into wall
				gsp = 0.0
				abs_gsp = 0.0
				accel_speed = 0.0
				slope_speed = 0.0
		
		#STEP 8: Check for doing a roll
		
		if not SPINDASHING:
			if ROLLTYPE == 0:
				if Input.is_action_just_pressed(BUTTON_ROLL) and abs_gsp > 5.0:
					SPINNING = true
				elif abs_gsp < 1.0:
					SPINNING = false
			elif ROLLTYPE == 1:
				if Input.is_action_pressed(BUTTON_ROLL) and abs_gsp > 5.0:
					SPINNING = true
				elif not JUMPING:
					SPINNING = false
		
		if SPINNING and not SPINDASHING and abs_gsp < 1.0 and not JUMPING:
			SPINNING = false
		
		#STEP 9: Handle camera bounds (not gonna worry about that)
		
		#STEP 10: Move the player (apply gsp to velocity)
		
		gsp = clampf(accel_speed + slope_speed, -MAXSPD, MAXSPD)
		abs_gsp = absf(gsp)
		
		if not SPINDASHING:
			var move_vector: Vector3 = move_dir
			move_vector *= gsp
			velocity.x = move_vector.x
			velocity.z = move_vector.z
		
		if JUMPING:
			var slope_strength: float = clampf(move_dir.dot(-slope_normal), -1.0, 1.0)
			
			# Reduce horizontal speed when jumping uphill steeply
			var forward_speed_loss: float = slope_strength * 0.3 * gsp
			accel_speed = clampf(accel_speed - forward_speed_loss, -MAXSPD, MAXSPD)
			slope_speed = clampf(slope_speed - forward_speed_loss, -MAXSPD, MAXSPD)
			
			velocity += slope_normal.normalized() * JUMP_VELOCITY
		
		move_and_slide()
		
		#STEP 11: Check ground angles
		
		ground_ray.target_position = -up_direction * floor_snap_length
		
		if JUMPING:
			GROUNDED = false
		else:
			GROUNDED = ground_ray.is_colliding()
		
		if GROUNDED:
			apply_floor_snap()
			slope_normal = ground_ray.get_collision_normal()
		
		#STEP 12: Check slipping/falling
		
		var threshold: float = 0.5  # tweak as needed
		
		# If on a steep slope (close to wall) and vertical speed along slope is low, detach
		if slope_normal.dot(GRAVITY_NORMAL) < 0 and abs_gsp < threshold:
			GROUNDED = false
			up_direction = GRAVITY_NORMAL
		else:
			up_direction = slope_normal
			# Optionally reset or reduce speed when detaching
			# velocity.y = 0
	
	else: #not GROUNDED
		#STEP 1: check for jump button release
		if JUMPING and not Input.is_action_pressed(BUTTON_JUMP):
			if velocity.y > 0:
				velocity.y *= 0.5  # You can tweak this (e.g. 0.4–0.6)
			JUMPING = false  # Prevent multiple reductions
		
		#STEP 2: Super Sonic checks (not gonna worry about that)
		
		#STEP 3: Directional input
		
		var current_h_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
		var current_speed: float = current_h_velocity.length()
		var current_h_dir: Vector3 = current_h_velocity.normalized() if current_speed > 0.01 else Vector3.ZERO
		
		if has_input:
			if current_h_dir.dot(input_dir) > 0:
				# Accelerate in air toward input direction
				var target_speed: float = clampf(current_speed + AIR_ACC * delta, 0, MAXSPD)
				var desired_velocity: Vector3 = input_dir * target_speed
				
				# Smoothly adjust velocity toward desired velocity
				velocity.x = lerpf(velocity.x, desired_velocity.x, AIR_CONTROL * delta)
				velocity.z = lerpf(velocity.z, desired_velocity.z, AIR_CONTROL * delta)
			else:
				# Opposite or perpendicular input — slow down gently, allow slight steering
				var target_speed: float = maxf(current_speed - AIR_ACC * 0.5 * delta, 0)
				
				# Blend slightly toward input direction to allow some control
				var blended_dir: Vector3 = current_h_dir.slerp(input_dir, 0.1) # small influence
				
				var desired_velocity: Vector3 = blended_dir * target_speed
				
				velocity.x = lerpf(velocity.x, desired_velocity.x, AIR_CONTROL * delta)
				velocity.z = lerpf(velocity.z, desired_velocity.z, AIR_CONTROL * delta)
		else:
			# No input, maintain current horizontal velocity (or decay slightly if desired)
			velocity.x = lerpf(velocity.x, current_h_velocity.x, AIR_CONTROL * 0.1 * delta)
			velocity.z = lerpf(velocity.z, current_h_velocity.z, AIR_CONTROL * 0.1 * delta)
		
		#STEP 4: Air drag
		
		# Airborne or spindash - let slope speed decay
		#slope_speed = move_toward(slope_speed, 0, DEC * delta)
		
		#STEP 5: Move the player
		move_and_slide()
		
		#STEP 6: Apply gravity
		velocity += -GRAVITY_NORMAL * GRAVITY * delta
		
		#STEP 7: Check underwater for reduced gravity (not gonna worry about that)
		
		#STEP 8: Reset ground angle
		slope_normal = GRAVITY_NORMAL
		
		#STEP 9: Collision checks
		ground_ray.target_position = -GRAVITY_NORMAL * floor_snap_length
		
		if ground_ray.is_colliding() and get_slide_collision_count() > 0:
			GROUNDED = true
			slope_normal = ground_ray.get_collision_normal()
	
	if has_input:
		last_input_dir = input_dir
	
	# --- Model rotation and tilt ---
	if move_dir != Vector3.ZERO:
		if not SKIDDING:
			rotate_toward_direction(model_default, move_dir, delta, 10.0)
			if GROUNDED:
				tilt_to_normal(twist, delta, 3.0, 180.0, -1.5)
				
				if Input.is_action_just_pressed("input_lb"):
					twist.rotation = Vector3.ZERO
				
				tilt_to_normal(model_default, delta, 6.0, 20.0, -2.5)
		else:
			tilt_to_normal(model_default, delta, 6.0, 20.0, -2.5)

	spinball_mesh.visible = SPINNING and not DROPDASHING

	# --- Detect Spin State Transitions ---
	if GROUNDED:
		if SPINNING and not prev_spinning and not JUMPING:
			anim_player.play("SonicMain/AnimRollEnd")
		elif not SPINNING and prev_spinning and Input.is_action_pressed(BUTTON_ROLL):
			anim_player.play("SonicMain/AnimRollStart")
	
	prev_spinning = SPINNING
	
	if not anim_player.is_playing() or (
		anim_player.current_animation != "SonicMain/AnimRollStart"
		and anim_player.current_animation != "SonicMain/AnimRollEnd"
	):
		if SKIDDING:
			anim_player.play("SonicMain/AnimSkid1")
			anim_player.speed_scale = 1.0  # Default run speed
		elif not GROUNDED:
			if SPINNING:
				anim_player.play("SonicMain/AnimSpin")
				anim_player.speed_scale = 1.0  # Default run speed
			else:
				if velocity.y > 3.0:
					anim_player.play("SonicMain/AnimAirUp")
					anim_player.speed_scale = 1.0  # Default run speed
				elif velocity.y < -4.0:
					anim_player.play("SonicMain/AnimAirDown")
					anim_player.speed_scale = 1.0  # Default run speed
				else:
					anim_player.play("SonicMain/AnimAirMid")
					anim_player.speed_scale = 1.0  # Default run speed
		elif CROUCHING:
			if not SPINDASHING:
				anim_player.play("SonicMain/AnimCrouch")
				anim_player.speed_scale = 1.0  # Default run speed
			else:
				anim_player.play("SonicMain/AnimSpin")
				anim_player.speed_scale = 1.0  # Default run speed
		elif SPINNING:
			anim_player.play("SonicMain/AnimSpin")
			anim_player.speed_scale = 1.0  # Default run speed
		elif abs_gsp > 65:
			anim_player.play("SonicMain/AnimPeelout")
			var peelout_speed_scale = lerpf(0.5, 2.0, clampf(abs_gsp / 120.0, 0.0, 1.0))
			anim_player.speed_scale = peelout_speed_scale
		elif abs_gsp > 25:
			anim_player.play("SonicMain/AnimRun")
		# Scale between 0.1 (slow) and 1.0 (fast) as speed increases
			var run_speed_scale = lerpf(0.0, 2.0, clampf(abs_gsp / 65.0, 0.0, 1.0))
			anim_player.speed_scale = run_speed_scale
		elif abs_gsp > 1:
			anim_player.play("SonicMain/AnimJog")

			# Scale between 0.1 (slow) and 1.0 (fast) as speed increases
			anim_player.speed_scale = 1.0  # Default run speed
			var walk_speed_scale: float = lerpf(0.05, 1.0, clampf(abs_gsp / 15.0, 0.0, 1.0))
			anim_player.speed_scale = walk_speed_scale
		else:
			anim_player.play("SonicMain/AnimIdle")
			anim_player.speed_scale = 1.0
