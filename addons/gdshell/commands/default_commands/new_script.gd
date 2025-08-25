extends GDShellCommand

const PlayerScene = preload("res://objects/Framework/Player.tscn")	
var player = PlayerScene.instantiate()

@onready var Player = get_node("/root/World/Player")  # adjust the path

func _character(char):
	Player.Character = char
	
