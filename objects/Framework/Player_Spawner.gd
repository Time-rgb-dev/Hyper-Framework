extends MeshInstance3D

func _ready() -> void:
	visible = false
	var my_scene = preload("res://objects/Framework/Player.tscn")
	var instance = my_scene.instantiate()
	get_tree().current_scene.add_child(instance) # spawn into main scene, not under the mesh
	instance.global_position = global_position   # spawn at spawner's positionyzx
