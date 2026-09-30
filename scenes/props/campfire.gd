extends StaticBody3D
## Feu de camp : la lumière vacille doucement et les flammes dansent.

@export var base_energy: float = 1.0
@export var flicker_strength: float = 0.25
@export var flicker_speed: float = 9.0

@onready var light: OmniLight3D = $Light
var _flame: Node3D
var _t := 0.0


func _ready() -> void:
	_flame = find_child("Flame", true, false) as Node3D
	# crépitement du feu, qu'on entend en s'approchant
	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = Sound.loop_stream("amb_fire")
	crackle.bus = "Sfx"
	crackle.unit_size = 2.5
	crackle.max_distance = 16.0
	crackle.volume_db = -4.0
	add_child(crackle)
	crackle.play.call_deferred()


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	var f := sin(_t) * 0.6 + sin(_t * 2.7) * 0.4
	light.light_energy = base_energy + f * flicker_strength
	if _flame:
		_flame.scale = Vector3(1.0 - f * 0.06, 1.0 + f * 0.12, 1.0 - f * 0.06)
		_flame.rotation.y = sin(_t * 0.3) * 0.3
