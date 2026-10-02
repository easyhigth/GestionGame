class_name CommandConsole
extends Control
## Terminal de commandes, façon Minecraft : Entrée (ou /) ouvre une ligne où l'on tape une commande
## (/aide pour la liste). Pour explorer, tester ou tricher : dévoiler la carte, se téléporter, se donner des objets...
## Le jeu continue de tourner pendant qu'on écrit. Une commande validée referme la ligne, et les réponses restent
## affichées quelques secondes. Échap referme. Flèches haut/bas : commandes précédentes, Tab : compléter.

## nom -> [syntaxe, description]
const COMMANDS := {
	"aide": ["/aide", "liste des commandes"],
	"carte": ["/carte", "dévoile toute la carte, toutes les zones, villes, châteaux, épaves et grottes"],
	"lieux": ["/lieux", "liste les capitales, châteaux et épaves avec leurs coordonnées"],
	"tp": ["/tp <x> <z>  ·  /tp <lieu>", "téléporte : coordonnées, nom d'une ville ou d'une zone, village, château, épave, grotte, donjon"],
	"pos": ["/pos", "ta position et ta zone"],
	"donner": ["/donner <objet> [nombre]", "ajoute un objet au sac (identifiant ou nom, ex. /donner épée en fer)"],
	"or": ["/or <nombre>", "ajoute des pièces d'or"],
	"soin": ["/soin", "vie et faim au maximum"],
	"vol": ["/vol", "voler au-dessus du monde (Saut : monter, Creuser : descendre) ; encore une fois pour atterrir"],
	"kit": ["/kit", "un équipement complet en mithril, des outils, des potions et de quoi manger"],
	"invoquer": ["/invoquer <monstre> [nombre]", "fait apparaître des monstres devant toi (ex. /invoquer loup 3)"],
	"dieu": ["/dieu", "invincible (encore une fois pour arrêter)"],
	"vitesse": ["/vitesse <x>", "vitesse de marche multipliée (1 = normale, jusqu'à 10)"],
	"niveau": ["/niveau <n>", "monte jusqu'au niveau n"],
	"heure": ["/heure <0-24>", "change l'heure"],
	"meteo": ["/meteo <clair|nuageux|pluie|orage|brouillard>", "change le temps"],
	"obelisques": ["/obelisques", "active tous les obélisques (voyage rapide partout)"],
	"tuer": ["/tuer", "terrasse les monstres à moins de 30 m"],
	"graine": ["/graine", "la graine du monde"],
	"monde": ["/monde", "guerres entre nations, armées en marche, prix des capitales et nouvelles"],
	"guerre": ["/guerre <nation> <nation>", "déclenche une guerre entre deux nations (ex. /guerre karg givre)"],
	"evenement": ["/evenement <foire|tournoi|moissons|morts>", "lance l'événement de saison dans une capitale"],
	"effacer": ["/effacer", "vide le terminal"],
}
const ALIASES := {"help": "aide", "map": "carte", "tp": "tp", "give": "donner", "heal": "soin", "god": "dieu",
	"speed": "vitesse", "time": "heure", "weather": "meteo", "météo": "meteo", "kill": "tuer", "seed": "graine",
	"clear": "effacer", "fly": "vol", "voler": "vol", "summon": "invoquer", "spawn": "invoquer", "obélisques": "obelisques", "level": "niveau", "gold": "or", "lieu": "lieux", "teleport": "tp", "world": "monde", "war": "guerre", "événement": "evenement", "event": "evenement"}
const MAX_LINES := 14
## Temps de calcul accordé par image au dévoilement de la carte (le jeu reste fluide pendant ce temps).
const REVEAL_BUDGET_USEC := 18000

var player: Player
var world: WorldGenerator
var _log: RichTextLabel
var _input: LineEdit
var _lines: Array[String] = []
var _history: Array[String] = []
var _hist_i := -1
var _reveal_row := -1
## Temps de calcul total du dernier /carte (µs), et nombre d'images.
var reveal_usec := 0
var reveal_frames := 0
var _box: PanelContainer
var _open := false
## Secondes pendant lesquelles les réponses restent affichées après la fermeture.
var _linger := 0.0
const LINGER := 7.0


func _ready() -> void:
	add_to_group("command_console")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := PanelContainer.new()
	_box = box
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 16
	box.offset_right = 720
	box.offset_top = -330
	box.offset_bottom = -96
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.82)
	sb.border_color = Color("c8a24a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", sb)
	add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_override("normal_font", UiTheme.font("body"))
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_log)
	_input = LineEdit.new()
	_input.placeholder_text = "Tape une commande (/aide) — Entrée : valider · Échap : fermer"
	_input.add_theme_font_override("font", UiTheme.font("body"))
	_input.add_theme_font_size_override("font_size", 15)
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_key)
	v.add_child(_input)
	_box.hide()
	_say("[color=#c8a24a]Terminal de commandes[/color] — /aide pour la liste.")


func is_open() -> bool:
	return _open


func open(prefill := "") -> void:
	if player == null or player.ui_open:
		return
	_open = true
	_box.show()
	_input.show()
	_box.modulate.a = 1.0
	player.ui_open = true
	_input.text = prefill
	_input.grab_focus.call_deferred()
	(func(): _input.caret_column = _input.text.length()).call_deferred()
	_hist_i = -1


func close(linger := 0.0) -> void:
	if not _open:
		return
	_open = false
	_input.release_focus()
	_input.hide()
	_linger = linger
	if linger <= 0.0:
		_box.hide()
	if player:
		player.ui_open = false


func _unhandled_input(event: InputEvent) -> void:
	if _open:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo or player == null or player.ui_open or get_tree().paused:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		open()
		get_viewport().set_input_as_handled()
	elif k.unicode == 47:   # « / »
		open("/")
		get_viewport().set_input_as_handled()


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_ESCAPE:
			close()
			_input.accept_event()
		KEY_UP:
			if not _history.is_empty():
				_hist_i = mini(_hist_i + 1, _history.size() - 1)
				_input.text = _history[_history.size() - 1 - _hist_i]
				_input.caret_column = _input.text.length()
			_input.accept_event()
		KEY_DOWN:
			_hist_i = maxi(_hist_i - 1, -1)
			_input.text = "" if _hist_i < 0 else _history[_history.size() - 1 - _hist_i]
			_input.caret_column = _input.text.length()
			_input.accept_event()
		KEY_TAB:
			_complete()
			_input.accept_event()


func _complete() -> void:
	var t := _input.text.strip_edges().trim_prefix("/")
	if t.contains(" "):
		return
	var found := COMMANDS.keys().filter(func(c): return String(c).begins_with(t.to_lower()))
	if found.size() == 1:
		_input.text = "/" + str(found[0]) + " "
		_input.caret_column = _input.text.length()
	elif found.size() > 1:
		_say("  " + "  ".join(found.map(func(c): return "/" + str(c))))


func _on_submit(text: String) -> void:
	text = text.strip_edges()
	_input.text = ""
	if text == "":
		close()
		return
	if _history.is_empty() or _history[-1] != text:
		_history.append(text)
	_hist_i = -1
	_say("[color=#8a8a9a]> %s[/color]" % text.replace("[", "[lb]"))
	run(text)
	close(LINGER)


func _say(t: String) -> void:
	_lines.append(t)
	while _lines.size() > 200:
		_lines.pop_front()
	if _log:
		_log.text = "\n".join(_lines.slice(-MAX_LINES * 4))


func _ok(t: String) -> void:
	_say("[color=#8ee07a]%s[/color]" % t)


func _err(t: String) -> void:
	_say("[color=#ff7a6a]%s[/color]" % t)


## Exécute une commande (avec ou sans « / »). Renvoie vrai si elle a réussi.
func run(text: String) -> bool:
	var parts := text.strip_edges().trim_prefix("/").split(" ", false)
	if parts.is_empty():
		return false
	var cmd := _plain(parts[0])
	cmd = ALIASES.get(cmd, cmd)
	var args: Array = Array(parts.slice(1))
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	match cmd:
		"aide":
			for c in COMMANDS:
				_say("[color=#ffd24a]%s[/color]  %s" % [COMMANDS[c][0].replace("[", "[lb]"), COMMANDS[c][1]])
			return true
		"carte":
			return _cmd_map()
		"lieux":
			return _cmd_places()
		"monde":
			return _cmd_world()
		"guerre":
			var pol := get_tree().get_first_node_in_group("world_politics") as WorldPolitics
			if pol == null or args.size() < 2:
				_err("Usage : /guerre <nation> <nation>  (givre, sylvae, sables, karg, cendres)")
				return false
			if pol.start_war(_nation_id(str(args[0])), _nation_id(str(args[1]))):
				_ok("La guerre est déclarée.")
				return true
			_err("Impossible : nations inconnues, ou déjà en guerre.")
			return false
		"evenement":
			var pol := get_tree().get_first_node_in_group("world_politics") as WorldPolitics
			var kind := _plain(str(args[0])) if not args.is_empty() else ""
			if pol == null or not kind in WorldPolitics.SEASON_EVENTS:
				_err("Usage : /evenement <foire|tournoi|moissons|morts>")
				return false
			if pol.start_event(kind, _nation_id(str(args[1])) if args.size() > 1 else ""):
				_ok("Événement lancé : %s." % WorldPolitics.EVENT_NAMES[kind])
				return true
			_err("Impossible pour l'instant.")
			return false
		"tp":
			return _cmd_tp(args)
		"pos":
			var pp := player.global_position
			var z := world.zone_at(pp)
			_ok("Position : x %d, z %d, hauteur %.1f m%s" % [floori(pp.x), floori(pp.z), pp.y, ("  ·  " + str(z.name)) if not z.is_empty() else ""])
			return true
		"donner":
			return _cmd_give(args)
		"or":
			var n := int(args[0]) if not args.is_empty() and str(args[0]).is_valid_int() else 1000
			player.inventory.add(Items.get_item("piece_or"), clampi(n, 1, 999999))
			_ok("+%d pièces d'or." % clampi(n, 1, 999999))
			return true
		"soin":
			player.health.heal(player.health.max_health)
			player.hunger = Player.HUNGER_MAX
			_ok("Vie et faim au maximum.")
			return true
		"vol":
			player.cheat_fly = not player.cheat_fly
			if not player.cheat_fly:
				player.airborne = true    # on retombe doucement
				player.air_vy = 0.0
			_ok("Tu t'envoles ! Saut : monter, Creuser : descendre." if player.cheat_fly else "Tu redescends sur terre.")
			return true
		"kit":
			var given: Array = []
			for pair in [["epee_mithril", 1], ["armure_mithril", 1], ["casque_mithril", 1], ["gantelets_mithril", 1], ["jambieres_mithril", 1],
					["bouclier_hauterive", 1], ["pioche_fer", 1], ["hache_fer", 1], ["potion_soin", 10], ["potion_force", 3],
					["pain", 20], ["viande_cuite", 10], ["torche", 10], ["bloc_planches", 64], ["bloc_pierre_polie", 64]]:
				var it := Items.get_item(pair[0]) as ItemData
				if it:
					player.inventory.add(it, int(pair[1]))
					given.append(it.display_name)
			_ok("Kit d'aventurier : %s." % ", ".join(given))
			return true
		"invoquer":
			return _cmd_summon(args)
		"dieu":
			player.cheat_god = not player.cheat_god
			player.health.invulnerable = player.cheat_god
			_ok("Invincible." if player.cheat_god else "Tu redeviens mortel.")
			return true
		"vitesse":
			if args.is_empty() or not str(args[0]).is_valid_float():
				_err("Usage : /vitesse <x>  (1 = normale)")
				return false
			player.cheat_speed = clampf(float(args[0]), 0.2, 10.0)
			_ok("Vitesse ×%.1f." % player.cheat_speed)
			return true
		"niveau":
			if args.is_empty() or not str(args[0]).is_valid_int():
				_err("Usage : /niveau <n>")
				return false
			var target := clampi(int(args[0]), 1, 99)
			var guard := 0
			while player.level < target and guard < 200:
				player.gain_xp(player.xp_to_next() - player.xp)
				guard += 1
			_ok("Niveau %d." % player.level)
			return true
		"heure":
			if args.is_empty() or not str(args[0]).is_valid_float():
				_err("Usage : /heure <0-24>")
				return false
			var dc := get_tree().get_first_node_in_group("day_cycle")
			if dc:
				dc.hour = fposmod(float(args[0]), 24.0)
			_ok("Il est %dh." % int(fposmod(float(args[0]), 24.0)))
			return true
		"meteo":
			var w := get_tree().get_first_node_in_group("weather")
			var k := _plain(str(args[0])) if not args.is_empty() else ""
			if w == null or not (k in ["clair", "nuageux", "pluie", "orage", "brouillard"]):
				_err("Usage : /meteo clair | nuageux | pluie | orage | brouillard")
				return false
			w.set_kind(k)
			_ok("Météo : %s." % k)
			return true
		"obelisques":
			var n := 0
			for z in world.zones:
				if (z.obelisk as Vector2i).x >= 0 and not z.obelisk_on:
					z.obelisk_on = true
					n += 1
			_ok("%d obélisques activés : ouvre la carte (M) pour voyager." % n)
			return true
		"tuer":
			var n := 0
			for e in get_tree().get_nodes_in_group("enemy_units"):
				if (e as Node3D).global_position.distance_to(player.global_position) < 30.0 and e.get("health"):
					e.health.take_damage(e.health.current + 99999, player)
					n += 1
			_ok("%d monstres terrassés." % n)
			return true
		"graine":
			_ok("Graine du monde : %d" % world.world_seed)
			return true
		"effacer":
			_lines.clear()
			_say("")
			return true
	_err("Commande inconnue : « %s ». Tape /aide." % parts[0])
	return false


## minuscules sans accents, pour comparer des noms
static func _plain(s: String) -> String:
	s = s.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"], ["ï", "i"],
			["ô", "o"], ["ö", "o"], ["û", "u"], ["ù", "u"], ["ü", "u"], ["ç", "c"], ["'", " "], ["-", " "]]:
		s = s.replace(pair[0], pair[1])
	return s.strip_edges()


# ---------------------------------------------------------------- carte

func _cmd_map() -> bool:
	for z in world.zones:
		z.discovered = true
	_reveal_row = 0
	reveal_usec = 0
	reveal_frames = 0
	_ok("La carte se dévoile... (quelques secondes)")
	return true


func _process(delta: float) -> void:
	if not _open and _linger > 0.0:
		_linger -= delta
		_box.modulate.a = clampf(_linger / 1.5, 0.0, 1.0)
		if _linger <= 0.0:
			_box.hide()
	if player and player.cheat_god:
		player._invulnerable_left = 0.5
		if player.health.current < player.health.max_health:
			player.health.heal(player.health.max_health)
	if _reveal_row < 0 or world == null:
		return
	var mc := get_tree().get_first_node_in_group("mountain_caves")
	var t0 := Time.get_ticks_usec()
	while _reveal_row < world.world_size.y and Time.get_ticks_usec() - t0 < REVEAL_BUDGET_USEC:
		var y1 := _reveal_row + 2
		world.reveal_rows(_reveal_row, y1)
		# les entrées de grottes : une rangée de morceaux, quand on vient de la finir
		if mc and (y1 % WorldGenerator.CHUNK == 0 or y1 >= world.world_size.y):
			var chy := (y1 - 1) / WorldGenerator.CHUNK
			for cx in ceili(world.world_size.x / float(WorldGenerator.CHUNK)):
				mc.entrance_of(Vector2i(cx, chy))
		_reveal_row = y1
	reveal_usec += Time.get_ticks_usec() - t0
	reveal_frames += 1
	if _reveal_row >= world.world_size.y:
		_reveal_row = -1
		var caves := 0
		if mc:
			for e in mc._entrances.values():
				if not (e as Dictionary).is_empty():
					caves += 1
		_ok("Carte entière dévoilée : %d zones, %d capitales, %d châteaux, %d épaves, %d grottes. Ouvre-la avec M." % [
			world.zones.size(), world.cities.size(), _sites("castle").size(), _sites("wreck").size(), caves])
		if player:
			player.notify.emit("Toute la carte est dévoilée.")


## Toute la carte est-elle en train de se dévoiler ?
func revealing() -> bool:
	return _reveal_row >= 0


func _sites(kind: String) -> Array:
	return world.structure_sites.filter(func(s): return s.kind == kind)


## Une nation par son identifiant, son nom ou le nom de sa capitale.
func _nation_id(q: String) -> String:
	var p := _plain(q)
	for id in Diplomacy.NATIONS:
		if _plain(id) == p or _plain(Diplomacy.NATIONS[id].name).contains(p):
			return id
	for c in world.cities:
		if _plain(c.name).begins_with(p):
			return c.nation
	return p


func _cmd_world() -> bool:
	var pol := get_tree().get_first_node_in_group("world_politics") as WorldPolitics
	if pol == null:
		_err("Le monde n'est pas encore prêt.")
		return false
	var wars: Array = pol.wars_text()
	_say("[color=#ffd24a]Guerres :[/color] " + (" · ".join(wars) if not wars.is_empty() else "aucune"))
	for ar in pol.armies:
		var at: Vector3 = pol.army_pos(ar)
		_say("%s → %s (x %d, z %d, %d %%)" % [pol._army_name(ar), pol._goal_name(ar), floori(at.x), floori(at.z), roundi(100.0 * float(ar.dist) / maxf(1.0, float(ar.len)))])
	for c in world.cities:
		var notes := []
		for t in ["Forgeron", "Épicier", "Joaillier", "Maçon"]:
			var m := pol.price_mult(c.nation, t, true)
			if absf(m - 1.0) > 0.05:
				notes.append("%s %+d %%" % [WorldPolitics.CAT_NAMES[pol.category(t)], roundi((m - 1.0) * 100.0)])
		_say("%s : %s" % [c.name, ", ".join(notes) if not notes.is_empty() else "prix normaux"])
	if not pol.event.is_empty():
		_say("[color=#ffd24a]Événement :[/color] %s" % WorldPolitics.EVENT_NAMES[pol.event.kind])
	for n in pol.news.slice(-4):
		_say("Jour %d — %s" % [int(n[0]), n[1]])
	return true


func _cmd_places() -> bool:
	for c in world.cities:
		_say("[color=#ffd24a]%s[/color] (%s) : x %d, z %d" % [c.name, Diplomacy.NATIONS.get(c.nation, {}).get("name", ""), c.center.x, c.center.y])
	for s in _sites("castle"):
		var cc: Vector2i = s.cell + Vector2i(10, 10)
		_say("Château %s (%s) : x %d, z %d" % ["abandonné" if s.abandoned else "habité", world.zones[int(s.zone)].name, cc.x, cc.y])
	_say("%d épaves : /tp épave pour la plus proche." % _sites("wreck").size())
	return true


# ---------------------------------------------------------------- téléportation

func _cmd_tp(args: Array) -> bool:
	if args.is_empty():
		_err("Usage : /tp <x> <z>  ou  /tp <lieu>  (ville, zone, village, château, épave, grotte, donjon)")
		return false
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		_err("Sors d'abord du souterrain pour te téléporter.")
		return false
	if args.size() >= 2 and str(args[0]).is_valid_float() and str(args[-1]).is_valid_float():
		var x := float(args[0])
		var z := float(args[-1])
		world.teleport(Vector3(x, 0, z))
		_ok("Téléporté en x %d, z %d." % [floori(x), floori(z)])
		return true
	var q := _plain(" ".join(args))
	var pp := player.global_position
	var dest := Vector3.INF
	var label := ""
	match q:
		"village", "royaume", "maison":
			dest = world.cell_center(world.spawn_cell + Vector2i(0, 4))
			label = "ton village"
		"chateau", "chateau abandonne", "chateau habite":
			var list := _sites("castle")
			if q != "chateau":
				list = list.filter(func(s): return s.abandoned == (q == "chateau abandonne"))
			var s = _nearest(list, func(s): return s.cell + Vector2i(10, 22))
			if s:
				dest = _cell_pos(s.cell + Vector2i(10, 24))
				label = "le château %s (%s)" % ["abandonné" if s.abandoned else "habité", world.zones[int(s.zone)].name]
		"epave", "bateau":
			var s = _nearest(_sites("wreck"), func(s): return s.cell)
			if s:
				dest = _cell_pos(s.cell + Vector2i(-3, 6))
				label = "l'épave la plus proche"
		"grotte", "caverne":
			var e := _nearest_cave()
			if not e.is_empty():
				dest = e.pos + Vector3(e.dir.x * -1.5, 0, e.dir.y * -1.5)
				label = "l'entrée de grotte la plus proche"
		"donjon":
			var best := -1.0
			for z in world.zones:
				var g: Vector2i = z.gate
				if g.x >= 0 and not z.get("cleared", false):
					var d := Vector2(g.x - pp.x, g.y - pp.z).length()
					if best < 0.0 or d < best:
						best = d
						dest = _cell_pos(g + Vector2i(0, 4))
						label = "le donjon de " + str(z.name)
	if dest == Vector3.INF:
		for c in world.cities:
			if _plain(c.name).begins_with(q) or _plain(c.nation) == q:
				# devant la porte la plus extérieure (Minas Cendrys a une porte par cercle)
				var gate := Vector2i(0, c.radius)
				for g in c.gates:
					if gate == Vector2i(0, c.radius) or Vector2(g).length() > Vector2(gate).length():
						gate = g
				var out := Vector2(gate).normalized() * 4.0
				dest = _cell_pos(c.center + gate + Vector2i(roundi(out.x), roundi(out.y)))
				label = c.name
				break
	if dest == Vector3.INF:
		for z in world.zones:
			if _plain(z.name).contains(q):
				dest = world.cell_center(Vector2i(z.site))
				label = z.name
				break
	if dest == Vector3.INF:
		_err("Lieu inconnu : « %s ». Essaie une ville (/lieux), une zone, village, château, épave, grotte ou donjon." % " ".join(args))
		return false
	world.teleport(dest)
	_ok("Téléporté : %s." % label)
	return true


func _cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func _nearest(list: Array, cell_of: Callable):
	var best = null
	var bd := INF
	var pp := player.global_position
	for s in list:
		var c: Vector2i = cell_of.call(s)
		var d := Vector2(c.x - pp.x, c.y - pp.z).length()
		if d < bd:
			bd = d
			best = s
	return best


func _nearest_cave() -> Dictionary:
	var mc := get_tree().get_first_node_in_group("mountain_caves")
	if mc == null:
		return {}
	var pp := player.global_position
	var ch := Vector2i(floori(pp.x) / WorldGenerator.CHUNK, floori(pp.z) / WorldGenerator.CHUNK)
	var nchunks := ceili(world.world_size.x / float(WorldGenerator.CHUNK))
	for r in range(0, nchunks):
		var best := {}
		var bd := INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var c := ch + Vector2i(dx, dz)
				if c.x < 0 or c.y < 0 or c.x >= nchunks or c.y >= nchunks:
					continue
				var e: Dictionary = mc.entrance_of(c)
				if not e.is_empty():
					var d: float = (e.pos as Vector3).distance_to(pp)
					if d < bd:
						bd = d
						best = e
		if not best.is_empty():
			return best
	return {}


# ---------------------------------------------------------------- monstres

func _cmd_summon(args: Array) -> bool:
	if args.is_empty():
		_err("Usage : /invoquer <monstre> [nombre]  (ex. /invoquer loup 3, /invoquer bandit)")
		return false
	var n := 1
	if args.size() > 1 and str(args[-1]).is_valid_int():
		n = clampi(int(args[-1]), 1, 20)
		args = args.slice(0, args.size() - 1)
	var q := _plain(" ".join(args))
	var found := ""
	var dir := DirAccess.open("res://data/enemies")
	var ids: Array = []
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tres") or f.ends_with(".tres.remap"):
				ids.append(f.trim_suffix(".remap").trim_suffix(".tres"))
	for id in ids:
		if _plain(id).replace("_", " ") == q:
			found = id
	if found == "":
		for id in ids:
			var d := load("res://data/enemies/%s.tres" % id) as EnemyData
			if _plain(id).replace("_", " ").contains(q) or (d and _plain(d.display_name).contains(q)):
				found = id
				break
	if found == "":
		_err("Monstre inconnu : « %s »." % " ".join(args))
		return false
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var data := load("res://data/enemies/%s.tres" % found) as EnemyData
	var front := player.global_position + player.facing.normalized() * 5.0 if player.facing.length() > 0.1 else player.global_position + Vector3(0, 0, 5)
	var parent: Node = world.get_node_or_null("Village") if world.get_node_or_null("Village") else world
	for i in n:
		var e := scene.instantiate() as Enemy
		e.data = data
		e.level = maxi(1, player.level)
		e.power = 1.0 + 0.05 * e.level
		parent.add_child(e)
		var a := TAU * i / n
		var p := front + Vector3(cos(a), 0, sin(a)) * (0.0 if n == 1 else 2.0)
		p.y = world.support_height(p, player.global_position.y + 2.0)
		e.global_position = p
		e.home = p
	_ok("%d × %s." % [n, data.display_name])
	return true


# ---------------------------------------------------------------- objets

func _cmd_give(args: Array) -> bool:
	if args.is_empty():
		_err("Usage : /donner <objet> [nombre]")
		return false
	var n := 1
	if args.size() > 1 and str(args[-1]).is_valid_int():
		n = clampi(int(args[-1]), 1, 9999)
		args = args.slice(0, args.size() - 1)
	var q := _plain(" ".join(args))
	var it: ItemData = Items.get_item(" ".join(args))
	if it == null:
		var partial: ItemData = null
		for id in Items.items:
			var cand: ItemData = Items.items[id]
			var name := _plain(cand.display_name)
			if name == q or _plain(id).replace("_", " ") == q:
				it = cand
				break
			if partial == null and (name.contains(q) or _plain(id).replace("_", " ").contains(q)):
				partial = cand
		if it == null:
			it = partial
	if it == null:
		_err("Objet inconnu : « %s »." % " ".join(args))
		return false
	player.inventory.add(it, n)
	_ok("+%d %s (%s)." % [n, it.display_name, it.id])
	return true
