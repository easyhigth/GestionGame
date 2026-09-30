class_name DayCycle
extends Node
## Cycle du jour et de la nuit : soleil et lune, couleurs du ciel, horloge, monstres de la nuit,
## et sommeil dans un lit (E près d'un lit, la nuit) pour passer au matin.
## Un jour dure DAY_SECONDS (6 h → 20 h) et une nuit NIGHT_SECONDS (20 h → 6 h).

signal night_started
## Le jour se lève (numéro du jour qui commence).
signal day_started(day: int)
signal slept

const DAY_SECONDS := 600.0
const NIGHT_SECONDS := 240.0
const DAWN := 6.0
const DUSK := 20.0
const START_HOUR := 8.0

## Monstres de la nuit : délai entre deux apparitions, distance au héros, nombre maximum.
const SPAWN_EVERY := 7.0
const SPAWN_MIN := 15.0
const SPAWN_MAX := 24.0
## Pas d'apparition à moins de cette distance d'une lumière (torche, feu de camp...).
const LIGHT_SAFE := 8.0

const NIGHT_BG := Color(0.05, 0.07, 0.16)
const NIGHT_AMBIENT := Color(0.4, 0.48, 0.8)
const DUSK_TINT := Color(1.0, 0.55, 0.32)
const MOON_COLOR := Color(0.62, 0.72, 1.0)

var world: WorldGenerator
var player: Player
var hour := START_HOUR
var day := 1
var _night := false
var _spawn_timer := 3.0
var _night_monsters: Array = []
var _sun: DirectionalLight3D
var _env: Environment
var _day_sun := [Color(1, 0.96, 0.88), 0.95]
var _day_env := [Color(0.53, 0.74, 0.9), Color(0.74, 0.78, 0.95), 0.45]


func _ready() -> void:
	add_to_group("day_cycle")
	var root := get_parent()
	_sun = root.get_node_or_null("Soleil") as DirectionalLight3D
	var env_node := root.get_node_or_null("Ambiance") as WorldEnvironment
	_env = env_node.environment if env_node else null
	if _sun:
		_day_sun = [_sun.light_color, _sun.light_energy]
	if _env:
		_day_env = [_env.background_color, _env.ambient_light_color, _env.ambient_light_energy]
	# une partie chargée avant que le cycle n'existe
	if not SaveGame.day_state.is_empty():
		import_state(SaveGame.day_state)
		SaveGame.day_state = {}
	_night = is_night()
	_apply_light()


func is_night() -> bool:
	return hour >= DUSK or hour < DAWN


## Texte de l'horloge : « Jour 3 · 14:20 ».
func clock_text() -> String:
	var h := int(hour) % 24
	var m := int((hour - floorf(hour)) * 60.0)
	return "%s  Jour %d · %02d:%02d" % ["☾" if is_night() else "☀", day, h, m]


func _process(delta: float) -> void:
	if player == null or world == null:
		return
	var rate := (DUSK - DAWN) / DAY_SECONDS if not is_night() else (24.0 - DUSK + DAWN) / NIGHT_SECONDS
	hour += delta * rate
	if hour >= 24.0:
		hour -= 24.0
	_check_transition()
	_apply_light()
	if _night:
		_night_spawns(delta)


func _check_transition() -> void:
	var n := is_night()
	if n == _night:
		return
	_night = n
	if n:
		night_started.emit()
		if player:
			player.notify.emit("La nuit tombe ! Reste près d'une lumière ou dors dans un lit (E).")
	else:
		day += 1
		_dawn()


## Le jour se lève : les créatures de la nuit fuient.
func _dawn() -> void:
	for e in _night_monsters:
		if is_instance_valid(e):
			VoxelBurst.spawn(e.get_parent(), e.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.85, 0.5), 18, 3.0, 0.1, 0.6, "up", 6.0, false)
			e.queue_free()
	_night_monsters.clear()
	day_started.emit(day)
	if player:
		player.notify.emit("Le jour %d se lève." % day)


# ---------------------------------------------------------------- lumière

func _apply_light() -> void:
	# dans un donjon, c'est le donjon qui règle la lumière
	if player and player.global_position.y < WorldGenerator.UNDERGROUND:
		return
	var d := daylight()
	var dusk := clampf(d * (1.0 - d) * 4.0, 0.0, 1.0) * 0.7
	if _sun:
		var t := clampf((hour - DAWN) / (DUSK - DAWN), 0.0, 1.0)
		var dir: Vector3
		if d > 0.35:
			var el := deg_to_rad(12.0 + 50.0 * sin(PI * t))
			var az := deg_to_rad(lerpf(100.0, 260.0, t))
			dir = -Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
		else:
			dir = -Vector3(cos(deg_to_rad(55.0)) * sin(deg_to_rad(200.0)), sin(deg_to_rad(55.0)), cos(deg_to_rad(55.0)) * cos(deg_to_rad(200.0)))
		_sun.global_basis = Basis.looking_at(dir, Vector3.UP)
		var sun_col: Color = (_day_sun[0] as Color).lerp(DUSK_TINT, dusk)
		_sun.light_color = MOON_COLOR.lerp(sun_col, d)
		_sun.light_energy = lerpf(0.2, float(_day_sun[1]), d)
	if _env:
		_env.background_color = NIGHT_BG.lerp(_day_env[0], d).lerp(DUSK_TINT, dusk * 0.6)
		_env.ambient_light_color = NIGHT_AMBIENT.lerp(_day_env[1], d)
		_env.ambient_light_energy = lerpf(0.26, float(_day_env[2]), d)


## 1 en plein jour, 0 la nuit, entre les deux à l'aube et au crépuscule.
func daylight() -> float:
	return smoothstep(DAWN - 0.5, DAWN + 0.8, hour) * (1.0 - smoothstep(DUSK - 0.8, DUSK + 0.5, hour))


# ---------------------------------------------------------------- monstres de la nuit

func _night_spawns(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_EVERY
	_night_monsters = _night_monsters.filter(func(e): return is_instance_valid(e) and e.is_alive())
	# ils marchent vers le héros
	for e in _night_monsters:
		if not e.get("_target"):
			e.home = player.global_position
			e.set("_wander_to", player.global_position)
			e.set("_returning", true)
	if player.global_position.y < WorldGenerator.UNDERGROUND or not player.is_alive():
		return
	if _night_monsters.size() >= max_monsters():
		return
	var pos := _spawn_spot()
	if pos == Vector3.INF:
		return
	var r := world.region_at(pos)
	var z := world.zone_at(pos)
	if r == null or r.enemies.is_empty():
		return
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var e := scene.instantiate() as Enemy
	e.data = r.enemies[randi() % r.enemies.size()]
	var lv: Vector2i = z.get("level", Vector2i(1, 2))
	e.level = randi_range(lv.x, maxi(lv.x, lv.y))
	e.power = 1.0 + 0.09 * maxi(0, e.level - r.level_range.x)
	e.set_meta("night", true)
	add_child(e)
	e.global_position = pos
	e.home = player.global_position
	e.set("_wander_to", player.global_position)
	e.set("_returning", true)
	_night_monsters.append(e)
	VoxelBurst.spawn(self, pos + Vector3(0, 0.5, 0), Color(0.35, 0.2, 0.5), 16, 2.5, 0.1, 0.6, "up", 3.0, false)


## Nombre de monstres de la nuit en même temps (augmente un peu chaque nuit).
func max_monsters() -> int:
	return mini(3 + day, 8)


## Un endroit sombre, praticable, hors des pièces et loin des lumières (INF s'il n'y en a pas).
func _spawn_spot() -> Vector3:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	for i in 12:
		var a := randf() * TAU
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(SPAWN_MIN, SPAWN_MAX)
		p.y = world.ground_height_at(p + Vector3(0, 3, 0))
		if not world.is_walkable(p) or near_light(p):
			continue
		var cell := world.cell_at(p)
		if world.terrain_type(cell) in [WorldGenerator.WATER, WorldGenerator.DEEP]:
			continue
		if k and k.room_at(cell, p.y) != null:
			continue
		return p
	return Vector3.INF


## Vrai près d'une lumière : torche ou lanterne posée, feu de camp, établi du village.
func near_light(pos: Vector3) -> bool:
	if pos.distance_to(world.cell_center(world.spawn_cell)) < LIGHT_SAFE + 2.0:
		return true
	for k in world.build.furniture:
		var f: Dictionary = world.build.furniture[k]
		if (f.item as ItemData).furniture_light and Vector3(f.col.x + 0.5, f.base, f.col.y + 0.5).distance_to(pos) < LIGHT_SAFE:
			return true
	return false


func night_monsters() -> Array:
	return _night_monsters.filter(func(e): return is_instance_valid(e) and e.is_alive())


# ---------------------------------------------------------------- sommeil

## Dormir dans un lit : la nuit seulement, et sans monstre tout près. Renvoie le message à afficher.
func sleep() -> String:
	if not is_night():
		return ""
	for e in get_tree().get_nodes_in_group("enemy_units"):
		if e is Combatant and e.is_alive() and (e as Node3D).global_position.distance_to(player.global_position) < 12.0:
			return "Impossible de dormir : des monstres rôdent tout près !"
	var layer := CanvasLayer.new()
	layer.layer = 50
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		hour = DAWN + 0.5
		_check_transition()
		_apply_light()
		player.health.heal(player.health.max_health)
		slept.emit())
	tw.tween_interval(0.5)
	tw.tween_property(black, "color:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)
	return "Tu dors jusqu'au matin..."


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"hour": hour, "day": day}


func import_state(d: Dictionary) -> void:
	hour = float(d.get("hour", START_HOUR))
	day = int(d.get("day", 1))
	_night = is_night()
	_apply_light()
