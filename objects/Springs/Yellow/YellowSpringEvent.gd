extends Area3D

const SPRING_LAUNCH_SPEED := 900.0  # Adjust this as needed

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("Spring activated for:", body.name)

		# Launch upward by modifying vertical velocity
		body.velocity.y = SPRING_LAUNCH_SPEED
