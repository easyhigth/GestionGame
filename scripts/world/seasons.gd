class_name Seasons
extends Node
## Saisons : printemps, été, automne, hiver, de SEASON_DAYS jours chacune (une année = 4 saisons).
## Elles changent les couleurs du monde (feuillages, herbe, neige au sol l'hiver), le temps qu'il fait,
## la pousse des cultures (rien ne pousse l'hiver), et chaque saison a sa fête au village (2e jour) :
## décorations, cadeaux, feux d'artifice le soir, habitants plus heureux.

signal season_changed(season: int)
signal festival_started(season: int)

const SEASON_DAYS := 4
const NAMES := ["Printemps", "Été", "Automne", "Hiver"]
## Feuillages : couleur visée et force du mélange (a).
const LEAF := [Color(0.55, 0.85, 0.35, 0.0), Color(0.75, 0.8, 0.3, 0.14), Color(0.92, 0.42, 0.1, 0.8), Color(0.94, 0.96, 1.0, 0.5)]
## Sol (dessus de l'herbe et de la terre) : couleur visée et force.
const GROUND := [Color(0.5, 0.8, 0.35, 0.05), Color(0.8, 0.75, 0.35, 0.18), Color(0.7, 0.5, 0.2, 0.42), Color(0.93, 0.95, 0.99, 0.88)]
## Neige au sol (hiver).
const SNOW := [0.0, 0.0, 0.0, 0.82]
## Pousse des cultures selon la saison.
const CROP_RATE := [1.25, 1.0, 1.0, 0.0]
## Météo : multiplicateurs des chances de chaque temps.
const WEATHER := [
	{"pluie": 1.6, "orage": 0.6},
	{"clair": 1.6, "orage": 1.5, "pluie": 0.6},
	{"brouillard": 2.0, "pluie": 1.4, "clair": 0.8},
	{"pluie": 1.3, "orage": 0.2, "brouillard": 1.3},
]
## Fêtes : nom, texte, cadeaux [identifiant, nombre], couleurs des décorations.
const FESTIVALS := [
	["Fête des semailles", "Les habitants fêtent le retour des beaux jours et t'offrent des semences.", [["graines_ble", 8], ["carotte", 4], ["pomme_de_terre", 4]], [Color("ff8ac8"), Color("fff08a"), Color("8af0a0")]],
	["Fête du solstice", "Le jour le plus long : on danse autour du feu jusqu'à la nuit.", [["poisson_grille", 3], ["baies", 10], ["lanterne", 1]], [Color("ffd24a"), Color("ff8a3a"), Color("8ad8ff")]],
	["Fête des moissons", "Les greniers sont pleins : festin au village !", [["pain", 4], ["gateau", 1], ["fromage", 2]], [Color("e87a2a"), Color("c8a040"), Color("a83a2a")]],
	["Fête des lumières", "Au cœur de l'hiver, lanternes et feux d'artifice chassent la nuit.", [["lanterne", 2], ["soupe_legumes", 2], ["manteau_laine", 1]], [Color("8ac8ff"), Color("ffffff"), Color("c88aff")]],
]
const FESTIVAL_DAY := 2
## Changement de saison : les couleurs glissent en quelques secondes.
const BLEND_SPEED := 0.08

var world: WorldGenerator
var player: Player
var _season := -1
var _leaf := Color(0, 0, 0, 0)
var _ground := Color(0, 0, 0, 0)
var _snow := 0.0
var _gifts := {}          # « an_saison » -> vrai (cadeau déjà donné)
var _decor: Node3D
var _fireworks := 0.0
var _tick := 0.0


func _ready() -> void:
	add_to_group("seasons")
	if not SaveGame.seasons_state.is_empty():
		import_state(SaveGame.seasons_state)
		SaveGame.seasons_state = {}
	var s := season()
	_leaf = LEAF[s]
	_ground = GROUND[s]
	_snow = SNOW[s]
	_apply_colors()


func _day() -> int:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	return dc.day if dc else 1


func season() -> int:
	return ((_day() - 1) / SEASON_DAYS) % 4


func year() -> int:
	return (_day() - 1) / (SEASON_DAYS * 4) + 1


## Jour dans la saison (1 à SEASON_DAYS).
func day_in_season() -> int:
	return (_day() - 1) % SEASON_DAYS + 1


func season_name() -> String:
	return NAMES[season()]


func is_festival() -> bool:
	return day_in_season() == FESTIVAL_DAY


func is_winter() -> bool:
	return season() == 3


func crop_rate() -> float:
	return CROP_RATE[season()]


## Multiplicateur des chances d'un temps (météo).
func weather_mult(kind: String) -> float:
	return float(WEATHER[season()].get(kind, 1.0))


## Premier jour de la prochaine fête.
func next_festival_day() -> int:
	var d := _day()
	var start := d - day_in_season() + 1
	var f := start + FESTIVAL_DAY - 1
	return f if f >= d else f + SEASON_DAYS


## Texte pour le HUD : « Printemps, jour 2/4 ».
func hud_text() -> String:
	var t := "%s, jour %d/%d" % [season_name(), day_in_season(), SEASON_DAYS]
	if is_festival():
		t = "%s · %s" % [FESTIVALS[season()][0], season_name()]
	return t


func _process(delta: float) -> void:
	var s := season()
	if s != _season:
		var first := _season < 0
		_season = s
		if not first:
			season_changed.emit(s)
			if player:
				player.notify.emit("Une nouvelle saison commence : %s." % NAMES[s].to_lower() + (" Rien ne pousse dans les champs en hiver." if s == 3 else ""))
	# les couleurs glissent vers celles de la saison
	var tl: Color = LEAF[s]
	var tg: Color = GROUND[s]
	var k := clampf(delta * BLEND_SPEED * 8.0, 0.0, 1.0)
	_leaf = _leaf.lerp(tl, k)
	_ground = _ground.lerp(tg, k)
	_snow = lerpf(_snow, SNOW[s], k)
	_apply_colors()
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_festival_step()
	if _decor and is_festival():
		_fireworks_step(delta)


func _apply_colors() -> void:
	RenderingServer.global_shader_parameter_set("season_leaf", Vector4(_leaf.r, _leaf.g, _leaf.b, _leaf.a))
	RenderingServer.global_shader_parameter_set("season_ground", Vector4(_ground.r, _ground.g, _ground.b, _ground.a))
	RenderingServer.global_shader_parameter_set("season_snow", _snow)


# ---------------------------------------------------------------- fêtes

func _festival_step() -> void:
	if world == null:
		return
	var on := is_festival()
	var key := "%d_%d" % [year(), season()]
	# décorations d'une autre fête (jours sautés) : on les remplace
	if _decor and (not on or _decor.get_meta("key", "") != key):
		_decor.queue_free()
		_decor = null
	if on and _decor == null:
		_make_decor()
		_decor.set_meta("key", key)
		var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
		if not _gifts.has(key) and dc and dc.hour >= 6.0:
			_gifts[key] = true
			_give_gifts()
			festival_started.emit(season())


func _give_gifts() -> void:
	var f: Array = FESTIVALS[season()]
	var c := world.cell_center(world.spawn_cell)
	var i := 0
	for g in f[2]:
		var it := Items.get_item(g[0])
		if it:
			var a := TAU * i / 3.0 + 0.6
			world.spawn_pickup(it, c + Vector3(cos(a), 0, sin(a)) * 1.8, int(g[1]))
			i += 1
	if player:
		player.feat.emit(f[0] + " !", Color("ffd24a"))
		player.notify.emit("%s %s Les cadeaux sont près du feu de camp." % [f[0] + " :", f[1]])
	Sound.ui("levelup")


## Guirlandes et lanternes autour du feu de camp.
func _make_decor() -> void:
	_decor = Node3D.new()
	_decor.name = "DecorFete"
	world.get_node("Village").add_child(_decor)
	var c := world.cell_center(world.spawn_cell)
	_decor.global_position = c
	var cols: Array = FESTIVALS[season()][3]
	var n := 10
	var tops := []
	for i in n:
		var a := TAU * i / n
		var p := c + Vector3(cos(a), 0, sin(a)) * 6.5
		p.y = world.ground_height_at(p + Vector3(0, 3, 0))
		var pole := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 2.6, 0.12)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.45, 0.3, 0.18)
		bm.material = pm
		pole.mesh = bm
		_decor.add_child(pole)
		pole.global_position = p + Vector3(0, 1.3, 0)
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.3, 0.36, 0.3)
		var mat := StandardMaterial3D.new()
		var col: Color = cols[i % cols.size()]
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.2
		lm.material = mat
		lamp.mesh = lm
		_decor.add_child(lamp)
		lamp.global_position = p + Vector3(0, 2.7, 0)
		tops.append(p + Vector3(0, 2.5, 0))
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 0.8
			l.omni_range = 4.0
			_decor.add_child(l)
			l.global_position = p + Vector3(0, 2.6, 0)
	# fanions entre les mâts
	for i in n:
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[(i + 1) % n]
		for j in 4:
			var t := (j + 0.5) / 4.0
			var q := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.35, 0)
			var flag := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.22, 0.28, 0.03)
			var mm := StandardMaterial3D.new()
			mm.albedo_color = cols[(i + j) % cols.size()]
			fm.material = mm
			flag.mesh = fm
			_decor.add_child(flag)
			flag.global_position = q
			flag.look_at_from_position(q, q + (b - a).cross(Vector3.UP), Vector3.UP)


## Feux d'artifice au-dessus du village, le soir d'une fête.
func _fireworks_step(delta: float) -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc == null or not (dc.hour >= 19.5 or dc.hour < 1.0):
		return
	if player and player.global_position.distance_to(_decor.global_position) > 80.0:
		return
	_fireworks -= delta
	if _fireworks > 0.0:
		return
	_fireworks = randf_range(0.8, 2.0)
	var cols: Array = FESTIVALS[season()][3]
	var at := _decor.global_position + Vector3(randf_range(-10, 10), randf_range(14, 20), randf_range(-10, 10))
	VoxelBurst.spawn(_decor, at, cols[randi() % cols.size()], 40, 7.0, 0.12, 1.3, "sphere", 1.5, false)
	Sound.play("hit_heavy", at)


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"gifts": _gifts.keys()}


func import_state(d: Dictionary) -> void:
	_gifts = {}
	for k in d.get("gifts", []):
		_gifts[str(k)] = true
