extends Area3D

@export  var item: String = "10 Rings"
@onready var item_sound : AudioStream

# Models
@onready var normal_model: MeshInstance3D = $ModelNormal
@onready var broken_model: MeshInstance3D = $ModelBroken
@onready var explosion:    Node3D = $Explosion
# Collision & Sound
#@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var BreakSound: AudioStreamPlayer3D = $BreakSound
@onready var ItemSound: AudioStreamPlayer3D = $ItemSound

@export var sfx_ring:       AudioStream
@export var sfx_barrier:    AudioStream
@export var sfx_water_barrier:    AudioStream
@export var sfx_thunder_barrier:    AudioStream
@export var sfx_fire_barrier:    AudioStream
@export var sfx_extra_life: AudioStream

@export var target_name: StringName = &"Player"

func _ready() -> void:
	# Broken model should be invisible at start
	broken_model.visible = false
	normal_model.visible = true
	explosion.visible = true
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Only react to the correct body
	if body.name != target_name:
		return
	
	# Only break if the player is spinning and box is not already broken
	if body.SPINNING and normal_model.visible:
		# ==== ITEM SWITCH ====
		match item:
			"10 Rings":
				Global.Rings += 10
				Global.Score += 100
				item_sound = sfx_ring
				# TODO: Add rings to player
				pass
			"Barrier":
				Global.Score += 250
				item_sound = sfx_barrier
				body.BARRIER = true
				body.BARRIER_TYPE = "Normal"
				pass
			"Water Barrier":
				Global.Score += 250
				item_sound = sfx_water_barrier
				body.BARRIER = true
				body.BARRIER_TYPE = "Water"
				pass
			"Thunder Barrier":
				Global.Score += 250
				item_sound = sfx_thunder_barrier
				body.BARRIER = true
				body.BARRIER_TYPE = "Thunder"
				pass
			"Fire Barrier":
				Global.Score += 250
				item_sound = sfx_fire_barrier
				body.BARRIER = true
				body.BARRIER_TYPE = "Fire"
				pass
			"Invincibility":
				Global.Score += 250
				item_sound = sfx_ring
				#body.IFRAMES = 1000
				# TODO: Invincibility Stars, sparkles, and music
				pass
			"Extra Life":
				Global.Score += 500
				item_sound = sfx_extra_life
				Global.Lives += 1
				pass
		
		# ==== MONITOR BREAK LOGIC ====
		# Disable collision so player doesn't stick
		#collision.disabled = true
		explosion.Activated = true

		# Toggle models
		normal_model.visible = false
		
		broken_model.visible = true 	

		# Bounce the player upward
		body.velocity.y = -body.velocity.y

		# Play break SFX
		BreakSound.play()
		
		if item_sound:
			Global.play_sfx(ItemSound, item_sound)
