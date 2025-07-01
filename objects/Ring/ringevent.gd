extends Area3D

@export var spin_speed = 90.0
@export var ring_value = 1

func _ready():
	connect("body_entered", _on_body_entered)

func _process(delta):
	rotation.y += deg_to_rad(spin_speed) * delta

func _on_body_entered(body):
	if body.has_method("collect_ring"):
		body.collect_ring(ring_value)
	queue_free() # Destroy ring after collection
	
	
