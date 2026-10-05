extends SceneTree
var f := 0
var p; var w; var snd; var dc
var ok := true
var t0 := 0

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Test"
	h.race = load("res://data/races/homme_bete.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func playing(stream_name: String) -> bool:
	for c in snd.get_children():
		if (c is AudioStreamPlayer or c is AudioStreamPlayer3D) and c.playing and c.stream and c.stream.resource_path.get_file().begins_with(stream_name):
			return true
	return false

func wait(ms: int, key: String) -> bool:
	if f <= 8:
		return false
	if not has_meta(key):
		set_meta(key, Time.get_ticks_msec())
	if Time.get_ticks_msec() - int(get_meta(key)) < ms:
		return false
	if has_meta(key + "_done"):
		return false
	set_meta(key + "_done", true)
	return true

func _process(_d) -> bool:
	f += 1
	OS.delay_msec(4)
	if p: p._invulnerable_left = 5.0
	if f == 8:
		snd = root.get_node("Sound")
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		dc = get_first_node_in_group("day_cycle")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== fichiers")
		var names := ["swing", "hit", "hit_heavy", "block", "parry", "dash", "hurt", "enemy_die", "player_die",
			"step_grass", "step_stone", "step_wood", "step_sand", "chop", "pick", "break_wood", "break_stone", "dig",
			"place", "pickup", "levelup", "cast", "boss_roar", "horn", "ui_click", "ui_open", "craft", "talent",
			"night", "day", "sleep", "door", "amb_day", "amb_night", "amb_fire"]
		var missing := names.filter(func(n): return snd._stream(snd.SFX_DIR, n) == null)
		check("%d bruitages chargés" % (names.size() - missing.size()), missing.is_empty())
		if not missing.is_empty(): print("   manquants : ", missing)
		var all_mus := ["title", "day", "night", "combat", "dungeon", "boss"]
		for r in ["foret", "marais", "desert", "montagnes", "toundra", "bois_enchante", "volcan", "jungle"]:
			all_mus.append("region_" + r)
		var mus := all_mus.filter(func(n): return snd._stream(snd.MUSIC_DIR, n, true) == null)
		check("%d musiques chargées (régions, donjon, boss) %s" % [all_mus.size(), str(mus)], mus.is_empty())
		var ui_missing := ["ui_close", "ui_page", "ui_hover"].filter(func(n): return snd._stream(snd.SFX_DIR, n) == null)
		check("sons d'interface : parchemin, page, survol", ui_missing.is_empty())
		# chaque musique : le thème et deux variantes, enchaînés au hasard et sans fin
		var short := []
		var total := 0.0
		for n in all_mus:
			var pl = snd._stream(snd.MUSIC_DIR, n, true)
			if not (pl is AudioStreamPlaylist and pl.shuffle and pl.loop and pl.stream_count == 3):
				short.append(n)
				continue
			var sec := 0.0
			for k in pl.stream_count:
				var part = pl.get_list_stream(k)
				# chaque partie se joue une fois (c'est la liste qui boucle) ; la musique est en OGG pour rester légère
				if not (part is AudioStreamOggVorbis and not part.loop and part.get_length() > 10.0):
					short.append("%s[%d]" % [n, k])
				sec += part.get_length() if part else 0.0
			total += sec
		check("musiques en 3 parties enchaînées au hasard (%.0f s de musique en tout) %s" % [total, str(short)], short.is_empty() and total > 14 * 60.0)
		check("bus Musique et Bruitages", AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("Sfx") >= 0)
		var sg = root.get_node("SaveGame")
		sg.options.music_volume = 0.25
		sg.apply_options()
		check("volume de la musique réglable (%.1f dB)" % AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.25)) < 0.1)
	if wait(1500, "a"):
		print("== musique et ambiance")
		check("le jour : musique « day » (%s), ambiance « amb_day » (%s)" % [snd.music_track, snd.amb_track], snd.music_track == "day" and snd.amb_track == "amb_day")
		check("la musique joue", snd._music_a.playing or snd._music_b.playing)
		dc.hour = 21.0
		# la musique est réévaluée deux fois par seconde : on force la prochaine réévaluation
		snd._think = 0.0
	if wait(3000, "b"):
		check("la nuit : « night » et « amb_night » (%s / %s)" % [snd.music_track, snd.amb_track], snd.music_track == "night" and snd.amb_track == "amb_night")
		var rm = get_first_node_in_group("raids")
		rm.raid = {"state": "active"}
		check("raid en cours : musique de combat (%s)" % snd._auto_music(p), snd._auto_music(p) == "combat")
		rm.raid = {}
		# loin du village, dans une région : son thème
		var keep: Vector3 = p.global_position
		var target_zone := {}
		for z in w.zones:
			if z.type and z.type.id != "prairie" and snd.has_music("region_" + z.type.id):
				target_zone = z
				break
		if not target_zone.is_empty():
			dc.hour = 10.0
			p.global_position = w.cell_center(target_zone.site)
			check("région « %s » : musique %s" % [target_zone.type.id, snd._auto_music(p)], snd._auto_music(p) == "region_" + target_zone.type.id)
			dc.hour = 21.0
		p.global_position = keep + Vector3(0, -300, 0)
		check("sous terre : musique du donjon (%s)" % snd._auto_music(p), snd._auto_music(p) == "dungeon")
		p.global_position = keep
		snd.forced_music = "combat"
		dc.hour = 10.0
	if wait(4200, "c"):
		snd._think = 0.0; snd._process(0.1)
		check("musique imposée (combat) : %s" % snd.music_track, snd.music_track == "combat")
		snd.forced_music = ""
		print("== bruitages en jeu")
		# un coup d'épée, un dégât reçu, une esquive
		p._next_combo()
		check("coup d'épée : « swing »", playing("swing"))
		var e = load("res://scenes/enemies/enemy.tscn").instantiate()
		e.data = load("res://data/enemies/%s" % DirAccess.get_files_at("res://data/enemies/")[0].trim_suffix(".remap"))
		w.add_child(e)
		e.global_position = p.global_position + Vector3(0, 0, 1.5)
		e.receive_hit(30, p, 1.0, 1.0)
		check("ennemi touché : « hit »", playing("hit"))
		e.queue_free()
		# pas
		p.velocity = Vector3(4, 0, 0)
		p._step_left = 0.0
		p._footsteps(0.016)
		check("pas sur le sol", playing("step_"))
		p._start_dash(Vector3(1, 0, 0))
		check("roulade : « dash »", playing("dash"))
	if wait(4600, "d"):
		print("== écran titre")
		change_scene_to_file("res://scenes/ui/title_screen.tscn")
	if wait(7000, "e"):
		# sur une machine lente, l'écran titre peut mettre du temps à arriver
		if current_scene == null or not current_scene.scene_file_path.ends_with("title_screen.tscn"):
			if has_meta("e_done"):
				remove_meta("e_done")
			if f < 20000:
				return false
		snd._think = 0.0; snd._process(0.1); print("   dbg after process: ", snd.music_track)
		print("   dbg forced=", snd.forced_music, " path=", current_scene.scene_file_path, " think=", snd._think, " proc=", snd.can_process())
		print("   scène : ", current_scene.name if current_scene else "?", " héros : ", get_first_node_in_group("player"))
		check("écran titre : musique « title » (%s), pas d'ambiance" % snd.music_track, snd.music_track == "title" and snd.amb_track == "")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
