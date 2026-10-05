class_name DayCycle
extends Node
## Cycle du jour et de la nuit : soleil et lune, couleurs du ciel, horloge, monstres de la nuit,
## et sommeil dans un lit (E près d'un lit, la nuit) pour passer au matin.
## Un jour dure DAY_SECONDS (6 h → 20 h) et une nuit NIGHT_SECONDS (20 h → 6 h).

signal night_started
## Le jour se lève (numéro du jour qui commence).
signal day_started(day: int)
signal slept
## Une créature de la nuit a été vaincue (pour les quêtes « défendre le village »).
signal night_monster_killed

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
## Lumière d'appoint sans ombre, venue du côté opposé au soleil : les faces à l'ombre
## gardent leur relief au lieu de tourner au noir.
var _fill: DirectionalLight3D
var _fill_day := Color(1.0, 0.93, 0.84)
var _env: Environment
var _day_sun := [Color(1, 0.96, 0.88), 0.95]
var _day_env := [Color(0.53, 0.74, 0.9), Color(0.82, 0.84, 0.9), 0.88]
var _sky_bg := Color(-1, -1, -1)


func _ready() -> void:
	add_to_group("day_cycle")
	var root := get_parent()
	_sun = root.get_node_or_null("Soleil") as DirectionalLight3D
	_fill = root.get_node_or_null("Remplissage") as DirectionalLight3D
	var env_node := root.get_node_or_null("Ambiance") as WorldEnvironment
	_env = env_node.environment if env_node else null
	if _sun:
		_day_sun = [_sun.light_color, _sun.light_energy]
	if _fill:
		_fill_day = _fill.light_color
	if _env:
		_day_env = [_env.background_color, _env.ambient_light_color, _env.ambient_light_energy]
	# une partie chargée avant que le cycle n'existe
	if not SaveGame.day_state.is_empty():
		import_state(SaveGame.day_state)
		SaveGame.day_state = {}
	_night = is_night()
	_apply_light()
	_sync_sky()


func is_night() -> bool:
	return hour >= DUSK or hour < DAWN


## Texte de l'horloge : « Jour 3 · 14:20 ».
func clock_text() -> String:
	var h := int(hour) % 24
	var m := int((hour - floorf(hour)) * 60.0)
	return "%s  Jour %d · %02d:%02d" % ["☾" if is_night() else "☀", day, h, m]


func _process(delta: float) -> void:
	_sync_sky()
	if player == null or world == null:
		return
	var rate := (DUSK - DAWN) / DAY_SECONDS if not is_night() else (24.0 - DUSK + DAWN) / NIGHT_SECONDS
	hour += delta * rate
	if hour >= 24.0:
		hour -= 24.0
	_check_transition()
	_apply_light()
	# la nuit, ou pendant un orage
	var w := _weather()
	if _night or (w and w.is_storm()):
		_night_spawns(delta)
	elif not _night_monsters.is_empty():
		_scatter()


func _check_transition() -> void:
	var n := is_night()
	if n == _night:
		return
	_night = n
	if n:
		night_started.emit()
		Sound.ui("night")
		if player:
			player.notify.emit("La nuit tombe ! Reste près d'une lumière ou dors dans un lit ({interact}).")
	else:
		day += 1
		_dawn()


func _weather() -> Weather:
	return get_tree().get_first_node_in_group("weather") as Weather


## Les créatures de la nuit (ou de l'orage) fuient.
func _scatter() -> void:
	for e in _night_monsters:
		if is_instance_valid(e):
			VoxelBurst.spawn(e.get_parent(), e.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.85, 0.5), 18, 3.0, 0.1, 0.6, "up", 6.0, false)
			e.queue_free()
	_night_monsters.clear()


## Le jour se lève : les créatures de la nuit fuient.
func _dawn() -> void:
	_scatter()
	day_started.emit(day)
	Sound.ui("day")
	if player:
		player.notify.emit("Le jour %d se lève." % day)


# ---------------------------------------------------------------- lumière

func _apply_light() -> void:
	# dans un donjon, c'est le donjon qui règle la lumière
	if player and player.global_position.y < WorldGenerator.UNDERGROUND:
		return
	var d := daylight()
	var dusk := clampf(d * (1.0 - d) * 4.0, 0.0, 1.0) * 0.7
	var w := _weather()
	var cloud := w.clouds() if w else 0.0
	var flash := w.flash() if w else 0.0
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
		_sun.light_color = MOON_COLOR.lerp(sun_col, d).lerp(Color(0.75, 0.78, 0.85), cloud * 0.6)
		_sun.light_energy = lerpf(0.2, float(_day_sun[1]), d) * (1.0 - cloud * 0.6) + flash * 1.5
	if _env:
		var grey := Color(0.5, 0.53, 0.58).lerp(NIGHT_BG, 1.0 - d)
		_env.background_color = NIGHT_BG.lerp(_day_env[0], d).lerp(DUSK_TINT, dusk * 0.6 * (1.0 - cloud)).lerp(grey, cloud * 0.85).lerp(Color(0.85, 0.88, 1.0), flash * 0.5)
		_env.ambient_light_color = NIGHT_AMBIENT.lerp(_day_env[1], d)
		_env.ambient_light_energy = lerpf(0.26, float(_day_env[2]), d) * (1.0 - cloud * 0.25) + flash * 0.8
		# la brume de distance prend la couleur du ciel (bleutée le jour, dorée au crépuscule, sombre la nuit)
		_env.fog_light_color = _env.background_color.lerp(Color(0.85, 0.88, 0.95), 0.15 * d)
		_env.fog_light_energy = lerpf(0.35, 1.0, d)


## Le ciel en dégradé suit la couleur de fond que règlent le cycle, la météo, les donjons et les grottes :
## plus soutenu en haut, plus clair à l'horizon, le sol plus sombre.
func _sync_sky() -> void:
	_sync_fill()
	if _env == null or _env.sky == null:
		return
	var mat := _env.sky.sky_material as ProceduralSkyMaterial
	if mat == null:
		return
	var bg := _env.background_color
	if bg.is_equal_approx(_sky_bg):
		return
	_sky_bg = bg
	var horizon := bg.lerp(Color(0.95, 0.95, 0.95), 0.3 * bg.get_luminance())
	mat.sky_top_color = bg.darkened(0.3)
	mat.sky_horizon_color = horizon
	mat.ground_horizon_color = horizon
	mat.ground_bottom_color = bg.darkened(0.6)


## La lumière d'appoint suit le soleil (ou la lune) : en face de lui, rasante, à 40 % de sa force ;
## chaude le jour (la lumière renvoyée par le sol), bleutée la nuit.
## Les donjons et les grottes baissent le soleil, elle baisse avec.
func _sync_fill() -> void:
	if _fill == null or _sun == null:
		return
	var d := -_sun.global_basis.z
	var fill_dir := Vector3(-d.x, 0.0, -d.z)
	# presque à l'horizontale : elle éclaire les faces à l'ombre (le visage du héros, les flancs) sans
	# s'ajouter au soleil sur le dessus des blocs, qui virait au blanc à midi (neige, peau claire)
	fill_dir = (fill_dir.normalized() + Vector3.DOWN * 0.45).normalized() if fill_dir.length() > 0.01 else Vector3.DOWN
	_fill.global_basis = Basis.looking_at(fill_dir, Vector3.FORWARD if absf(fill_dir.y) > 0.99 else Vector3.UP)
	_fill.light_energy = _sun.light_energy * 0.4
	_fill.light_color = MOON_COLOR.lerp(_fill_day, daylight())


## 1 en plein jour, 0 la nuit, entre les deux à l'aube et au crépuscule.
func daylight() -> float:
	return smoothstep(DAWN - 0.5, DAWN + 0.8, hour) * (1.0 - smoothstep(DUSK - 0.8, DUSK + 0.5, hour))


# ---------------------------------------------------------------- monstres de la nuit

func _night_spawns(delta: float) -> void:
	# option du monde : pas de monstres la nuit
	if not SaveGame.world_flag("night_monsters"):
		return
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
	e.defeated.connect(func(): night_monster_killed.emit())
	e.global_position = pos
	e.home = player.global_position
	e.set("_wander_to", player.global_position)
	e.set("_returning", true)
	_night_monsters.append(e)
	VoxelBurst.spawn(self, pos + Vector3(0, 0.5, 0), Color(0.35, 0.2, 0.5), 16, 2.5, 0.1, 0.6, "up", 3.0, false)


## Nombre de monstres de la nuit en même temps (augmente un peu chaque nuit).
func max_monsters() -> int:
	var w := _weather()
	if w and w.is_storm() and not is_night():
		return 3
	# seul et à mains nues : la première nuit est plus douce
	if GameState.bare_start and day <= 1:
		return 2
	return mini(3 + day, 8) + (2 if w and w.is_storm() else 0)


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
	# la zone du camp (autour du drapeau du royaume) est un refuge : pas de monstres la nuit
	if world.in_home_zone(pos):
		return true
	# le feu du campement de départ (départ à mains nues : il n'y en a pas, ce sont tes torches et ton feu)
	if not GameState.bare_start and pos.distance_to(world.cell_center(world.spawn_cell)) < LIGHT_SAFE + 2.0:
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
	Sound.ui("sleep")
	return "Tu dors jusqu'au matin..."


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"hour": hour, "day": day}


func import_state(d: Dictionary) -> void:
	hour = float(d.get("hour", START_HOUR))
	day = int(d.get("day", 1))
	_night = is_night()
	_apply_light()
