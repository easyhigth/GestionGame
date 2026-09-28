extends StaticBody2D
## Feu de camp : la lumière vacille doucement.

@export var base_energy: float = 1.3
@export var flicker_strength: float = 0.18
@export var flicker_speed: float = 9.0

@onready var light: PointLight2D = $Light
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	light.energy = base_energy + sin(_t) * flicker_strength * 0.6 + sin(_t * 2.7) * flicker_strength * 0.4
