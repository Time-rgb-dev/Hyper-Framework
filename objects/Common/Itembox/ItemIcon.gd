extends Sprite3D
@export var spr_ring : CompressedTexture2D
@export var spr_barrier : CompressedTexture2D
@export var spr_barrier_water : CompressedTexture2D
@export var spr_barrier_thunder : CompressedTexture2D
@export var spr_barrier_fire : CompressedTexture2D
@export var spr_extralife : CompressedTexture2D
@export var spr_invincibility : CompressedTexture2D
@export var itembox : Area3D

var sec_accum:float

func _ready() -> void:
	# ==== ITEM SWITCH ====
	match itembox.item:
		"10 Rings":
			texture = spr_ring
			pass
		"Barrier":
			texture = spr_barrier
			pass
		"Water Barrier":
			texture = spr_barrier_water
			pass
		"Thunder Barrier":
			texture = spr_barrier_thunder
			pass
		"Fire Barrier":
			texture = spr_barrier_fire
			pass
		"Invincibility":
			texture = spr_invincibility
			pass
		"Extra Life":
			texture = spr_extralife
			pass
		
func _physics_process(delta: float) -> void:
	sec_accum += delta
	
	if sec_accum >= 0.050: #if a second or so has passed
		visible = false
		
		
		if sec_accum >= 0.060:
			visible = true
			sec_accum = 0.0
			
		
