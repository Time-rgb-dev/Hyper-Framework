extends CharacterBody3D

@onready var anim_player: AnimationPlayer = $CollisionShape3D2/DefaultModel/GeneralSkeleton/AnimationPlayer
##The player's model. This is a child of [member model_rotation_base], so it only has to rotate on its local y 
##axis to face the direction the player is giving input to.
@onready var model_default = $CollisionShape3D2/DefaultModel
@onready var spinball_mesh = $CollisionShape3D2/DefaultModel/GeneralSkeleton/SonicFSpin
##The base for the player's rotation. This will be rotated to align to slopes.
@onready var model_rotation_base: Node3D = $CollisionShape3D2
@onready var camera:Node3D = $CameraRig
@onready var ground_ray: RayCast3D = $GroundRay
@onready var debug_label: Label = $"CanvasLayer/Label"

# Sound Player
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
# Sounds
@export var sfx_jump: AudioStream
@export var sfx_roll: AudioStream
@export var sfx_charge: AudioStream
@export var sfx_release: AudioStream
@export var sfx_skid: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_breathe: AudioStream

# Constants
@export var ACC: float = 0.30895 # 85% Classic Accurate
@export var AIR_ACC: float = 0.35895
@export var DEC: float = 0.50
@export var FRC: float = 0.30 # 80% Classic Accurate
@export var SPIN_FRC: float = 0.15
@export var MAXACC: float = 60.0
@export var MAXSPD: float = 200.0
@export var JUMP_HEIGHT: float = 45.0

## GRAVITY
@export var GRAVITY: float = 85.0
@export var GRAVITY_NORMAL: Vector3 = Vector3.UP ##The normal (up direction) of gravity

## SLOPES
@export var NORMAL_SLOPE_POWER: float = 75.0
@export var ROLL_SLOPE_POWER: float = 150.0

## WALL THRESHOLD
@export var WALL_THRESHOLD:float = - 0.9

## SPINDASH
@export var SPINDASH_CHARGE_RATE: float = 50.0
@export var SPINDASH_MAX: float = 100.0
@export var SPINDASH_RELEASE_MULT = 1
@export var SPINDASH_SLOWDOWN_THRESHOLD: float = 1.5

## GAMEPLAY TOGGLES
@export var ROLLTYPE = 0 # [0 = CLASSIC STYLED / TOGGLE] [1 = GT & RASCAL STYLED / HOLD]
@export var SPINDASHTYPE = 0 # [0 = CROUCH AND PRESS A TO REV, RELEASE CROUCH] [1 = HOLD RT AND A TO REV, RELEASE JUMP] [2 = HOLD CROUCH TO REV, RELEASE CROUCH]

## INPUT
@export var BUTTON_ROLL: StringName = &"input_rt"
@export var BUTTON_JUMP: StringName = &"input_a"
@export var BUTTON_LEFT: StringName = &"input_left"
@export var BUTTON_RIGHT: StringName = &"input_right"
@export var BUTTON_UP: StringName = &"input_forward"
@export var BUTTON_DOWN: StringName = &"input_back"

@export var DEBUG_DOWNHILL: StringName = &"input_x"
@export var DEBUG_UPHILL:StringName = "input_y"

@export var SPACE_SCALE: float = 0.01
@export var CAM_SENSITIVITY:Vector2 = Vector2(0.1, 0.1)

var TIME = Global.TIME

# State
var gsp: float = 0.0:
	set(new_gsp):
		gsp = new_gsp
		abs_gsp = absf(gsp)

var abs_gsp: float = 0.0

##The direction the player is moving, on the x and z axes.
var move_dir: Vector3 = Vector3.ZERO
##This is the raw input of the player rotated to align to the POV of the camera. 
##For example, z+ will always be going away from the camera and x+ will always be going right to the camera.
var last_cam_input_dir: Vector3 = Vector3.ZERO
##This is the raw input of the player rotated to align to the POV of the player. 
##For example, z+ will always be forward to the player and x+ will always be right to the player.
var last_player_input_dir: Vector3 = Vector3.ZERO

var GROUNDED: bool = true
var SPINNING: bool = false
var ROLLING:  bool = false
var CROUCHING: bool = false
var JUMPING: bool  = false
var DROPDASHING: bool = false
var SPINDASHING: bool = false
var SKIDDING: bool = false

var SPINLOCK = false
var roll_toggle_lock: bool = false
var prev_spinning: bool = false

var spindash_charge: float = 0.0

var slope_normal: Vector3 = Vector3.UP:
	set(new_normal):
		slope_normal = new_normal
		slope_mag_dot = slope_normal.dot(GRAVITY_NORMAL)
var slope_mag_dot:float

var camera_smoothed_pitch: float
var camera_default_transform: Transform3D

const debug_enabled: bool = true

##Rotate an object towards a specific direction. Used to rotate the player model to face the direction of the player's input
static func rotate_toward_direction(object: Node3D, direction: Vector3, delta: float, rotation_speed: float) -> void:
	var target_yaw: float = atan2(direction.x, direction.z)
	var current_yaw: float = object.rotation.y
	object.rotation.y = lerp_angle(current_yaw, target_yaw, delta * rotation_speed)

func tilt_to_normal(object:Node3D, delta: float, tilt_speed: float, max_angle: float, pitch_mult: float) -> void:
	var forward: Vector3 = -object.basis.z.normalized()

	# Check if on flat ground
	if slope_mag_dot >= 0.999:
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

func add_debug_info(info:String) -> void:
	if debug_enabled:
		debug_label.text += info + "\n"

func readable_vector(input:Vector3) -> String:
	return str(input.snappedf(0.01))

func readable_float(input:float) -> String:
	return str(snappedf(input, 0.01))

func process_animations() -> void:
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
			if SPINNING or (JUMPING and abs_gsp < 1.0):
				SPINNING = true  # Ensure spinning visual even if jumping from idle
				anim_player.play("SonicMain/AnimSpin")
				anim_player.speed_scale = 1.0
			else:
				if velocity.y > 3.0:
					anim_player.play("SonicMain/AnimAirUp")
					anim_player.speed_scale = 1.0
				elif velocity.y < -4.0:
					anim_player.play("SonicMain/AnimAirDown")
					anim_player.speed_scale = 1.0
				else:
					anim_player.play("SonicMain/AnimAirMid")
					anim_player.speed_scale = 1.0
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
		elif abs_gsp > 115:
			anim_player.play("SonicMain/AnimPeelout")
			var peelout_speed_scale = lerpf(0.5, 2.0, clampf(abs_gsp / 120.0, 0.0, 1.0))
			anim_player.speed_scale = peelout_speed_scale
		elif abs_gsp > 35:
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

func process_rotations(delta: float) -> void:
	if move_dir != Vector3.ZERO:
		if not SKIDDING:
			rotate_toward_direction(model_default, move_dir, delta, 10.0)
			
			# Camera
			
			var camera_movement: Vector2 = Input.get_vector(
				"input_cursor_left", "input_cursor_right", 
				"input_cursor_down", "input_cursor_up"
			)
			
			var reset_pressed: bool = Input.is_action_pressed("input_rb")
			
			if reset_pressed:
				camera.global_transform = global_transform * camera_default_transform
			elif not camera_movement.is_zero_approx():
				#manual camera movement; this overrides the "auto" cam, which is later
				camera_movement *= CAM_SENSITIVITY
				#rotate the camera around the player without actually rotating the parent node in the process
				
				var manual_cam_transform: Transform3D = Transform3D.IDENTITY
				#x transform
				manual_cam_transform = manual_cam_transform.rotated_local(GRAVITY_NORMAL, camera_movement.x)
				#y transform
				manual_cam_transform = manual_cam_transform.rotated_local(camera.global_basis.x.normalized(), camera_movement.y)
				
				camera.global_transform = global_transform * manual_cam_transform * camera.transform
			else:
				#TODO: "auto" cam that follows the player, gradually moving to be behind the player at 
				#all times
				
				camera.global_transform = global_transform * camera.transform
			
			tilt_to_normal(camera, delta, 3.0, 20.0, -1.5)
			
			tilt_to_normal(model_default, delta, 6.0, 20.0, -2.5)

func apply_steering(input_dir: Vector3, delta: float) -> void:
	if input_dir == Vector3.ZERO:
		return
	
	var current_velocity = Vector3(velocity.x, 0, velocity.z)
	var current_speed = current_velocity.length()
	
	if current_speed < 10.5:
		# If too slow, directly apply input
		move_dir = input_dir.normalized()
		return
	
	var current_dir = current_velocity.normalized()
	var input_norm = input_dir.normalized()
	
	var angle_diff = rad_to_deg(acos(clampf(current_dir.dot(input_norm), -1.0, 1.0)))

	var speed_ratio = current_speed / MAXSPD
# Use a non-linear curve for steer strength: stronger at low speeds, weaker at high speeds
	var steer_strength = clampf(pow(1.0 - speed_ratio, 0.5), 0.1, 1.0) * 7.0
	
	# Apply resistance to sharp turns (bigger angle = more speed lost)
	if not ROLLING:
		if angle_diff > 35.0:
			var loss_factor = clampf(angle_diff / 180.0, 0.0, 1.0)
			var speed_loss = current_speed * loss_factor * 0.08
			gsp = maxf(gsp - speed_loss, 0.0)

	# Gradually steer move_dir
	move_dir = current_dir.slerp(input_norm, steer_strength * delta).normalized()

	# Reapply velocity with new direction
	velocity.x = move_dir.x * gsp
	velocity.z = move_dir.z * gsp
	
func _ready() -> void:
	camera_default_transform = camera.transform

func _physics_process(delta: float) -> void:
	debug_label.text = ""
	
	# Calculate rotation that aligns body "down" with floor normal
	var axis: Vector3 = GRAVITY_NORMAL.cross(slope_normal).normalized()
	
	if not axis.is_zero_approx():
		var quat_rotate: Quaternion = Quaternion(axis, acos(slope_mag_dot))
		model_rotation_base.rotation = quat_rotate.get_euler()
	else:
		# Floor normal and up vector are the same (flat ground)
		model_rotation_base.rotation = Vector3.ZERO
	
	# Input
	var input: Vector2 = Input.get_vector(BUTTON_LEFT, BUTTON_RIGHT, BUTTON_UP, BUTTON_DOWN)
	var input_3: Vector3 = Vector3(
		input.x,
		0.0, 
		input.y
	)
	
	var cam_input_dir: Vector3 = (camera.global_basis * input_3).normalized()
	var player_input_dir: Vector3 = (model_default.global_basis * input_3).normalized()
	
	var has_input: bool = not cam_input_dir.is_zero_approx() if not input.is_zero_approx() else false
	
	add_debug_info("Input Vector: " + readable_vector(input_3))
	add_debug_info("Camera-localized Input: " + readable_vector(cam_input_dir))
	add_debug_info("Player-localized Input: " + readable_vector(player_input_dir))
	
	var cam_move_dot: float = move_dir.dot(cam_input_dir)
	var vel_move_dot: float = cam_input_dir.dot(velocity.normalized())
	
	add_debug_info("Cam move dot: " + readable_float(cam_move_dot))
	add_debug_info("Vel move dot: " + readable_float(vel_move_dot))
	
	# SPINNING DETECTION
	if ROLLING or JUMPING or SPINDASHING or SPINLOCK:
		SPINNING = true
	else:
		SPINNING = false
		
	if GROUNDED:
		#STEP 1: Check for crouching, balancing, etc.
		CROUCHING = Input.is_action_pressed(BUTTON_ROLL) and abs_gsp <= 5.0
		
		var can_move:bool = not (SPINDASHING or CROUCHING)
		
		#STEP 2: Check for starting a spindash
		if SPINDASHTYPE == 0:
			if CROUCHING:
				if Input.is_action_just_pressed(BUTTON_JUMP):
					if not SPINDASHING:
						SPINNING = true
						SPINDASHING = true
						Global.play_sfx(audio_player, sfx_charge)
						spindash_charge = 25.0
					
					if has_input:
						rotate_toward_direction(model_default, last_cam_input_dir, delta * 3, 10.0)
					if SPINDASHTYPE == 0:
						if Input.is_action_just_pressed(BUTTON_JUMP):
							Global.play_sfx(audio_player, sfx_charge)
							spindash_charge = clampf(spindash_charge + (SPINDASH_MAX / 6), 0, SPINDASH_MAX)
						
					elif SPINDASHTYPE == 1:
						if abs_gsp > SPINDASH_SLOWDOWN_THRESHOLD:
							gsp = move_toward(gsp, 0.0, abs_gsp / 10.0)
						else:
							spindash_charge = clampf(spindash_charge + SPINDASH_CHARGE_RATE * delta, 0, SPINDASH_MAX)
					
					add_debug_info("Spindash Charge: " + readable_float(spindash_charge))
			elif SPINDASHING:
				var dash_dir: Vector3 = cam_input_dir if has_input else last_cam_input_dir
				if not dash_dir.is_zero_approx():
					move_dir = dash_dir
					gsp = spindash_charge * SPINDASH_RELEASE_MULT
					ROLLING = true
					CROUCHING = false
				else:
					# Fallback if no input direction
					gsp = spindash_charge * SPINDASH_RELEASE_MULT
					ROLLING = true
				SPINDASHING = false
				spindash_charge = 0.0
				ROLLING = true
				Global.play_sfx(audio_player, sfx_release)
		
		#STEP 3: Slope factors
		
		add_debug_info("Slope Normal " + readable_vector(slope_normal))
		
		# positive if the slope and movement are in the same direction;
		#ie. if the player is running downhill
		#var slope_dir_dot: float = move_dir.dot(slope_normal) #works for loops if running towards camera, downhill is always towards camera
		var slope_dir_dot: float = last_player_input_dir.dot(slope_normal)
		
		add_debug_info("Ground Angle " + readable_float(rad_to_deg(acos(slope_mag_dot))))
		
		if not SPINDASHING:
			# Get slope tilt from model forward tilt
			var slope_angle:float = acos(slope_mag_dot)
			
			add_debug_info("Slope magnitude: " + readable_float(slope_mag_dot))
			add_debug_info("Slope direction: " + readable_float(slope_dir_dot))
			add_debug_info("Slope angle: " + readable_float(rad_to_deg(slope_angle)))
			
			#slope factors do NOT apply on ceilings. 
			#if slope_mag_dot < 1.0 and slope_mag_dot > -0.5:
			if slope_mag_dot < 1.0 and slope_mag_dot > 0.0:
				var downhill_factor:float 
				var uphill_factor:float
				
				if ROLLING:
					downhill_factor = ROLL_SLOPE_POWER
					uphill_factor = (ROLL_SLOPE_POWER * 0.60)
				else:
					uphill_factor = (NORMAL_SLOPE_POWER * 0.75)
					downhill_factor = NORMAL_SLOPE_POWER
				
				if slope_dir_dot < 0 or Input.is_action_pressed(DEBUG_DOWNHILL): # Downhill
					add_debug_info("RUNNING DOWNHILL")
					gsp += slope_angle * downhill_factor * delta
				elif slope_dir_dot > 0 or Input.is_action_pressed(DEBUG_DOWNHILL): # Uphill
					add_debug_info("RUNNING UP THAT HILL") #kudos if you pick up the ref :trol:
					gsp -= slope_angle * uphill_factor * delta
			
			# Clamp slope speed
			gsp = clampf(gsp, -MAXSPD, MAXSPD)
		else:
			#WIP: Keep the player from sliding during a spindash
			gsp = 0
			velocity = Vector3.ZERO
		
		
		#STEP 4: Check for starting a jump
		if Input.is_action_just_pressed(BUTTON_JUMP) and can_move:
			JUMPING  = true
			SPINLOCK = true
			SKIDDING = false
			Global.play_sfx(audio_player, sfx_jump)
		
		
		
		#STEP 5: Direction input factors, friction/deceleration
		
		var current_friction: float = SPIN_FRC if SPINNING else FRC
		
		# Detect skidding
		if not SPINNING and not CROUCHING and has_input:
			if move_dir != Vector3.ZERO:
				if vel_move_dot <= -0.16 and abs_gsp > 25.0:
					SKIDDING = true
					Global.play_sfx(audio_player, sfx_skid)
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
				# update_move_direction(cam_input_dir, delta, not GROUNDED)
				if has_input:
					apply_steering(cam_input_dir, delta)
				#recompute this
				cam_move_dot = move_dir.dot(cam_input_dir)
				
				if abs_gsp < MAXACC:
					# Accelerate
					if not SPINNING and not CROUCHING and not SKIDDING and not SPINDASHING:
						if cam_move_dot > 0:
							gsp = minf(gsp + ACC, MAXACC)
						elif cam_move_dot < 0:
							gsp = maxf(gsp - DEC, -MAXACC)
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
			var forward: Vector3 = -model_default.global_basis.z.normalized()
			var wall_normal: Vector3 = get_wall_normal()
			var wall_dot: float = forward.dot(wall_normal)
			
			if wall_dot < WALL_THRESHOLD:  # Almost head-on into wall
				add_debug_info("WALL COLLISION")
				gsp = 0.0
				abs_gsp = 0.0
		
		#STEP 8: Check for doing a roll
		
		if not SPINDASHING:
			if ROLLTYPE == 0:
				if not ROLLING:
					if Input.is_action_just_pressed(BUTTON_ROLL) and abs_gsp > 5.0:
						ROLLING = true
						Global.play_sfx(audio_player, sfx_roll)
					elif abs_gsp < 2.5:
						ROLLING = false
				else:
					if Input.is_action_just_pressed(BUTTON_ROLL):
						ROLLING = false
			elif ROLLTYPE == 1:
				if Input.is_action_just_pressed(BUTTON_ROLL) and abs_gsp > 2.5:
					Global.play_sfx(audio_player, sfx_roll)
				if Input.is_action_pressed(BUTTON_ROLL) and abs_gsp > 2.5:
					ROLLING = true
				else:
					ROLLING = false
		
		if ROLLING and not SPINDASHING and abs_gsp < 1.0 and not JUMPING:
			ROLLING = false
		
		#STEP 9: Handle camera bounds (not gonna worry about that)
		
		#STEP 10: Move the player (apply gsp to velocity)
		gsp = clampf(gsp, -MAXSPD, MAXSPD)
		
		add_debug_info("Ground Speed: " + readable_float(gsp))
		
		if not SPINDASHING:
			var move_vector: Vector3 = move_dir
			move_vector *= gsp
			velocity.x = move_vector.x
			velocity.z = move_vector.z
		
		if JUMPING:
			velocity += slope_normal * JUMP_HEIGHT
		
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
		else:
			slope_normal = GRAVITY_NORMAL
		
		#STEP 12: Check slipping/falling
		
		if GROUNDED:
			var threshold: float = 10.0
			
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
		
		#var current_h_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
		#var current_speed: float = current_h_velocity.length()
		#var current_h_dir: Vector3 = current_h_velocity.normalized() if current_speed > 0.01 else Vector3.ZERO
		
		if has_input:
			apply_steering(cam_input_dir, delta)
			if abs_gsp < MAXACC:
				# Adjust acceleration based on input alignment
				if cam_move_dot > 0:
					gsp = minf(gsp + AIR_ACC, MAXACC)
				elif cam_move_dot < 0:
					gsp = minf(gsp - AIR_ACC, MAXACC)
		else:
			# No input — slowly reduce gsp
			gsp = move_toward(gsp, 0.0, FRC)
		
		# STEP 3: Apply horizontal air velocity based on gsp and move_dir
		gsp = clampf(gsp, -MAXSPD, MAXSPD)
		
		add_debug_info("Ground Speed: " + readable_float(gsp))
		
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
			ROLLING = false
			JUMPING = false
			SPINLOCK = false
			SPINNING = false
			slope_normal = ground_ray.get_collision_normal()
			
			#WIP: Apply velocity to ground (slope) speed
			gsp += (1.0 - slope_mag_dot) * velocity.length()
	
	if has_input:
		last_cam_input_dir = cam_input_dir
		last_player_input_dir = player_input_dir
	
	process_rotations(delta)
	process_animations()
