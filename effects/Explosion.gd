extends Node3D

@onready var Debris: GPUParticles3D = $Debris
@onready var Plasma: GPUParticles3D = $Debris/Plasma
@onready var Fire: GPUParticles3D = $Debris/Fire

@onready var Activated: bool = false

func _physics_process(delta: float) -> void:
	if Activated:
		Debris.emitting = true
		Plasma.emitting = true
		Fire.emitting = true
