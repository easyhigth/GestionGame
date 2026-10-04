class_name Weather
extends Node3D
## Météo : clair, nuageux, pluie, orage, brouillard. Ce qui tombe dépend de la région où est le héros
## (pluie, neige, sable ou cendres). Le temps change toutes les quelques heures ; chaque jour a un temps
## dominant, annoncé la veille (« demain : pluie »).
## Effets : ciel et lumière, particules, brouillard, sons ; la pluie arrose les champs du village,
## les habitants s'abritent, l'orage amène des monstres et la foudre ; la neige donne froid.

signal changed

const KINDS := ["clair", "nuageux", "pluie", "orage", "brouillard"]
const NAMES := {"clair": "Beau temps", "nuageux": "Nuageux", "pluie": "Pluie", "orage": "Orage", "brouillard": "Brouillard"}
const PRECIP_NAMES := {"neige": ["Neige", "Tempête de neige"], "sable": ["Vent de sable", "Tempête de sable"], "cendres": ["Pluie de cendres", "Orage volcanique"]}
## [nuages 0-1, précipitations 0-1+, brouillard 0-1]
const LOOK := {
	"clair": [0.0, 0.0, 0.0], "nuageux": [0.35, 0.0, 0.05], "pluie": [0.55, 1.0, 0.15],
	"orage": [0.8, 1.4, 0.2], "brouillard": [0.3, 0.0, 1.0],
}
## Durée d'un temps (secondes de jeu) avant d'en tirer un autre.
const MIN_TIME := 110.0
const MAX_TIME := 260.0
## Chance que le temps tiré soit celui du jour.
const DAY_BIAS := 0.6
## Sans pluie depuis ce nombre de jours : sécheresse (les champs non arrosés poussent moins vite).
const DROUGHT_DAYS := 3
const DROUGHT_RATE := 0.75
## Froid dans la neige : au bout de ce temps sans se réchauffer, on ralentit et on a faim plus vite.
const COLD_AFTER := 20.0

var world: WorldGenerator
var player: Player
## Temps en cours, temps dominant du jour, prévision pour demain.
var kind := "clair"
var today := "clair"
var tomorrow := "nuageux"
var dry_days := 0
var cold := false
var _rained_today := false
var _timer := 60.0
var _mix := [0.0, 0.0, 0.0]   # nuages, précipitations, brouillard (valeurs affichées, lissées)
var _precip := "pluie"        # ce qui tombe là où est le héros
var _flash := 0.0
var _bolt_timer := 8.0
var _cold_time := 0.0
var _particles := {}
var _audio: AudioStreamPlayer
var _audio_track := ""
var _env: Environment


func _ready() -> void:
	add_to_group("weather")
	top_level = true
	var env_node := get_parent().get_node_or_null("Ambiance") as WorldEnvironment
	_env = env_node.environment if env_node else null
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Sfx"
	_audio.volume_db = -80.0
	add_child(_audio)
	for p in ["pluie", "neige", "sable", "cendres"]:
		_particles[p] = _make_particles(p)
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		dc.day_started.connect(_on_day)
	else:
		_connect_day.call_deferred()
	if not SaveGame.weather_state.is_empty():
		import_state(SaveGame.weather_state)
		SaveGame.weather_state = {}
	else:
		today = "clair"
		tomorrow = _roll()


func _connect_day() -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and not dc.day_started.is_connected(_on_day):
		dc.day_started.connect(_on_day)


func _village_region() -> RegionData:
	return world.region_at(world.cell_center(world.spawn_cell)) if world else null


## Tire un temps selon le climat du village.
func _roll(region: RegionData = null) -> String:
	var r := region if region else _village_region()
	var w: Dictionary = r.weather_weights if r else {"clair": 4, "nuageux": 3, "pluie": 2, "orage": 1, "brouillard": 1}
	var se := get_tree().get_first_node_in_group("seasons") if is_inside_tree() else null
	var total := 0.0
	for k in KINDS:
		total += float(w.get(k, 0)) * (se.weather_mult(k) if se else 1.0)
	var x := randf() * total
	for k in KINDS:
		x -= float(w.get(k, 0)) * (se.weather_mult(k) if se else 1.0)
		if x <= 0.0:
			return k
	return "clair"


func _on_day(_d: int) -> void:
	dry_days = 0 if _rained_today else dry_days + 1
	_rained_today = false
	today = tomorrow
	tomorrow = _roll()
	set_kind(today)


## Change le temps tout de suite.
func set_kind(k: String) -> void:
	if not LOOK.has(k):
		return
	var before := kind
	kind = k
	_timer = randf_range(MIN_TIME, MAX_TIME)
	if is_wet():
		_rained_today = true
	if player and before != kind and player.global_position.y > WorldGenerator.UNDERGROUND:
		if kind == "orage":
			player.notify.emit("Un orage éclate ! Des monstres rôdent, même en plein jour.")
		elif is_wet() and not (before in ["pluie", "orage"]):
			player.notify.emit("%s : les champs sont arrosés, les habitants se mettent à l'abri." % display_name())
	changed.emit()


# ---------------------------------------------------------------- état

## Il pleut (ou neige...) sur le village.
func is_wet() -> bool:
	return kind == "pluie" or kind == "orage"


func is_storm() -> bool:
	return kind == "orage"


## Les champs sont arrosés par la pluie (seulement la vraie pluie, pas le sable ni les cendres).
func waters_fields() -> bool:
	var r := _village_region()
	return is_wet() and (r == null or r.precipitation in ["pluie", "neige"])


func drought() -> bool:
	return dry_days >= DROUGHT_DAYS


## Assombrissement du ciel (0 à 1).
func clouds() -> float:
	return _mix[0]


func flash() -> float:
	return _flash


## Nom du temps là où est le héros (« Pluie », « Neige », « Tempête de sable »...).
func display_name(k := "", precip := "") -> String:
	if k == "":
		k = kind
	if precip == "":
		precip = _precip
	if (k == "pluie" or k == "orage") and PRECIP_NAMES.has(precip):
		return PRECIP_NAMES[precip][1 if k == "orage" else 0]
	return NAMES.get(k, k)


## Ligne pour le HUD : « Pluie · demain : beau temps ».
func hud_text() -> String:
	var r := _village_region()
	var se := get_tree().get_first_node_in_group("seasons")
	var pr: String = r.precipitation if r else "pluie"
	if pr == "pluie" and se and se.is_winter():
		pr = "neige"
	var t := "%s  ·  demain : %s" % [display_name(), display_name(tomorrow, pr).to_lower()]
	if drought() and not is_wet():
		t += "  ·  sécheresse"
	if cold:
		t += "  ·  tu as froid"
	return t


# ---------------------------------------------------------------- chaque image

func _process(delta: float) -> void:
	if player == null or world == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		set_kind(today if randf() < DAY_BIAS else _roll())
	var underground := player.global_position.y < WorldGenerator.UNDERGROUND
	var r := world.region_at(player.global_position) if not underground else null
	_precip = r.precipitation if r else "pluie"
	# l'hiver, la pluie devient de la neige
	var se := get_tree().get_first_node_in_group("seasons")
	if _precip == "pluie" and se and se.is_winter():
		_precip = "neige"
	# valeurs visées (rien sous terre)
	var goal: Array = LOOK[kind] if not underground else [0.0, 0.0, 0.0]
	for i in 3:
		_mix[i] = move_toward(_mix[i], goal[i], delta * 0.12)
	_update_particles()
	_update_fog()
	_update_audio(delta, underground)
	_flash = maxf(0.0, _flash - delta * 3.0)
	if is_storm() and not underground:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = randf_range(6.0, 14.0)
			lightning()
	_update_cold(delta, underground)


func _make_particles(p: String) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.name = "Particules_" + p
	c.local_coords = false
	c.emitting = false
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	var mesh := BoxMesh.new()
	match p:
		"pluie":
			mesh.size = Vector3(0.04, 0.7, 0.04)
			c.amount = 1400
			c.lifetime = 1.1
			c.emission_box_extents = Vector3(20, 0.5, 20)
			c.direction = Vector3(0.12, -1, 0.05)
			c.spread = 3.0
			c.initial_velocity_min = 16.0
			c.initial_velocity_max = 20.0
			c.gravity = Vector3(0, -6, 0)
			c.color = Color(0.75, 0.85, 1.0, 0.75)
		"neige":
			mesh.size = Vector3(0.13, 0.13, 0.13)
			c.amount = 800
			c.lifetime = 6.0
			c.emission_box_extents = Vector3(20, 0.5, 20)
			c.direction = Vector3(0.3, -1, 0.1)
			c.spread = 25.0
			c.initial_velocity_min = 1.5
			c.initial_velocity_max = 2.5
			c.gravity = Vector3(0.4, -0.6, 0)
			c.color = Color(1, 1, 1, 0.9)
		"sable":
			mesh.size = Vector3(0.35, 0.03, 0.03)
			c.amount = 700
			c.lifetime = 2.2
			c.emission_box_extents = Vector3(3, 5, 20)
			c.direction = Vector3(1, -0.05, 0.1)
			c.spread = 8.0
			c.initial_velocity_min = 14.0
			c.initial_velocity_max = 20.0
			c.gravity = Vector3(0, -0.5, 0)
			c.color = Color(0.85, 0.7, 0.45, 0.6)
		"cendres":
			mesh.size = Vector3(0.07, 0.07, 0.07)
			c.amount = 600
			c.lifetime = 5.0
			c.emission_box_extents = Vector3(20, 0.5, 20)
			c.direction = Vector3(0.2, -1, 0)
			c.spread = 30.0
			c.initial_velocity_min = 1.0
			c.initial_velocity_max = 2.0
			c.gravity = Vector3(0.2, -0.5, 0)
			c.color = Color(0.3, 0.28, 0.27, 0.85)
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.5, 0.15, 0.9))
			g.set_color(1, Color(0.28, 0.26, 0.25, 0.85))
			c.color_ramp = g
	mesh.material = mat
	c.mesh = mesh
	# l'air est déjà plein de gouttes (ou de flocons) quand ça commence
	c.preprocess = c.lifetime
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(c)
	return c


func _update_particles() -> void:
	var p := player.global_position
	for k in _particles:
		var c: CPUParticles3D = _particles[k]
		var on: bool = k == _precip and _mix[1] > 0.15
		if on != c.emitting:
			c.emitting = on
		if on:
			if k == "sable":
				c.global_position = p + Vector3(-18, 1.5, 0)
			else:
				c.global_position = p + Vector3(0, 12 if k == "pluie" else 9, 0)


func _update_fog() -> void:
	if _env == null:
		return
	var fog: float = _mix[2]
	var sand := 0.0
	if _precip == "sable":
		sand = clampf(_mix[1], 0.0, 1.0) * 0.8
	var amount := maxf(fog, sand)
	# sous terre (grottes, donjons) : les ténèbres avalent tout au-delà de quelques mètres
	if player and player.global_position.y < WorldGenerator.UNDERGROUND:
		_env.fog_enabled = true
		_env.fog_mode = Environment.FOG_MODE_DEPTH
		_env.fog_density = 1.0
		_env.fog_depth_begin = 4.0
		_env.fog_depth_end = 30.0
		_env.fog_sky_affect = 1.0
		_env.fog_light_color = Color(0.012, 0.01, 0.018)
		_env.fog_light_energy = 1.0
		return
	var wg := get_tree().get_first_node_in_group("world") as WorldGenerator
	if wg and wg.close_view:
		# vue rapprochée : brume de distance toujours là (fin du monde chargé), plus proche par temps de brouillard
		var reach := wg.view_distance * WorldGenerator.CHUNK
		_env.fog_enabled = true
		_env.fog_mode = Environment.FOG_MODE_DEPTH
		_env.fog_density = 1.0
		_env.fog_depth_end = reach * lerpf(0.95, 0.4, clampf(amount, 0.0, 1.0))
		_env.fog_depth_begin = minf(reach * 0.45, _env.fog_depth_end * 0.3) if amount > 0.02 else reach * 0.45
		_env.fog_sky_affect = 0.6
		if amount > 0.02:
			_env.fog_light_color = Color(0.72, 0.74, 0.78).lerp(Color(0.85, 0.72, 0.5), sand / maxf(amount, 0.001))
		return
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_enabled = amount > 0.02
	if _env.fog_enabled:
		_env.fog_light_color = Color(0.72, 0.74, 0.78).lerp(Color(0.85, 0.72, 0.5), sand / maxf(amount, 0.001))
		_env.fog_density = amount * 0.055
		_env.fog_sky_affect = 0.6
		_env.fog_light_energy = lerpf(1.0, 0.5, _mix[0])


func _update_audio(delta: float, underground: bool) -> void:
	var track := ""
	if not underground and _mix[1] > 0.2:
		track = "amb_rain" if _precip == "pluie" else "amb_wind"
	if track != _audio_track:
		_audio_track = track
		if track != "":
			_audio.stream = Sound._stream(Sound.SFX_DIR, track, true)
			_audio.play()
	var goal := -80.0 if track == "" else lerpf(-24.0, -8.0, clampf(_mix[1] / 1.4, 0.0, 1.0))
	_audio.volume_db = move_toward(_audio.volume_db, goal, delta * 20.0)
	if track == "" and _audio.volume_db <= -79.0 and _audio.playing:
		_audio.stop()


## Un éclair : flash, tonnerre, et parfois la foudre frappe un arbre isolé près du héros.
func lightning() -> void:
	_flash = 1.0
	var at := player.global_position
	get_tree().create_timer(randf_range(0.3, 1.2)).timeout.connect(func(): Sound.ui("thunder"))
	if randf() > 0.35:
		return
	var here := world.cell_at(player.global_position)
	for i in 30:
		var c := here + Vector2i(randi_range(-25, 25), randi_range(-25, 25))
		var k := world.decor_at(c)
		if k != WorldGenerator.D_OAK and k != WorldGenerator.D_PINE:
			continue
		if c.distance_to(world.spawn_cell) < 12.0:
			continue
		var pos := world.cell_center(c)
		world.remove_decor(c)
		VoxelBurst.spawn(world, pos + Vector3(0, 1.5, 0), Color(1.0, 0.95, 0.6), 30, 5.0, 0.12, 0.5, "sphere", 10.0, false)
		VoxelBurst.spawn(world, pos + Vector3(0, 0.6, 0), Color(0.25, 0.2, 0.18), 20, 3.0, 0.12, 0.8, "up", 6.0, false)
		world.spawn_pickup(Items.get_item("wood"), pos + Vector3(0.4, 0, 0.2), 2)
		Sound.play("break_wood", pos)
		if pos.distance_to(at) < 18.0:
			player.notify.emit("La foudre frappe un arbre tout près !")
		return


## Froid : dans la neige, sans lumière proche ni vêtement chaud.
func _update_cold(delta: float, underground: bool) -> void:
	var snowing: bool = not underground and _precip == "neige" and _mix[1] > 0.5
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	var warm := is_warm()
	if dc and dc.near_light(player.global_position):
		warm = true
	if snowing and not warm:
		_cold_time += delta
	else:
		_cold_time = maxf(0.0, _cold_time - delta * 2.0)
	var now := _cold_time >= COLD_AFTER
	if now != cold:
		cold = now
		player.notify.emit("Tu as froid : tu avances moins vite. Approche-toi d'un feu ou porte une cape ou une armure." if cold else "Tu t'es réchauffé.")
		changed.emit()


## Vêtement chaud : une cape, ou une armure de torse.
func is_warm() -> bool:
	var eq := player.equipment
	return eq.slots.has(ItemData.Slot.BACK) or eq.slots.has(ItemData.Slot.CHEST)


## Multiplicateur de vitesse du héros (froid).
func speed_mult() -> float:
	return 0.85 if cold else 1.0


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"kind": kind, "today": today, "tomorrow": tomorrow, "dry": dry_days, "rained": _rained_today, "timer": _timer}


func import_state(d: Dictionary) -> void:
	today = str(d.get("today", "clair"))
	tomorrow = str(d.get("tomorrow", "nuageux"))
	dry_days = int(d.get("dry", 0))
	_rained_today = bool(d.get("rained", false))
	kind = str(d.get("kind", today)) if LOOK.has(str(d.get("kind", ""))) else "clair"
	_timer = float(d.get("timer", 120.0))
	var goal: Array = LOOK[kind]
	_mix = goal.duplicate()
	changed.emit()
