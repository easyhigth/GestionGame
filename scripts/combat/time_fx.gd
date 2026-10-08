extends Node
## Autoload « TimeFX » : arrêt sur image au moment des impacts et ralentis (esquive parfaite, parade).
## Les durées sont en temps réel (secondes), indépendantes du ralenti.

var _slow_scale := 1.0
var _slow_until := 0
var _stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Fige l'action un court instant (impact).
func hit_stop(seconds: float) -> void:
	if Access.reduce_motion():
		return
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + roundi(seconds * 1000.0))


## Ralentit le temps (0.3 = 30 % de la vitesse normale).
func slow_motion(time_scale: float, seconds: float) -> void:
	if Access.reduce_motion():
		time_scale = lerpf(time_scale, 1.0, 0.7)
		seconds *= 0.5
	_slow_scale = time_scale
	_slow_until = Time.get_ticks_msec() + roundi(seconds * 1000.0)


func is_slowed() -> bool:
	return Time.get_ticks_msec() < _slow_until


func cancel() -> void:
	_slow_until = 0
	_stop_until = 0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var ts := 1.0
	if now < _slow_until:
		ts = _slow_scale
	if now < _stop_until:
		ts = minf(ts, 0.04)
	Engine.time_scale = ts
