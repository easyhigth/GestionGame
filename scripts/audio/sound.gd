extends Node
## Autoload « Sound » : bruitages, ambiances et musiques.
## Les sons sont dans assets/audio/sfx/<nom>.wav et assets/audio/music/<nom>.wav (fabriqués par
## tools/audio_generator.py). Pour mettre un vrai enregistrement, remplace le fichier en gardant le nom
## (un .ogg du même nom est pris en priorité). Une musique peut avoir des variantes <nom>_2, <nom>_3... :
## le jeu enchaîne alors le thème et ses variantes dans un ordre au hasard, pour ne pas tourner en rond.
##   Sound.play("hit", position)   bruitage (3D si une position est donnée)
##   Sound.ui("ui_click")          bruitage d'interface
## La musique et l'ambiance sont choisies toutes seules : titre, jour, nuit, combat (boss ou raid).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const FADE := 1.6
## Fondu entre deux parties d'une même musique (thème et variantes).
const PART_FADE := 1.2
## Distance au-delà de laquelle un bruitage 3D ne s'entend plus.
const HEAR_DISTANCE := 32.0
## Autour du village, on garde la musique « de chez soi ».
const VILLAGE_RADIUS := 45.0

var _streams := {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _amb: AudioStreamPlayer
var music_track := ""
var amb_track := ""
var _think := 0.0
## Musique imposée (ex. « combat » pendant un boss) : vide = choix automatique.
var forced_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("Sfx")
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_pool2d.append(p)
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Sfx"
		p.max_distance = HEAR_DISTANCE
		p.unit_size = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	_music_a = _make_loop_player("Music")
	_music_b = _make_loop_player("Music")
	_amb = _make_loop_player("Sfx")


func _make_loop_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")


## Volume d'un bus (0 à 1).
func set_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.001, v)))
		AudioServer.set_bus_mute(i, v <= 0.001)


func _stream(dir: String, name: String, loop := false) -> AudioStream:
	var key := dir + name
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(dir + name + ext):
			s = load(dir + name + ext)
			break
	if s and loop and dir == MUSIC_DIR:
		var parts: Array[AudioStream] = [s]
		var i := 2
		while i <= AudioStreamPlaylist.MAX_STREAMS:
			var part := _stream(dir, "%s_%d" % [name, i])
			if part == null:
				break
			parts.append(part)
			i += 1
		if parts.size() > 1:
			var pl := AudioStreamPlaylist.new()
			pl.shuffle = true
			pl.loop = true
			pl.fade_time = PART_FADE
			pl.stream_count = parts.size()
			for k in parts.size():
				pl.set_list_stream(k, parts[k])
			_streams[key] = pl
			return pl
	if s and loop:
		s = s.duplicate()
		if s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			# le fichier importé peut être compressé : on calcule la fin d'après la durée
			w.loop_end = int(w.get_length() * w.mix_rate)
		elif s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
	_streams[key] = s
	return s


## Son en boucle (pour un lecteur posé dans le monde, comme le feu de camp).
func loop_stream(name: String) -> AudioStream:
	return _stream(SFX_DIR, name, true)


## Joue un bruitage. Avec une position : son 3D (plus faible de loin), sinon son « dans la tête ».
func play(name: String, pos := Vector3.INF, volume_db := 0.0, pitch_var := 0.08) -> void:
	var s := _stream(SFX_DIR, name)
	if s == null:
		return
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var)
	if pos == Vector3.INF:
		var p := _free(_pool2d) as AudioStreamPlayer
		p.stream = s
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
		return
	# trop loin de l'auditeur : inutile
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > HEAR_DISTANCE + 6.0:
		return
	var q := _free(_pool3d) as AudioStreamPlayer3D
	q.stream = s
	q.volume_db = volume_db
	q.pitch_scale = pitch
	q.global_position = pos
	q.play()


## Bruitage d'interface (sans variation de hauteur).
func ui(name: String) -> void:
	play(name, Vector3.INF, -4.0, 0.0)


func _free(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	# tout est pris : on coupe le plus ancien
	var p = pool.pop_front()
	pool.append(p)
	return p


# ---------------------------------------------------------------- musique et ambiance

## Change de musique avec un fondu enchaîné (« » = silence).
func music(track: String) -> void:
	if track == music_track:
		return
	music_track = track
	var old := _music_a if _music_a.playing and _music_a.volume_db > -60.0 else _music_b
	var new := _music_b if old == _music_a else _music_a
	var tw := create_tween().set_parallel(true)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.chain().tween_callback(old.stop)
	if track != "":
		new.stream = _stream(MUSIC_DIR, track, true)
		if new.stream:
			new.volume_db = -40.0
			new.play()
			create_tween().tween_property(new, "volume_db", -6.0, FADE)


func ambience(track: String) -> void:
	if track == amb_track:
		return
	amb_track = track
	var tw := create_tween()
	tw.tween_property(_amb, "volume_db", -80.0, FADE * 0.6)
	tw.tween_callback(func():
		_amb.stop()
		if track != "":
			_amb.stream = _stream(SFX_DIR, track, true)
			if _amb.stream:
				_amb.play()
				create_tween().tween_property(_amb, "volume_db", -14.0, FADE))


func _process(delta: float) -> void:
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.5
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# écran titre (le monde y sert de décor) et création du héros
	var path := scene.scene_file_path
	if player == null or path.ends_with("title_screen.tscn") or path.ends_with("character_creator.tscn"):
		music("title")
		ambience("")
		return
	if forced_music != "":
		music(forced_music)
	else:
		music(_auto_music(player))
	var dc := get_tree().get_first_node_in_group("day_cycle")
	var underground := player.global_position.y < WorldGenerator.UNDERGROUND
	if underground:
		ambience("")
	elif dc and dc.is_night():
		ambience("amb_night")
	else:
		ambience("amb_day")


func _auto_music(player: Node3D) -> String:
	# combat : un boss vivant tout près, ou un raid en cours
	for b in get_tree().get_nodes_in_group("bosses"):
		if b is Combatant and (b as Combatant).is_alive() and (b as Node3D).global_position.distance_to(player.global_position) < 30.0:
			return "boss"
	var rm := get_tree().get_first_node_in_group("raids")
	if rm and rm.get("raid") is Dictionary and str(rm.raid.get("state", "")) == "active":
		return "combat"
	# donjons et grottes : thème souterrain
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		return "dungeon"
	var dc := get_tree().get_first_node_in_group("day_cycle")
	if dc and dc.is_night():
		return "night"
	return region_music(player)


## De jour : le thème du village tout près de chez soi, sinon celui de la région traversée.
func region_music(player: Node3D) -> String:
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator
	if w == null:
		return "day"
	if w.has_home() and player.global_position.distance_to(w.home_center()) < VILLAGE_RADIUS:
		return "day"
	var z := w.zone_at(player.global_position)
	if z.is_empty() or z.type == null:
		return "day"
	var track := "region_" + (z.type as RegionData).id
	return track if ResourceLoader.exists(MUSIC_DIR + track + ".wav") else "day"
