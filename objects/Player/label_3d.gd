extends Label3D

@export var player: Node3D  # Drag your player object into this in the editor

func _process(_delta):
	if player and player.has_method("get_floor_normal"):
		var floor_normal = player.call("get_floor_normal")
		var angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
		var gsp = player.gsp
		var spindash_charge = player.spindash_charge
		text = "Ground Angle: " + str(round(angle)) + "   GSP: "  + str(round(gsp)) + "    SPNDSHCHRG: " + str(round(spindash_charge))
