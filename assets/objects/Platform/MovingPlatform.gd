extends StaticBody3D

@export var point_a: Vector3 = Vector3(0, 0, 0)
@export var point_b: Vector3 = Vector3(10, 0, 0)
@export var speed: float = 1.0

var direction: int = 1
var t: float = 0.0

func _process(delta):
	t += direction * speed *  0.5 * delta

	# Ping-pong motion
	if t >= 1.0:
		t = 1.0
		direction = -1
	elif t <= 0.0:
		t = 0.0
		direction = 1

	global_transform.origin = point_a.slerp(point_b, t)


var last_position: Vector3
var velocity: Vector3

func _ready():
	last_position = global_transform.origin

func _physics_process(delta):
	var current_position = global_transform.origin
	velocity = (current_position - last_position) / delta
	last_position = current_position
	# update movement as before
