class_name Diplomacy
extends Node
## Diplomatie : cinq nations voisines entourent le royaume. Chacune a une relation (-100 à 100)
## avec lui, des goûts, des demandes et un caractère. Panneau : touche Y (ou bouton du panneau du royaume).
##  - Cadeaux (or ou ce qu'elle aime, une fois par jour) et demandes remplies : la relation monte.
##  - Traités : paix (elle ne déclare jamais la guerre, relation 0), commerce (relation 20 : une caravane
##    tous les 3 jours et de meilleurs prix chez le marchand), alliance (relation 60, paix et commerce :
##    un présent rare tous les 5 jours et des raids de pillards moins nombreux).
##  - Une nation hostile (relation -40 ou moins, sans traité de paix) peut déclarer la guerre ; on peut
##    aussi la déclarer soi-même. En guerre, ses armées attaquent le village (raids) ; trois armées
##    repoussées : elle capitule et paie un tribut. On peut aussi acheter la paix.
## La relation revient doucement vers le caractère de la nation, un peu chaque jour.
## Conquête : en guerre, on peut assiéger la capitale (voir DungeonManager.enter_siege). Champion vaincu :
## la nation devient une province du royaume (impôts tous les 2 jours, colons de sa race, bonus pour le héros).

signal changed
signal war_declared(id: String, by_us: bool)
signal peace_made(id: String, text: String)

const PEACE_MIN := 0.0
const COMMERCE_MIN := 20.0
const ALLIANCE_MIN := 60.0
const HOSTILE := -40.0
const GIFT_GOLD := 50
const CARAVAN_EVERY := 3
const ALLY_GIFT_EVERY := 5
const WINS_TO_SURRENDER := 3
const TREATY_NAMES := {"paix": "Paix", "commerce": "Commerce", "alliance": "Alliance"}
const TAX_EVERY := 2
const SETTLER_EVERY := 5
const SIEGE_MIN_LEVEL := 6
## Bonus du héros pour chaque province.
const PROVINCE_BONUS := {"attack": 2.0, "defense": 2.0}
## Races des colons de chaque nation.
const RACES := {"karg": ["orc", "gobelin", "hobgobelin"], "sylvae": ["fee", "dryade", "elfe"], "sables": ["homme_lezard", "insectoide"],
	"givre": ["nain", "lycan"], "cendres": ["demon", "oni", "vampire"]}

## id -> nation. base : relation vers laquelle elle revient ; likes : [objet, nombre] qu'elle adore ;
## wants : ce qu'elle peut demander ; goods : ce que livrent ses caravanes ; army : raid en temps de guerre.
const NATIONS := {
	"karg": {"name": "Horde de Karg", "people": "orcs et gobelins", "color": Color("d8844a"), "base": -25.0, "start": -30.0,
		"text": "Une horde fière et belliqueuse, qui ne respecte que la force.",
		"likes": ["viande_cuite", 8], "wants": [["iron_ingot", 10], ["leather", 12], ["viande_cuite", 10]],
		"goods": [["iron_ingot", 5], ["leather", 6], ["viande_crue", 6]],
		"army": {"name": "Armée de la Horde de Karg", "types": ["orc_brute", "gobelin_pillard", "gobelin_pillard"], "leader": "ogre"}},
	"sylvae": {"name": "Cour de Sylvaë", "people": "fées et dryades", "color": Color("8ad66a"), "base": 10.0, "start": 5.0,
		"text": "Les gardiens des bois anciens, méfiants envers ceux qui abattent les arbres.",
		"likes": ["baies", 15], "wants": [["baies", 20], ["ble", 15], ["laine", 8]],
		"goods": [["baies", 10], ["larme_esprit", 1], ["graines_ble", 8]],
		"army": {"name": "Esprits en colère de Sylvaë", "types": ["fee_sauvage", "esprit_follet", "dryade_corrompue"], "leader": "dryade_corrompue"}},
	"sables": {"name": "Sultanat des Sables", "people": "hommes-lézards", "color": Color("e8c86a"), "base": 15.0, "start": 10.0,
		"text": "Des marchands du désert : tout se négocie, surtout l'or.",
		"likes": ["lingot_or", 2], "wants": [["lingot_or", 3], ["poisson_grille", 8], ["bloc_verre", 20]],
		"goods": [["piece_or", 60], ["or_brut", 4], ["bloc_sable", 20]],
		"army": {"name": "Légion du Sultanat", "types": ["homme_lezard", "scorpion", "homme_lezard"], "leader": "homme_lezard"}},
	"givre": {"name": "Jarls du Givre", "people": "clans du nord", "color": Color("9ad0f0"), "base": 0.0, "start": 0.0,
		"text": "Des clans rudes des montagnes gelées, fidèles à leur parole.",
		"likes": ["manteau_laine", 1], "wants": [["laine", 12], ["pain", 10], ["iron_ingot", 8]],
		"goods": [["laine", 8], ["saumon", 4], ["croc_meute", 2]],
		"army": {"name": "Meute des Jarls", "types": ["loup_givre", "ours_neige", "loup_givre"], "leader": "loup_alpha"}},
	"cendres": {"name": "Principauté des Cendres", "people": "démons des volcans", "color": Color("e0705a"), "base": -45.0, "start": -50.0,
		"text": "Une cour démoniaque ambitieuse, qui guette la moindre faiblesse.",
		"likes": ["sang_demon", 1], "wants": [["fragment_brume", 2], ["lingot_or", 4], ["ecaille_dragon", 1]],
		"goods": [["sang_demon", 1], ["piece_or", 80], ["ecaille_dragon", 1]],
		"army": {"name": "Légion des Cendres", "types": ["demon", "salamandre", "slime_magma"], "leader": "seigneur_demon"}},
}

## id -> {rel, war, treaties: [], wins, gift_day, request: [objet, nombre] ou [], req_day, last_caravan, last_gift}
var states := {}
var player: Player
var _day := -1
var _tick := 0.0


func _ready() -> void:
	add_to_group("diplomacy")
	for id in NATIONS:
		states[id] = _fresh(id)
	if not SaveGame.diplomacy_state.is_empty():
		import_state(SaveGame.diplomacy_state)
		SaveGame.diplomacy_state = {}
	_connect.call_deferred()


func _fresh(id: String) -> Dictionary:
	return {"rel": float(NATIONS[id].start), "war": false, "treaties": [], "wins": 0, "gift_day": -1,
		"request": [], "req_day": 0, "last_caravan": 0, "last_gift": 0,
		"annexed": false, "last_tax": 0, "last_settler": 0}


func _connect() -> void:
	var rm := _raids()
	if rm and not rm.raid_ended.is_connected(_on_raid_ended):
		rm.raid_ended.connect(_on_raid_ended)


func _raids() -> RaidManager:
	return get_tree().get_first_node_in_group("raids") as RaidManager


func _day_cycle() -> DayCycle:
	return get_tree().get_first_node_in_group("day_cycle") as DayCycle


func today() -> int:
	var dc := _day_cycle()
	return dc.day if dc else 1


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var d := today()
	if _day < 0:
		_day = d
		return
	while _day < d:
		_day += 1
		new_day(_day)


# ---------------------------------------------------------------- état

func rel(id: String) -> float:
	return float(states[id].rel)


func at_war(id: String) -> bool:
	return bool(states[id].war)


func has_treaty(id: String, t: String) -> bool:
	return (states[id].treaties as Array).has(t)


func _add_rel(id: String, v: float) -> void:
	states[id].rel = clampf(rel(id) + v, -100.0, 100.0)


func annexed(id: String) -> bool:
	return bool(states[id].get("annexed", false))


func provinces() -> Array:
	return NATIONS.keys().filter(func(id): return annexed(id))


func status(id: String) -> String:
	if annexed(id):
		return "Province"
	if at_war(id):
		return "En guerre"
	if has_treaty(id, "alliance"):
		return "Alliée"
	var r := rel(id)
	if r <= HOSTILE:
		return "Hostile"
	if r < 0.0:
		return "Méfiante"
	if r < COMMERCE_MIN:
		return "Neutre"
	return "Amicale"


static func status_color(s: String) -> Color:
	return {"Province": Color("ffd24a"), "En guerre": Color("ff5a4a"), "Hostile": Color("e0705a"), "Méfiante": Color("e8b070"),
		"Neutre": Color("d8d0c0"), "Amicale": Color("8ad66a"), "Alliée": Color("6ad0ff")}.get(s, Color.WHITE)


func wars() -> Array:
	return NATIONS.keys().filter(func(id): return at_war(id))


func allies() -> Array:
	return NATIONS.keys().filter(func(id): return has_treaty(id, "alliance"))


func count_treaty(t: String) -> int:
	return NATIONS.keys().filter(func(id): return has_treaty(id, t)).size()


## Meilleurs prix chez le marchand : -4 % à l'achat et +4 % à la vente par traité de commerce.
func buy_mult() -> float:
	return 1.0 - 0.04 * count_treaty("commerce")


func sell_mult() -> float:
	return 1.0 + 0.04 * count_treaty("commerce")


## Pillards en moins à chaque raid ordinaire (un par allié).
func raid_reduction() -> int:
	return allies().size()


# ---------------------------------------------------------------- actions du joueur

func _item(id: String) -> ItemData:
	return Items.get_item(id)


func _has(id: String, n: int) -> bool:
	return player != null and player.inventory.count(_item(id)) >= n


func _say(text: String) -> void:
	if player:
		player.notify.emit(text)


## Pourquoi on ne peut pas faire l'action ("" si c'est possible).
func block(id: String, action: String) -> String:
	var s: Dictionary = states[id]
	if annexed(id):
		return "C'est ta province."
	match action:
		"siege":
			if not at_war(id):
				return "Il faut être en guerre."
			if player and player.level < SIEGE_MIN_LEVEL:
				return "Niveau %d requis pour mener un siège." % SIEGE_MIN_LEVEL
			var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
			if dm == null or dm.active:
				return "Impossible depuis un donjon."
		"gift", "like":
			if at_war(id):
				return "En guerre : elle refuse tes présents."
			if int(s.gift_day) == today():
				return "Un seul présent par jour."
			if action == "gift" and not _has("piece_or", GIFT_GOLD):
				return "Il faut %d pièces d'or." % GIFT_GOLD
			var lk: Array = NATIONS[id].likes
			if action == "like" and not _has(lk[0], int(lk[1])):
				return "Il faut %d %s." % [int(lk[1]), _item(lk[0]).display_name]
		"request":
			var rq: Array = s.request
			if rq.is_empty():
				return "Pas de demande en ce moment."
			if at_war(id):
				return "En guerre."
			if not _has(rq[0], int(rq[1])):
				return "Il faut %d %s." % [int(rq[1]), _item(rq[0]).display_name]
		"paix", "commerce", "alliance":
			if at_war(id):
				return "Vous êtes en guerre."
			if has_treaty(id, action):
				return "Traité déjà signé."
			var need: float = {"paix": PEACE_MIN, "commerce": COMMERCE_MIN, "alliance": ALLIANCE_MIN}[action]
			if rel(id) < need:
				return "Relation %d requise (actuelle %d)." % [roundi(need), roundi(rel(id))]
			if action == "alliance" and not (has_treaty(id, "paix") and has_treaty(id, "commerce")):
				return "Il faut d'abord la paix et le commerce."
		"war":
			if at_war(id):
				return "Déjà en guerre."
		"peace":
			if not at_war(id):
				return "Vous n'êtes pas en guerre."
			if not _has("piece_or", peace_price(id)):
				return "Il faut %d pièces d'or." % peace_price(id)
	return ""


func peace_price(id: String) -> int:
	return maxi(50, 300 - 80 * int(states[id].wins))


func act(id: String, action: String) -> bool:
	if block(id, action) != "":
		return false
	var s: Dictionary = states[id]
	var nm: String = NATIONS[id].name
	match action:
		"gift":
			player.inventory.remove(_item("piece_or"), GIFT_GOLD)
			s.gift_day = today()
			_add_rel(id, 6.0)
			_say("%s accepte ton présent (+6)." % nm)
		"like":
			var lk: Array = NATIONS[id].likes
			player.inventory.remove(_item(lk[0]), int(lk[1]))
			s.gift_day = today()
			_add_rel(id, 12.0)
			_say("%s adore ce présent : %d %s (+12)." % [nm, int(lk[1]), _item(lk[0]).display_name])
		"request":
			var rq: Array = s.request
			player.inventory.remove(_item(rq[0]), int(rq[1]))
			s.request = []
			s.req_day = today()
			_add_rel(id, 15.0)
			var gold := 30 + 10 * int(rq[1])
			player.inventory.add(_item("piece_or"), gold)
			player.gain_xp(40)
			_say("Demande de %s remplie (+15, %d pièces d'or)." % [nm, gold])
		"paix", "commerce", "alliance":
			(s.treaties as Array).append(action)
			if action == "commerce":
				s.last_caravan = today()
			if action == "alliance":
				s.last_gift = today()
			player.feat.emit("Traité : %s avec %s" % [TREATY_NAMES[action], nm], NATIONS[id].color)
		"war":
			declare_war(id, true)
		"peace":
			player.inventory.remove(_item("piece_or"), peace_price(id))
			_make_peace(id, "Tu achètes la paix avec %s." % nm, -30.0)
	Sound.ui("ui_click")
	changed.emit()
	return true


## Part assiéger la capitale (le panneau est fermé avant).
func start_siege(id: String) -> bool:
	if block(id, "siege") != "":
		return false
	var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
	dm.enter_siege(id)
	return true


## Le champion est tombé : la nation devient une province.
func annex(id: String) -> void:
	var s: Dictionary = states[id]
	s.annexed = true
	s.war = false
	s.wins = 0
	s.treaties = []
	s.request = []
	s.rel = 100.0
	s.last_tax = today()
	s.last_settler = today()
	if player:
		player.absorb_soul("province_" + id, PROVINCE_BONUS)
		player.feat.emit("%s devient ta province !" % NATIONS[id].name, Color("ffd24a"))
		player.notify.emit("Province annexée : impôts tous les %d jours, colons de temps en temps, +2 attaque et +2 défense." % TAX_EVERY)
	# les autres nations craignent l'empire
	for o in NATIONS:
		if o != id and not annexed(o):
			_add_rel(o, -5.0)
	changed.emit()


func _settler(id: String) -> void:
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator
	if w == null or w.villager_scene == null:
		return
	var race_id: String = (RACES.get(id, ["humain"]) as Array).pick_random()
	if not ResourceLoader.exists("res://data/races/%s.tres" % race_id):
		return
	var v := w.villager_scene.instantiate() as Villager
	v.stranger = true
	v.race = load("res://data/races/%s.tres" % race_id)
	v.villager_name = Villager.NAMES[randi() % Villager.NAMES.size()]
	v.level = randi_range(2, 4)
	var jobs := Villager.JOBS.duplicate()
	jobs.shuffle()
	v.talents = {jobs[0]: randf_range(0.5, 0.75), jobs[1]: randf_range(0.2, 0.35)}
	v.recruit_offer = {"items": [], "text": "Je viens de la province de %s. Le royaume est ma nouvelle maison : où dois-je m'installer ?" % NATIONS[id].name}
	v.wander_radius = 2.0
	v.set_meta("province", id)
	w.get_node("Village").add_child(v)
	var a := randf() * TAU
	var pos := w.cell_center(w.spawn_cell) + Vector3(cos(a), 0, sin(a)) * 10.0
	pos.y = w.ground_height_at(pos + Vector3(0, 3, 0))
	v.global_position = pos
	v.home = pos
	_say("Un colon de la province de %s arrive au village (%s) : parle-lui (E)." % [NATIONS[id].name, v.villager_name])


func declare_war(id: String, by_us: bool) -> void:
	var s: Dictionary = states[id]
	s.war = true
	s.wins = 0
	s.treaties = []
	s.rel = minf(rel(id) - 50.0, -60.0)
	# les autres nations n'aiment pas les agresseurs
	if by_us:
		for o in NATIONS:
			if o != id:
				_add_rel(o, -8.0 if not has_treaty(o, "alliance") else -3.0)
	if player:
		var nm: String = NATIONS[id].name
		player.feat.emit(("Tu déclares la guerre à %s !" if by_us else "%s te déclare la guerre !") % nm, Color("ff5a4a"))
		player.notify.emit("Guerre contre %s : ses armées vont attaquer le village. Repousse-en %d pour la faire capituler (Y : diplomatie)." % [nm, WINS_TO_SURRENDER])
	war_declared.emit(id, by_us)
	changed.emit()


func _make_peace(id: String, text: String, new_rel: float) -> void:
	var s: Dictionary = states[id]
	s.war = false
	s.wins = 0
	s.rel = new_rel
	if player:
		player.feat.emit("Paix avec %s" % NATIONS[id].name, Color("8ad66a"))
		player.notify.emit(text)
	peace_made.emit(id, text)
	changed.emit()


# ---------------------------------------------------------------- les jours passent

func new_day(d: int) -> void:
	var rm := _raids()
	var war_raid_done := false
	for id in NATIONS:
		var s: Dictionary = states[id]
		var n: Dictionary = NATIONS[id]
		if annexed(id):
			if d - int(s.last_tax) >= TAX_EVERY:
				s.last_tax = d
				_deliver(id, [["piece_or", 60]] + (n.goods as Array).slice(0, 2), "Impôts de la province de %s" % n.name)
			if d - int(s.last_settler) >= SETTLER_EVERY:
				s.last_settler = d
				_settler(id)
			continue
		# la relation revient vers le caractère de la nation
		if not at_war(id):
			var base: float = n.base + (10.0 if has_treaty(id, "paix") else 0.0) + (10.0 if has_treaty(id, "alliance") else 0.0)
			var r := rel(id)
			if absf(r - base) > 0.5:
				_add_rel(id, clampf(base - r, -1.0, 1.0))
		# une demande de temps en temps
		if (s.request as Array).is_empty() and d - int(s.req_day) >= 3 and not at_war(id):
			s.request = (n.wants as Array).pick_random().duplicate()
			s.req_day = d
		# caravane
		if has_treaty(id, "commerce") and d - int(s.last_caravan) >= CARAVAN_EVERY:
			s.last_caravan = d
			_deliver(id, n.goods, "La caravane de %s est arrivée au village" % n.name)
		# présent d'un allié
		if has_treaty(id, "alliance") and d - int(s.last_gift) >= ALLY_GIFT_EVERY:
			s.last_gift = d
			var gift: Array = [[["mithril_brut", 2], ["gemme_diamant", 1], ["larme_esprit", 1], ["lingot_or", 3], ["gemme_rubis", 1]].pick_random()]
			_deliver(id, gift, "Présent de ton allié, %s" % n.name)
		# une nation hostile peut déclarer la guerre
		if not at_war(id) and rel(id) <= HOSTILE and not has_treaty(id, "paix") and wars().size() < 2 and randf() < 0.15:
			declare_war(id, false)
		# en guerre : son armée marche sur le village
		elif at_war(id) and not war_raid_done and rm and rm.raid.is_empty() and randf() < 0.6:
			war_raid_done = true
			var a: Dictionary = n.army
			rm.announce({"key": "guerre_" + id, "name": a.name, "types": a.types, "leader": a.leader, "extra": 2})
	changed.emit()


func _deliver(id: String, goods: Array, text: String) -> void:
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator
	var parts := []
	for pair in goods:
		var it := _item(pair[0])
		if it == null:
			continue
		parts.append("%d %s" % [int(pair[1]), it.display_name])
		if w:
			var c := w.cell_center(w.spawn_cell) + Vector3(randf_range(-2, 2), 0, randf_range(2, 3.5))
			w.spawn_pickup(it, c, int(pair[1]))
		elif player:
			player.inventory.add(it, int(pair[1]))
	_say("%s : %s (au feu de camp)." % [text, ", ".join(PackedStringArray(parts))])


func _on_raid_ended(r: Dictionary, repelled: bool, _text: String) -> void:
	var key := str(r.get("story", ""))
	if not key.begins_with("guerre_"):
		return
	var id := key.trim_prefix("guerre_")
	if not states.has(id) or not at_war(id):
		return
	var s: Dictionary = states[id]
	if not repelled:
		return
	s.wins = int(s.wins) + 1
	if int(s.wins) >= WINS_TO_SURRENDER:
		var n: Dictionary = NATIONS[id]
		var tribute := [["piece_or", 400]] + (n.goods as Array)
		_make_peace(id, "%s capitule après %d défaites et te paie un tribut." % [n.name, WINS_TO_SURRENDER], -10.0)
		(states[id].treaties as Array).append("paix")
		_deliver(id, tribute, "Tribut de %s" % n.name)
		if player:
			player.gain_xp(300)
	else:
		_say("Armée de %s repoussée : %d / %d avant sa capitulation." % [NATIONS[id].name, int(s.wins), WINS_TO_SURRENDER])
	changed.emit()


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"states": states.duplicate(true), "day": _day}


func import_state(d: Dictionary) -> void:
	var s: Dictionary = d.get("states", {})
	for id in NATIONS:
		states[id] = _fresh(id)
		if not s.has(id):
			continue
		var e: Dictionary = s[id]
		states[id].rel = float(e.get("rel", NATIONS[id].start))
		states[id].war = bool(e.get("war", false))
		states[id].treaties = (e.get("treaties", []) as Array).map(func(t): return str(t))
		states[id].wins = int(e.get("wins", 0))
		states[id].gift_day = int(e.get("gift_day", -1))
		states[id].request = (e.get("request", []) as Array).duplicate()
		if not states[id].request.is_empty():
			states[id].request = [str(states[id].request[0]), int(states[id].request[1])]
		states[id].req_day = int(e.get("req_day", 0))
		states[id].last_caravan = int(e.get("last_caravan", 0))
		states[id].last_gift = int(e.get("last_gift", 0))
		states[id].annexed = bool(e.get("annexed", false))
		states[id].last_tax = int(e.get("last_tax", 0))
		states[id].last_settler = int(e.get("last_settler", 0))
	_day = int(d.get("day", -1))
	changed.emit()
