class_name Achievements
extends Node
## Succès et bestiaire (touche F1, ou bouton du journal).
##  - Une centaine de succès (combat, boss, héros, royaume, histoire, familiers, forge, Brume, diplomatie,
##    événements, donjons, exploration). Chacun rapporte des points ; certains donnent un titre.
##  - Les points débloquent des titres et des auras (lumière et particules autour du héros), à choisir dans le panneau.
##  - Le bestiaire recense chaque monstre vaincu : nombre de victoires, vie, attaque, butin, ressources rares, régions.

signal unlocked(id: String)
signal changed

## Monstres du bestiaire (fichiers de data/enemies), dans l'ordre d'affichage.
const BESTIARY := ["slime_bleu", "slime_acide", "slime_magma", "gobelin_pillard", "loup", "loup_alpha", "loup_givre", "sanglier",
	"araignee", "scorpion", "homme_lezard", "orc_brute", "ogre", "harpie", "ours_neige", "salamandre", "esprit_follet",
	"fee_sauvage", "dryade_corrompue", "squelette", "seigneur_squelette", "demon", "seigneur_demon",
	"panthere", "grenouille", "serpent", "serpent_roi", "yeti", "elementaire_glace", "mammouth"]
const BOSSES := {"prairie": "Grondebois", "foret": "Tissombre", "marais": "le Slime Primordial", "desert": "Ankhar",
	"montagnes": "Brisemonts", "toundra": "Givrecroc", "bois_enchante": "Sylvaëlle", "volcan": "Ignarok", "jungle": "Xochitl"}
## Récompenses selon les points : [points, titre, couleur de l'aura (ou null)].
const REWARDS := [[50, "Aventurier", null], [150, "Héros du royaume", Color("6ad0ff")], [300, "Légende vivante", Color("ffd24a")],
	[500, "Mythe éternel", Color("c48aff")]]
const CATEGORIES := ["Combat", "Boss", "Héros", "Royaume", "Histoire", "Familiers", "Forge", "Brume", "Diplomatie", "Événements", "Exploration"]

var kills := {}            # monstre -> victoires
var counters := {}         # compteurs divers (salles secrètes, événements réussis...)
var done := {}             # succès -> jour
var title := ""
var aura := -1             # indice dans REWARDS, -1 : aucune
var player: Player
var _defs: Array = []
var _tick := 0.0
var _aura_light: OmniLight3D
var _aura_fx := 0.0


func _ready() -> void:
	add_to_group("achievements")
	_defs = build_defs()
	if not SaveGame.achievements_state.is_empty():
		import_state(SaveGame.achievements_state)
		SaveGame.achievements_state = {}
	_connect.call_deferred()


func _connect() -> void:
	var wev := get_tree().get_first_node_in_group("world_events")
	if wev and not wev.ended.is_connected(_on_event_ended):
		wev.ended.connect(_on_event_ended)


func _on_event_ended(ev: Dictionary, success: bool, _t: String) -> void:
	if success:
		note("event_" + str(ev.id))


static func _d(id: String, name: String, text: String, cat: String, kind: String, n: float, pts := 10, param := "", title_reward := "") -> Dictionary:
	return {"id": id, "name": name, "text": text, "cat": cat, "kind": kind, "n": n, "pts": pts, "param": param, "title": title_reward}


## La liste des succès.
static func build_defs() -> Array:
	var d := []
	for pair in [[10, "Premier sang", 5], [50, "Chasseur", 5], [100, "Guerrier aguerri", 10], [250, "Fléau des monstres", 10],
			[500, "Massacreur", 20], [1000, "Mille victoires", 20], [2500, "Légion à lui seul", 40]]:
		d.append(_d("kills_%d" % pair[0], pair[1], "Vaincre %d monstres." % pair[0], "Combat", "kills", pair[0], pair[2]))
	for id in BESTIARY:
		var ed := load("res://data/enemies/%s.tres" % id) as EnemyData
		var nm: String = ed.display_name if ed else id
		d.append(_d("kill_" + id, "Chasseur : %s" % nm, "Vaincre 25 × %s." % nm, "Combat", "kill", 25, 5, id))
	for r in BOSSES:
		d.append(_d("boss_" + r, "Tombeur de %s" % BOSSES[r], "Vaincre le boss du donjon (%s)." % BOSSES[r], "Boss", "boss", 1, 10, r))
	d.append(_d("boss_all", "Fléau des boss", "Vaincre les %d boss des donjons." % BOSSES.size(), "Boss", "boss_all", BOSSES.size(), 40, "", "Tueur de boss"))
	for lv in [5, 10, 15, 20, 25, 30, 40, 50]:
		d.append(_d("level_%d" % lv, "Niveau %d" % lv, "Atteindre le niveau %d." % lv, "Héros", "level", lv, 5 if lv < 20 else (10 if lv < 40 else 20)))
	d.append(_d("evo_hero", "Éveil", "Faire évoluer le héros.", "Héros", "hero_evo", 1, 10))
	d.append(_d("gold_1000", "Bourse pleine", "Posséder 1 000 pièces d'or.", "Héros", "gold", 1000, 5))
	d.append(_d("gold_10000", "Trésor royal", "Posséder 10 000 pièces d'or.", "Héros", "gold", 10000, 20, "", "Le Fortuné"))
	for n in [5, 10, 15, 20, 30]:
		d.append(_d("pop_%d" % n, "%d habitants" % n, "Avoir %d habitants au village." % n, "Royaume", "villagers", n, 5 if n < 15 else 10))
	for rk in range(1, 7):
		d.append(_d("rank_%d" % rk, "Rang %d du royaume" % rk, "Faire grandir le royaume jusqu'au rang %d." % rk, "Royaume", "rank", rk, 5 + 5 * (rk / 3)))
	for act in range(1, 17):
		d.append(_d("act_%d" % act, "Acte %d terminé" % act, "Terminer l'acte %d de l'histoire." % act, "Histoire", "act", act, 5 if act < 9 else 10))
	d.append(_d("story_done", "L'Éveil du Royaume", "Terminer l'histoire.", "Histoire", "story_done", 1, 40, "", "L'Éveillé"))
	for n in [1, 10, 20, 40]:
		d.append(_d("side_%d" % n, "Ami du peuple %s" % ["I", "II", "III", "IV"][[1, 10, 20, 40].find(n)], "Terminer %d quête(s) des personnages." % n, "Histoire", "side", n, 5 if n < 20 else 20))
	d.append(_d("fam_1", "Premier pacte", "Apprivoiser un familier.", "Familiers", "familiars", 1, 5))
	d.append(_d("fam_3", "Meute", "Avoir 3 familiers.", "Familiers", "familiars", 3, 10))
	d.append(_d("fam_8", "Grand dompteur", "Avoir 8 familiers.", "Familiers", "familiars", 8, 20, "", "Dompteur"))
	d.append(_d("fam_evo", "Métamorphose", "Faire évoluer un familier deux fois.", "Familiers", "familiar_evo", 2, 10))
	d.append(_d("forge_1", "Apprenti forgeron", "Renforcer un objet à +1.", "Forge", "forge", 1, 5))
	d.append(_d("forge_5", "Forgeron", "Renforcer un objet à +5.", "Forge", "forge", 5, 10))
	d.append(_d("forge_10", "Maître forgeron", "Renforcer un objet à +10.", "Forge", "forge", 10, 20, "", "Maître de la forge"))
	d.append(_d("gems_3", "Joaillier", "Sertir 3 gemmes sur un objet.", "Forge", "gems", 3, 10))
	d.append(_d("rune", "Graveur de runes", "Graver une rune sur un objet.", "Forge", "rune", 1, 10))
	d.append(_d("brume_1", "Dans la Brume", "Franchir un palier de la Brume.", "Brume", "brume", 1, 10))
	d.append(_d("brume_5", "Marcheur de Brume", "Franchir le palier 5 de la Brume.", "Brume", "brume", 5, 20))
	d.append(_d("brume_10", "Maître de la Brume", "Franchir le palier 10 de la Brume.", "Brume", "brume", 10, 40, "", "Maître de la Brume"))
	d.append(_d("brume_lord", "Tueur de Seigneurs", "Vaincre un Seigneur de Brume.", "Brume", "brume_lord", 1, 20))
	d.append(_d("dip_commerce", "Marchand d'État", "Signer un traité de commerce.", "Diplomatie", "treaty", 1, 5, "commerce"))
	d.append(_d("dip_alliance", "Allié fidèle", "Signer une alliance.", "Diplomatie", "treaty", 1, 10, "alliance"))
	d.append(_d("dip_capitulation", "Vainqueur", "Faire capituler une nation en guerre.", "Diplomatie", "counter", 1, 10, "capitulation"))
	d.append(_d("dip_province", "Conquérant", "Annexer une nation.", "Diplomatie", "provinces", 1, 20))
	d.append(_d("dip_empire", "Empereur", "Avoir 3 provinces.", "Diplomatie", "provinces", 3, 40, "", "Empereur"))
	for ev in [["etoiles", "Chasseur d'étoiles"], ["invasion", "Rempart contre la Brume"], ["tournoi", "Champion du tournoi"],
			["fete", "Roi de la fête"], ["epidemie", "Guérisseur"]]:
		d.append(_d("event_" + ev[0], ev[1], "Réussir l'événement « %s »." % ev[1], "Événements", "counter", 1, 10, "event_" + ev[0]))
	d.append(_d("vault", "Pilleur de secrets", "Ouvrir une salle secrète.", "Exploration", "counter", 1, 10, "vault"))
	d.append(_d("vault_5", "Archéologue", "Ouvrir 5 salles secrètes.", "Exploration", "counter", 5, 20, "vault"))
	d.append(_d("gardien", "Briseur de gardiens", "Vaincre un Gardien de donjon.", "Exploration", "counter", 1, 10, "gardien"))
	d.append(_d("obelisks_5", "Voyageur", "Activer 5 obélisques.", "Exploration", "obelisks", 5, 10))
	d.append(_d("obelisks_all", "Cartographe", "Activer tous les obélisques.", "Exploration", "obelisks_all", 1, 20, "", "Cartographe"))
	d.append(_d("bestiary_all", "Naturaliste", "Vaincre au moins un monstre de chaque espèce du bestiaire.", "Exploration", "bestiary", BESTIARY.size(), 20, "", "Naturaliste"))
	return d


func defs() -> Array:
	return _defs


func points() -> int:
	var t := 0
	for d in _defs:
		if done.has(d.id):
			t += int(d.pts)
	return t


## Titres débloqués (par les points et par certains succès).
func titles() -> Array:
	var out := []
	var p := points()
	for r in REWARDS:
		if p >= int(r[0]):
			out.append(r[1])
	for d in _defs:
		if done.has(d.id) and str(d.title) != "":
			out.append(d.title)
	return out


func auras() -> Array:
	var out := []
	var p := points()
	for i in REWARDS.size():
		if REWARDS[i][2] != null and p >= int(REWARDS[i][0]):
			out.append(i)
	return out


func cycle_title() -> void:
	var t := [""] + titles()
	title = t[(t.find(title) + 1) % t.size()]
	changed.emit()


func cycle_aura() -> void:
	var a := [-1] + auras()
	aura = a[(a.find(aura) + 1) % a.size()]
	_update_aura()
	changed.emit()


# ---------------------------------------------------------------- suivi

func on_kill(e: Enemy) -> void:
	if e == null or e.tamed or e.data == null:
		return
	var id := e.data.resource_path.get_file().get_basename()
	counters.kills = int(counters.get("kills", 0)) + 1
	if id != "":
		kills[id] = int(kills.get(id, 0)) + 1


func note(key: String, n := 1) -> void:
	counters[key] = int(counters.get(key, 0)) + n


## Progression actuelle d'un succès (comparée à d.n).
func value(d: Dictionary) -> float:
	var tree := get_tree()
	var st := tree.get_first_node_in_group("story")
	var w := tree.get_first_node_in_group("world") as WorldGenerator
	var dip := tree.get_first_node_in_group("diplomacy")
	match d.kind:
		"kills":
			return int(counters.get("kills", 0))
		"kill":
			return int(kills.get(d.param, 0))
		"bestiary":
			return BESTIARY.filter(func(id): return int(kills.get(id, 0)) > 0).size()
		"boss":
			return 1 if player and player.souls.has(d.param) else 0
		"boss_all":
			return BOSSES.keys().filter(func(r): return player and player.souls.has(r)).size()
		"level":
			return player.level if player else 0
		"hero_evo":
			return int(player.hero_evo) if player else 0
		"gold":
			return player.inventory.count(Items.get_item("piece_or")) if player else 0
		"villagers":
			var vn := tree.get_first_node_in_group("village_needs")
			return vn.members().size() if vn else 0
		"rank":
			var k := tree.get_first_node_in_group("kingdom")
			return k.rank if k else 0
		"act":
			if st == null:
				return 0
			if st.is_done():
				return d.n
			return d.n if int(st.current()[1]) > int(d.n) else 0
		"story_done":
			return 1 if st and st.is_done() else 0
		"side":
			var sq := tree.get_first_node_in_group("side_quests")
			return sq.done_count() if sq else 0
		"familiars":
			var fm := tree.get_first_node_in_group("familiars_mgr")
			return fm.list.size() if fm else 0
		"familiar_evo":
			var fm := tree.get_first_node_in_group("familiars_mgr")
			var best := 0
			if fm:
				for e in fm.list:
					best = maxi(best, int(e.evo))
			return best
		"forge", "gems", "rune":
			var best := 0
			if player:
				var all := player.equipment.slots.values()
				for e in player.inventory.entries:
					all.append(e.item)
				for it in all:
					if it == null:
						continue
					match d.kind:
						"forge":
							best = maxi(best, int(it.upgrade))
						"gems":
							best = maxi(best, it.gems.size())
						"rune":
							best = maxi(best, 1 if it.rune != "" else 0)
			return best
		"brume":
			var best := 0
			if w:
				for z in w.zones:
					best = maxi(best, int(z.get("brume", 0)))
			return best
		"brume_lord":
			return player.souls.keys().filter(func(k): return str(k).begins_with("brume_")).size() if player else 0
		"treaty":
			return nations_with(dip, d.param)
		"provinces":
			return dip.provinces().size() if dip else 0
		"counter":
			return int(counters.get(d.param, 0))
		"obelisks":
			return w.zones.filter(func(z): return z.obelisk_on).size() if w else 0
		"obelisks_all":
			if w == null:
				return 0
			var total := w.zones.filter(func(z): return (z.obelisk as Vector2i).x >= 0).size()
			return 1 if total > 0 and w.zones.filter(func(z): return z.obelisk_on).size() >= total else 0
	return 0


static func nations_with(dip: Node, treaty: String) -> int:
	if dip == null:
		return 0
	return Diplomacy.NATIONS.keys().filter(func(id): return dip.has_treaty(id, treaty)).size()


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player:
			_update_aura()
		return
	_aura_step(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 2.0
	check_all()


## Vérifie tous les succès ; renvoie ceux débloqués maintenant.
func check_all() -> Array:
	var news := []
	for d in _defs:
		if done.has(d.id):
			continue
		if value(d) >= float(d.n):
			_unlock(d)
			news.append(d.id)
	if not news.is_empty():
		changed.emit()
	return news


func _unlock(d: Dictionary) -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle")
	done[d.id] = dc.day if dc else 1
	if player:
		player.feat.emit("Succès : %s (+%d)" % [d.name, int(d.pts)], Color("ffe08a"))
		if str(d.title) != "":
			player.notify.emit("Nouveau titre : « %s » (F1 : succès)." % d.title)
	Sound.ui("achievement")
	unlocked.emit(d.id)


# ---------------------------------------------------------------- aura

func aura_color() -> Variant:
	if aura < 0 or aura >= REWARDS.size():
		return null
	return REWARDS[aura][2]


func _update_aura() -> void:
	if player == null:
		return
	var col = aura_color()
	if col == null:
		if _aura_light and is_instance_valid(_aura_light):
			_aura_light.queue_free()
		_aura_light = null
		return
	if _aura_light == null or not is_instance_valid(_aura_light):
		_aura_light = OmniLight3D.new()
		_aura_light.name = "Aura"
		_aura_light.omni_range = 3.2
		_aura_light.light_energy = 0.9
		_aura_light.position.y = 1.0
		player.add_child(_aura_light)
	_aura_light.light_color = col


func _aura_step(delta: float) -> void:
	var col = aura_color()
	if col == null:
		return
	_aura_fx -= delta
	if _aura_fx <= 0.0:
		_aura_fx = 0.35
		var a := randf() * TAU
		VoxelBurst.spawn(player, player.global_position + Vector3(cos(a) * 0.6, 0.15, sin(a) * 0.6), col, 3, 1.2, 0.07, 0.8, "up", -2.0, false)


# ---------------------------------------------------------------- bestiaire

## Fiche d'un monstre : {name, known, kills, hp, attack, loot, rare, regions}.
func bestiary_entry(id: String) -> Dictionary:
	var ed := load("res://data/enemies/%s.tres" % id) as EnemyData
	var k := int(kills.get(id, 0))
	var out := {"id": id, "name": ed.display_name if ed else id, "known": k > 0, "kills": k, "hp": ed.max_health if ed else 0,
		"attack": ed.attack if ed else 0, "color": ed.color if ed else Color.WHITE, "loot": [], "rare": [], "regions": []}
	if ed:
		for it in ed.loot:
			if it and not out.loot.has(it.display_name):
				out.loot.append(it.display_name)
	for pair in RareDrops.ENEMY.get(id, []):
		var it := Items.get_item(pair[0])
		if it:
			out.rare.append("%s (%.1f %%)" % [it.display_name, float(pair[1]) * 100.0])
	for f in ["bois_enchante", "desert", "foret", "marais", "montagnes", "prairie", "toundra", "volcan", "jungle"]:
		var r := load("res://data/regions/%s.tres" % f) as RegionData
		if r == null:
			continue
		var all: Array = r.enemies + r.elite_enemies
		if all.any(func(e): return e and e.resource_path.get_file().get_basename() == id):
			out.regions.append(r.display_name)
	return out


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"kills": kills.duplicate(), "counters": counters.duplicate(), "done": done.duplicate(), "title": title, "aura": aura}


func import_state(d: Dictionary) -> void:
	kills = {}
	for k in d.get("kills", {}):
		kills[str(k)] = int(d.kills[k])
	counters = {}
	for k in d.get("counters", {}):
		counters[str(k)] = int(d.counters[k])
	done = {}
	for k in d.get("done", {}):
		done[str(k)] = int(d.done[k])
	title = str(d.get("title", ""))
	aura = int(d.get("aura", -1))
	_update_aura()
	changed.emit()
