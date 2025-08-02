extends Area3D

var SPRING_LAUNCH_SPEED := 50.0  # Adjust this as needed

@export var target_name: String = "Player"


func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if body.name == target_name:
		print("Spring activated for:", body.name)

		# Launch upward by modifying vertical velocity
		body.velocity.y = SPRING_LAUNCH_SPEED
		body.GROUNDED = false
		body.SPINNING = false
		body.JUMPING = false
