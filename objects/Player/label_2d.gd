extends Label

@export var player: Node3D  # Drag your player object into this in the editor

func _process(_delta):
	if player:
		var angle = rad_to_deg(acos(player.slope_normal.dot(Vector3.UP)))
		text = "Ground Angle: " + str(round(angle)) + "   GSP: "  + str(roundf(player.gsp)) + "    SPNDSHCHRG: " + str(roundf(player.spindash_charge))
