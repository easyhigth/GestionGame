class_name FlickerLight
extends OmniLight3D
## Lumière de flamme (torche, feu, lanterne) : son intensité vacille doucement, comme une vraie flamme.

## Intensité moyenne (prise sur light_energy à l'entrée dans la scène si laissée à 0).
var base_energy := 0.0
## Ampleur du vacillement (0,18 : ±18 %).
var amount := 0.18
var speed := 9.0
var _t := randf() * 100.0


func _ready() -> void:
	if base_energy <= 0.0:
		base_energy = light_energy


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta * speed
	light_energy = base_energy * (1.0 + amount * (sin(_t) * 0.5 + sin(_t * 2.7 + 1.3) * 0.3 + sin(_t * 5.3 + 0.4) * 0.2))


## Une lumière de flamme toute prête.
static func make(col: Color, energy: float, rng: float, amt := 0.18) -> FlickerLight:
	var l := FlickerLight.new()
	l.light_color = col
	l.light_energy = energy
	l.base_energy = energy
	l.omni_range = rng
	l.amount = amt
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 15.0
	return l
