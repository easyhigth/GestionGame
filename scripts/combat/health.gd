class_name Health
extends Node
## Points de vie d'un personnage ou d'un monstre.

signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal died
signal changed(current: int, maximum: int)

@export var max_health: int = 100
## Points de vie rendus par seconde (0 = pas de régénération).
@export var regen_per_second: float = 0.0
## Délai sans prendre de coup avant que la régénération commence (secondes).
@export var regen_delay: float = 6.0

var current: int = 0
## Aucun dégât (terminal de commandes : /dieu).
var invulnerable := false
var _since_hit := 999.0
var _regen_acc := 0.0


func _ready() -> void:
	if current <= 0:
		current = max_health


func is_dead() -> bool:
	return current <= 0


func ratio() -> float:
	return float(current) / float(maxi(max_health, 1))


## Change le maximum (et remplit la vie si `refill`).
func set_max(value: int, refill := false) -> void:
	max_health = maxi(value, 1)
	current = max_health if refill else mini(current, max_health)
	changed.emit(current, max_health)


func take_damage(amount: int, source: Node = null) -> int:
	if is_dead() or amount <= 0 or invulnerable:
		return 0
	var dealt := mini(amount, current)
	current -= dealt
	_since_hit = 0.0
	damaged.emit(dealt, source)
	changed.emit(current, max_health)
	if current <= 0:
		died.emit()
	return dealt


func heal(amount: int) -> void:
	if is_dead() or amount <= 0 or current >= max_health:
		return
	var n := mini(amount, max_health - current)
	current += n
	healed.emit(n)
	changed.emit(current, max_health)


## Remet sur pied avec une fraction de la vie max.
func revive(fraction := 1.0) -> void:
	current = maxi(1, roundi(max_health * fraction))
	_since_hit = 0.0
	changed.emit(current, max_health)


func _process(delta: float) -> void:
	_since_hit += delta
	if regen_per_second <= 0.0 or is_dead() or current >= max_health or _since_hit < regen_delay:
		return
	_regen_acc += regen_per_second * delta
	if _regen_acc >= 1.0:
		var n := floori(_regen_acc)
		_regen_acc -= n
		heal(n)
