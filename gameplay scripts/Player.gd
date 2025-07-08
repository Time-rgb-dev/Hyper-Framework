extends CharacterBody3D

@onready var anim_player: AnimationPlayer = $CollisionShape3D2/DefaultModel/GeneralSkeleton/AnimationPlayer
@onready var model_default = $CollisionShape3D2/DefaultModel
@onready var spinball_mesh = $CollisionShape3D2/DefaultModel/GeneralSkeleton/SonicFSpin
@onready var model_rotation_base: Node3D = $CollisionShape3D2
@onready var camera:Camera3D = $Camera3D
@onready var ground_ray: RayCast3D = $GroundRay
@onready var debug_label: Label = $"CanvasLayer/Label"

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
@export var SPIN_SLOPE_BOOST: float     = 200.0
@export var SPIN_SLOPE_SLOW: float      = 100.0

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
var gsp: float = 0.0:
	set(new_gsp):
		gsp = new_gsp
		abs_gsp = absf(gsp)
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

var slope_normal: Vector3 = Vector3.UP

var camera_smoothed_pitch: float

static func rotate_toward_direction(object: Node3D, direction: Vector3, delta: float, rotation_speed: float) -> void:
	var target_yaw: float = atan2(direction.x, direction.z)
	var current_yaw: float = object.rotation.y
	object.rotation.y = lerp_angle(current_yaw, target_yaw, delta * rotation_speed)

func tilt_to_normal(object:Node3D, delta: float, tilt_speed: float, max_angle: float, pitch_mult: float) -> void:
	var forward: Vector3 = -object.transform.basis.z.normalized()

	# Check if on flat ground
	if slope_normal.dot(GRAVITY_NORMAL) >= 0.999:
		# Smoothly reset tilt to 0
		object.rotation.x = lerp_angle(object.rotation.x, 0.0, delta * tilt_speed)
		return

	# Determine slope in forward direction
	var slope_forward: float = slope_normal.dot(forward)

	# Compute pitch angle — limit to a reasonable range (e.g., 0.35 rad ≈ 20 degrees)
	var max_tilt: float = deg_to_rad(max_angle)
	var target_pitch: float = clampf(slope_forward * max_tilt, -max_tilt, max_tilt)
	
	target_pitch *= pitch_mult
	
	if object == camera: #TwistPivot variant code. TODO: Make this less hacky
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

func add_debug_info(info:String) -> void:
	debug_label.text += info + "\n"

func _physics_process(delta: float) -> void:
	debug_label.text = ""
	
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
	
	var cam_basis: Basis = camera.global_basis
	var cam_forward: Vector3 = -cam_basis.z.normalized()
	var cam_right: Vector3 = cam_basis.x.normalized()
	var cam_up: Vector3 = cam_basis.y.normalized()
	
	var cam_input_dir: Vector3 = Vector3(cam_forward * input.y + cam_right * input.x).normalized()
	var has_input: bool = not cam_input_dir.is_zero_approx() if not input.is_zero_approx() else false
	
	add_debug_info("Input: " + str(input))
	add_debug_info("Camera-localized Input: " + str(cam_input_dir))
	
	var player_forward: Vector3 = -model_rotation_base.global_basis.z.normalized()
	var player_right: Vector3 = model_rotation_base.global_basis.x.normalized()
	var player_input_dir: Vector3 = Vector3(player_forward * input.y + player_right * input.x).normalized()
	add_debug_info("Player-localized Input: " + str(player_input_dir))
	
	# Predict intended direction if no new move_dir yet
	if has_input and move_dir.is_zero_approx():
		#move_dir = cam_input_dir
		move_dir = player_input_dir
	
	#This is used for measuring the change between the 
	var cam_move_dot: float = move_dir.dot(cam_input_dir)
	var movement_dot:float
	var vel_move_dot: float = cam_input_dir.dot(velocity.normalized())
	
	add_debug_info("Cam move dot: " + str(cam_move_dot))
	
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
				gsp = move_toward(gsp, 0.0, abs_gsp / 10.0)
			else:
				spindash_charge = clampf(spindash_charge + SPINDASH_CHARGE_RATE * delta, 0, SPINDASH_MAX)
			add_debug_info("Spindash Charge: " + str(roundf(spindash_charge)))
		elif SPINDASHING:
			var dash_dir: Vector3 = cam_input_dir if has_input else last_input_dir
			if not dash_dir.is_zero_approx():
				move_dir = dash_dir
				gsp = spindash_charge * SPINDASH_RELEASE_MULT
				SPINNING = true
				CROUCHING = false
			else:
				# Fallback if no input direction
				gsp = spindash_charge * SPINDASH_RELEASE_MULT
				SPINNING = true
			SPINDASHING = false
			spindash_charge = 0.0
			SPINNING = true
		
		#STEP 3: Slope factors
		
		#negative if the ground is a ceiling
		var slope_mag_dot: float = slope_normal.dot(GRAVITY_NORMAL)
		# positive if the slope and movement are in the same direction;
		#ie. if the player is running downhill
		var slope_dir_dot: float = player_input_dir.dot(slope_normal)
		
		add_debug_info("Ground Angle " + str(rad_to_deg(acos(slope_mag_dot))))
		
		if not SPINDASHING:
			# Get slope tilt from model forward tilt
			var forward_vec: Vector3 = -model_default.transform.basis.z.normalized()
			var slope_strength: float = snappedf(forward_vec.y, 0.01)
			
			add_debug_info("Slope strength: " + str(slope_strength))
			add_debug_info("Slope magnitude: " + str(slope_mag_dot))
			add_debug_info("Slope direction: " + str(slope_dir_dot))
			
			#slope factors do NOT apply on ceilings. 
			if slope_mag_dot > -0.5:
				if SPINNING:
					if slope_strength < 0: # Downhill
						add_debug_info("SPINNING DOWNHILL")
						gsp += absf(slope_strength) * SPIN_SLOPE_BOOST * delta
					elif slope_strength > 0: # Uphill
						add_debug_info("SPINNING UPHILL")
						gsp -= slope_strength * SPIN_SLOPE_SLOW * delta
						# Removed MIN_GSP_UPHILL clamp here
				else:
					if slope_strength < 0: # Downhill
						add_debug_info("RUNNING DOWNHILL")
						gsp += absf(slope_strength) * SLOPE_DOWNHILL_BOOST * delta
					elif slope_strength > 0: # Uphill
						add_debug_info("RUNNING UP THAT HILL") #kudos if you pick up the ref :trol:
						gsp -= slope_strength * SLOPE_UPHILL_SLOW * delta
						# Removed MIN_GSP_UPHILL clamp here
			
			# Clamp slope speed
			gsp = clampf(gsp, -MAXSPD, MAXSPD)
		else:
			#WIP: Keep the player from sliding during a spindash
			gsp = 0
		
		
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
				gsp = move_toward(gsp, 0.0, abs_gsp / 15.0 * 0.7)
		
		elif can_move: 
			if has_input:
				# Rotate toward new input direction
				var turn_speed: float = clampf(1.0 - (abs_gsp / MAXSPD) * TURN_RESISTANCE_FACTOR, 0.05, 1.0)
				
				move_dir = move_dir.slerp(cam_input_dir, turn_speed).normalized()
				#recompute this
				cam_move_dot = move_dir.dot(cam_input_dir)
				
				if abs_gsp < TOPACC:
					# Accelerate
					if not SPINNING and not CROUCHING and not SKIDDING:
						if cam_move_dot > 0:
							gsp = minf(gsp + ACC, TOPACC)
						elif cam_move_dot < 0:
							gsp = maxf(gsp - DEC, -TOPACC)
			else:
				# Apply friction when no input
				gsp = move_toward(gsp, 0.0, current_friction)
		
		#Rolling friction
		if SPINNING:
			if has_input:
				gsp = move_toward(gsp, 0.0, current_friction)
		
		#STEP 6: Check crouching, balancing, etc.
		
		#STEP 7: Push/wall sensors
		
		if is_on_wall():
			var forward: Vector3 = -model_default.global_transform.basis.z.normalized()
			var wall_normal: Vector3 = get_wall_normal()
			var wall_dot: float = forward.dot(wall_normal)
			
			if wall_dot < WALL_THRESHOLD:  # Almost head-on into wall
				add_debug_info("WALL COLLISION")
				gsp = 0.0
				abs_gsp = 0.0
		
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
		gsp = clampf(gsp, -MAXSPD, MAXSPD)
		
		add_debug_info("Ground Speed: " + str(gsp))
		
		if not SPINDASHING:
			var move_vector: Vector3 = move_dir
			move_vector *= gsp
			velocity.x = move_vector.x
			velocity.z = move_vector.z
		
		if JUMPING:
			velocity += slope_normal * JUMP_VELOCITY
		
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
		
		var threshold: float = 10.0
		
		slope_mag_dot = slope_normal.dot(GRAVITY_NORMAL)
		
		# If on a steep slope (close to wall) and vertical speed along slope is low, detach
		if abs_gsp < threshold:
			if slope_mag_dot < 0: 
				GROUNDED = false
				up_direction = GRAVITY_NORMAL
				add_debug_info("GROUND UNSTICK")
			else:
				add_debug_info("GROUND NEUTRAL")
		else:
			up_direction = slope_normal
			add_debug_info("GROUND STICK")
			# Optionally reset or reduce speed when detaching
			# velocity.y = 0
	
	else: #not GROUNDED
		#STEP 1: check for jump button release
		if JUMPING and not Input.is_action_pressed(BUTTON_JUMP):
			if velocity.y > 0:
				velocity.y *= 0.5  # You can tweak this (e.g. 0.4–0.6)
			JUMPING = false  # Prevent multiple reductions
		
		add_debug_info("Jumping: " + str(JUMPING))
		
		#STEP 2: Super Sonic checks (not gonna worry about that)
		
		#STEP 3: Directional input
		
		var current_h_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
		var current_speed: float = current_h_velocity.length()
		#var current_h_dir: Vector3 = current_h_velocity.normalized() if current_speed > 0.01 else Vector3.ZERO
		
		if has_input:
			# Smoothly rotate move_dir toward cam_input_dir in the air
			var turn_speed: float = clampf(1.0 - (absf(gsp) / MAXSPD) * TURN_RESISTANCE_FACTOR, 0.05, 1.0) * 0.5
			move_dir = move_dir.slerp(cam_input_dir, turn_speed).normalized()
			
			#recompute this
			cam_move_dot = move_dir.dot(cam_input_dir)
			
			if abs_gsp < TOPACC:
				# Adjust acceleration based on input alignment
				if cam_move_dot > 0:
					gsp = clampf(gsp + AIR_ACC * delta, -TOPACC, TOPACC)
				elif cam_move_dot < 0:
					gsp = clampf(gsp - AIR_ACC * 0.5 * delta, -TOPACC, TOPACC)
		else:
			# No input — slowly reduce gsp
			gsp = move_toward(gsp, 0.0, FRC)
		
		# STEP 3: Apply horizontal air velocity based on gsp and move_dir
		gsp = clampf(gsp, -MAXSPD, MAXSPD)
		
		add_debug_info("Ground Speed: " + str(gsp))
		
		var move_vector: Vector3 = move_dir * gsp
		velocity.x = move_vector.x
		velocity.z = move_vector.z
		#STEP 4: Air drag
		
		# Airborne or spindash - let slope speed decay
		#gsp = move_toward(gsp, 0, DEC * delta)
		
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
			
			#WIP: Apply velocity to ground (slope) speed
			gsp += (1.0 - slope_normal.dot(GRAVITY_NORMAL)) * velocity.length()
	
	if has_input:
		last_input_dir = cam_input_dir
	
	# --- Model rotation and tilt ---
	if move_dir != Vector3.ZERO:
		if not SKIDDING:
			rotate_toward_direction(model_default, move_dir, delta, 10.0)
			
			# Camera
			
			var manual_cam_transform: Transform3D = Transform3D.IDENTITY
			
			var camera_movement: Vector2 = Input.get_vector(
				"input_cursor_left", "input_cursor_right", 
				"input_cursor_down", "input_cursor_up"
			)
			
			var reset_pressed: bool = Input.is_action_just_pressed("input_rb")
			
			if not camera_movement.is_zero_approx():
				#manual camera movement; this overrides the "auto" cam, which is later
				const camera_sensitivity:Vector2 = Vector2(0.1, 0.1)
				
				camera_movement *= camera_sensitivity
				#rotate the camera around the player without actually rotating the parent node in the process
				
				#x transform
				manual_cam_transform = manual_cam_transform.rotated_local(GRAVITY_NORMAL, camera_movement.x)
				#y transform
				manual_cam_transform = manual_cam_transform.rotated_local(cam_right, camera_movement.y)
			else:
				#TODO: "auto" cam that follows the player, gradually moving to be behind the player at 
				#all times
				
				manual_cam_transform = Transform3D.IDENTITY
			
			var ground_cam_transform: Transform3D = Transform3D.IDENTITY
			
			if GROUNDED:
				tilt_to_normal(model_default, delta, 6.0, 20.0, -2.5)
				
				#tilt_to_normal(camera, delta, 3.0, 180.0, -1.5)
				
				var cam_diff: Vector3 = camera.global_rotation - model_rotation_base.global_rotation
				
				add_debug_info("Cam diff " + str(cam_diff))
				
				#ground_cam_transform = ground_cam_transform.rotated_local(cam_forward, cam_diff.z)
				
				
				#camera.rotation.z = model_rotation_base.rotation.z
			else:
				#reset the camera
				ground_cam_transform = ground_cam_transform.rotated_local(cam_forward, camera.global_rotation.z)
				
			
			add_debug_info("Cam transform manual x" + str(manual_cam_transform.basis.x))
			add_debug_info("Cam transform manual y" + str(manual_cam_transform.basis.y))
			add_debug_info("Cam transform manual z" + str(manual_cam_transform.basis.z))
			
			camera.global_transform = global_transform * manual_cam_transform * ground_cam_transform * camera.transform
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
