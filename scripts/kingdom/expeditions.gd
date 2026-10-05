class_name Expeditions
extends Node
## Expéditions des habitants (panneau du royaume → Expéditions) : on envoie 1 à 4 habitants en mission
## (chasse, cueillette, pêche, mine, escorte, ruines, repaire). Ils quittent le village le temps de la mission ;
## la réussite dépend de leur niveau, de leur classe et de leur métier (et d'un soigneur et d'un protecteur dans
## le groupe). Au retour : butin pour le héros, expérience et bonheur pour eux ; en cas d'échec, un peu de butin,
## des blessés et du mécontentement.

const MAX_PARTY := 4
## Expéditions en même temps : 1, 2 dès le Village, 3 en Ville.
const MAX_ACTIVE := [1, 1, 2, 2, 3, 3, 3]
const MISSIONS := {
	"chasse": {"name": "Partie de chasse", "icon": "🏹", "dur": 120.0, "diff": 1.0,
		"text": "Traquer le gibier dans les bois alentour.",
		"classes": ["rodeur", "assassin", "barbare"], "jobs": ["chasseur", "dresseur"],
		"loot": [["leather", 3], ["viande_crue", 4], ["croc_meute", 1]], "gold": 4},
	"cueillette": {"name": "Cueillette en forêt", "icon": "🌿", "dur": 90.0, "diff": 0.6,
		"text": "Ramasser baies, fibres et bois mort.",
		"classes": ["druide", "moine", "barde"], "jobs": ["fermier", "alchimiste"],
		"loot": [["baies", 6], ["fiber", 6], ["wood", 8]], "gold": 0},
	"peche": {"name": "Campagne de pêche", "icon": "🎣", "dur": 100.0, "diff": 0.7,
		"text": "Remonter la rivière et jeter les filets.",
		"classes": ["rodeur", "moine"], "jobs": ["pecheur", "cuisinier"],
		"loot": [["truite", 3], ["carpe", 3], ["saumon", 1]], "gold": 2},
	"mine": {"name": "Expédition minière", "icon": "⛏", "dur": 150.0, "diff": 1.5,
		"text": "Creuser un filon dans les collines.",
		"classes": ["guerrier", "barbare", "chevalier"], "jobs": ["mineur", "macon", "joaillier"],
		"loot": [["stone", 12], ["iron_ore", 5], ["or_brut", 2], ["gemme_amethyste", 1]], "gold": 5},
	"escorte": {"name": "Escorte de caravane", "icon": "🐴", "dur": 180.0, "diff": 2.0,
		"text": "Protéger des marchands sur la route.",
		"classes": ["chevalier", "paladin", "guerrier"], "jobs": ["marchand", "garde"],
		"loot": [["piece_or", 20], ["potion_soin", 1]], "gold": 0},
	"ruines": {"name": "Exploration des ruines", "icon": "🏛", "dur": 240.0, "diff": 3.0,
		"text": "Fouiller les ruines anciennes à la recherche de savoirs.",
		"classes": ["mage", "cryomancien", "necromancien", "barde"], "jobs": ["erudit", "enchanteur"],
		"loot": [["piece_or", 15], ["rune_force", 1], ["potion_soin", 2], ["gemme_saphir", 1]], "gold": 0},
	"repaire": {"name": "Nettoyer un repaire", "icon": "☠", "dur": 210.0, "diff": 4.0,
		"text": "Chasser les monstres d'une caverne voisine. Il faut un soigneur et un protecteur.",
		"classes": ["paladin", "clerc", "chevalier", "guerrier", "mage"], "jobs": ["garde"],
		"loot": [["piece_or", 30], ["iron_ingot", 4], ["lingot_or", 1], ["gemme_rubis", 1]], "gold": 0},
}
## Événements à mi-parcours : un choix pour le joueur (panneau des expéditions). Sans réponse, la 2e option
## (la plus prudente) est choisie au retour. Effets : chance (ajoutée), loot (multiplie le butin), time (secondes
## en plus), extra ([[objet, nombre]] en cas de réussite), recruit (un voyageur rejoint le village).
const EVENTS := {
	"grotte": {"icon": "🕳", "text": "Ils découvrent l'entrée d'une grotte inconnue.", "options": [
		["Explorer (risqué, plus de butin)", {"chance": -0.15, "loot": 1.6, "extra": [["gemme_amethyste", 1]]}],
		["Passer leur chemin", {}]]},
	"voyageur": {"icon": "🧍", "text": "Ils croisent un voyageur blessé au bord du chemin.", "options": [
		["Le soigner et le ramener (+1 min)", {"time": 60.0, "recruit": true}],
		["Lui laisser des vivres", {"chance": 0.05}]]},
	"bete": {"icon": "🐗", "text": "Une grosse bête sauvage rôde près de leur camp.", "options": [
		["La chasser (viande et cuir)", {"chance": -0.08, "extra": [["viande_crue", 4], ["leather", 3]]}],
		["La contourner", {}]]},
	"tempete": {"icon": "⛈", "text": "Une violente tempête se prépare.", "options": [
		["Continuer malgré tout", {"chance": -0.1, "loot": 1.25}],
		["Rentrer plus tôt (moins de butin)", {"time": -40.0, "loot": 0.7, "chance": 0.1}]]},
	"tresor": {"icon": "🗺", "text": "Ils trouvent une vieille carte au trésor.", "options": [
		["Suivre la carte (+1 min)", {"time": 60.0, "extra": [["lingot_or", 2], ["piece_or", 25]]}],
		["La rapporter au village", {"extra": [["piece_or", 5]]}]]},
}
## Trouvailles rares au retour d'une expédition réussie (10 % de chances).
const RARE_FINDS := ["gemme_diamant", "gemme_rubis", "gemme_saphir", "cristal_aube", "perle", "orichalque"]
const ORDER := ["cueillette", "peche", "chasse", "mine", "escorte", "ruines", "repaire"]

signal changed

## Expéditions en cours : {mission, members (Villager), names, left, total, chance}.
var active: Array = []
## Derniers retours (texte), le plus récent en premier.
var history: Array = []
var done := 0
## Expéditions d'une sauvegarde, en attente des habitants (rechargés par leur nom).
var _pending: Array = []


func _ready() -> void:
	add_to_group("expeditions")
	if not SaveGame.expeditions_state.is_empty():
		import_state(SaveGame.expeditions_state)
		SaveGame.expeditions_state = {}


static func max_active(tree: SceneTree) -> int:
	var k := tree.get_first_node_in_group("kingdom")
	var r: int = k.rank if k else 0
	return MAX_ACTIVE[clampi(r, 0, MAX_ACTIVE.size() - 1)]


## Habitants libres pour partir (ni compagnons, ni déjà en route, ni K.O.).
func available() -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("villagers"):
		if not v.get("companion") and not v.has_meta("expedition") and v.is_alive() and not v.has_meta("story"):
			out.append(v)
	return out


## Force d'un habitant pour cette mission (niveau, classe, métier).
static func member_power(v: Node, mission_id: String) -> float:
	var m: Dictionary = MISSIONS[mission_id]
	var pw := 1.0 + 0.15 * float(v.get("level"))
	var mult := 1.0
	if m.classes.has(v.get("fight_class")):
		mult += 0.4
	var talents: Dictionary = v.get("talents")
	for j in m.jobs:
		mult += 0.6 * float(talents.get(j, 0.0))
	return pw * mult


## Chance de réussite (0 à 0,95) d'un groupe.
static func chance(mission_id: String, members: Array) -> float:
	if members.is_empty():
		return 0.0
	var m: Dictionary = MISSIONS[mission_id]
	var power := 0.0
	var healer := false
	var tank := false
	for v in members:
		power += member_power(v, mission_id)
		var role: String = v.call("class_role") if v.has_method("class_role") else ""
		healer = healer or role in ["soin", "chant"]
		tank = tank or role == "rempart"
	var need := float(m.diff) * 3.0
	var c := 0.2 + 0.6 * power / need
	if healer:
		c += 0.12
	if tank:
		c += 0.08
	if mission_id == "repaire" and not (healer and tank):
		c *= 0.6
	return clampf(c, 0.05, 0.95)


func can_start(mission_id: String, members: Array) -> String:
	if not MISSIONS.has(mission_id):
		return "Mission inconnue."
	if members.is_empty():
		return "Choisis au moins un habitant."
	if members.size() > MAX_PARTY:
		return "Au plus %d habitants par expédition." % MAX_PARTY
	if active.size() >= max_active(get_tree()):
		return "Déjà %d expédition%s en cours (plus avec un royaume plus grand)." % [active.size(), "s" if active.size() > 1 else ""]
	for v in members:
		if v.has_meta("expedition"):
			return "%s est déjà en route." % v.get("villager_name")
	return ""


func start(mission_id: String, members: Array) -> bool:
	if can_start(mission_id, members) != "":
		return false
	var m: Dictionary = MISSIONS[mission_id]
	var e := {"mission": mission_id, "members": members.duplicate(), "names": members.map(func(v): return v.get("villager_name")),
		"left": float(m.dur), "total": float(m.dur), "chance": chance(mission_id, members)}
	for v in members:
		_leave(v)
	active.append(e)
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.notify.emit("%s part : %s (%d %% de chances, retour dans %d s)." % [", ".join(PackedStringArray(e.names)), m.name, roundi(e.chance * 100), roundi(m.dur)])
	changed.emit()
	return true


## L'habitant quitte le village le temps de l'expédition.
func _leave(v: Node) -> void:
	v.set_meta("expedition", true)
	# il n'est plus au village : ni cible des monstres, ni bouche à nourrir (il reste sauvegardé)
	v.remove_from_group("villagers")
	v.add_to_group("away_villagers")
	v.visible = false
	v.process_mode = Node.PROCESS_MODE_DISABLED
	v.set_meta("exp_layer", v.collision_layer)
	v.collision_layer = 0


func _come_back(v: Node) -> void:
	if not is_instance_valid(v):
		return
	v.remove_meta("expedition")
	v.remove_from_group("away_villagers")
	v.add_to_group("villagers")
	v.visible = true
	v.process_mode = Node.PROCESS_MODE_INHERIT
	v.collision_layer = int(v.get_meta("exp_layer", 1))
	VoxelBurst.spawn(v, v.global_position + Vector3(0, 0.3, 0), Color("ffe08a"), 16, 2.5, 0.08, 0.8, "up", -1.0)


func _process(delta: float) -> void:
	if not _pending.is_empty():
		_resolve_pending()
	var i := 0
	while i < active.size():
		var e: Dictionary = active[i]
		e.left -= delta
		# à mi-chemin, peut-être un événement (une fois par expédition)
		if not e.get("event_done", false) and not e.has("event") and e.left < float(e.total) * 0.55:
			e.event_done = true
			if randf() < 0.7:
				trigger_event(e, EVENTS.keys().pick_random())
		if e.left <= 0.0:
			active.remove_at(i)
			finish(e)
			continue
		i += 1


## Un événement arrive à cette expédition : le joueur choisit dans le panneau des expéditions.
func trigger_event(e: Dictionary, id: String) -> void:
	e.event = id
	e.event_done = true
	var p := get_tree().get_first_node_in_group("player")
	if p:
		var ev: Dictionary = EVENTS[id]
		p.notify.emit("Expédition (%s) : %s %s Que faire ? (U → Expéditions)" % [", ".join(PackedStringArray(e.names)), ev.icon, ev.text])
		Sound.ui("ui_open")
	changed.emit()


## Le choix du joueur (ou le choix prudent au retour) pour l'événement en cours.
func choose(e: Dictionary, idx: int) -> void:
	if not e.has("event"):
		return
	var ev: Dictionary = EVENTS[e.event]
	var opt: Array = ev.options[clampi(idx, 0, ev.options.size() - 1)]
	var fx: Dictionary = opt[1]
	e.chance = clampf(float(e.chance) + float(fx.get("chance", 0.0)), 0.05, 0.97)
	e.mult = float(e.get("mult", 1.0)) * float(fx.get("loot", 1.0))
	e.left = maxf(1.0, float(e.left) + float(fx.get("time", 0.0)))
	e.total = maxf(float(e.total), float(e.left))
	if fx.has("extra"):
		e.extra = Array(e.get("extra", [])) + fx.extra
	if fx.get("recruit", false):
		e.recruit = true
	e.choice = opt[0]
	e.erase("event")
	changed.emit()


## Fin d'une expédition : succès ou échec, butin et retour des habitants.
func finish(e: Dictionary, forced_roll := -1.0) -> Dictionary:
	if e.has("event"):
		choose(e, 1)
	var m: Dictionary = MISSIONS[e.mission]
	var members: Array = e.members.filter(func(v): return is_instance_valid(v))
	var ok: bool = (forced_roll if forced_roll >= 0.0 else randf()) < float(e.chance)
	var p := get_tree().get_first_node_in_group("player")
	var lv := 0.0
	for v in members:
		lv += float(v.get("level"))
	lv /= maxf(1.0, members.size())
	var mult: float = (1.0 + 0.25 * (members.size() - 1) + 0.03 * lv) * (1.0 if ok else 0.3) * float(e.get("mult", 1.0))
	var got := []
	for pair in m.loot:
		var it := Items.get_item(pair[0])
		var n := roundi(float(pair[1]) * mult * randf_range(0.8, 1.2))
		if it and n > 0:
			got.append([it, n])
	if int(m.gold) > 0:
		var g := Items.get_item("piece_or")
		var n := roundi(float(m.gold) * mult * (1.0 + lv * 0.1))
		if g and n > 0:
			got.append([g, n])
	var rare := ""
	if ok:
		for pair in e.get("extra", []):
			var it := Items.get_item(pair[0])
			if it:
				got.append([it, int(pair[1])])
		if randf() < 0.1:
			var rf := Items.get_item(RARE_FINDS.pick_random())
			if rf:
				got.append([rf, 1])
				rare = rf.display_name
		if e.get("recruit", false):
			_bring_traveler(members)
	var parts := []
	for pair in got:
		if p:
			p.inventory.add(pair[0], pair[1])
		parts.append("%d %s" % [pair[1], (pair[0] as ItemData).display_name])
	for v in members:
		_come_back(v)
		if ok:
			v.set("happiness", minf(100.0, float(v.get("happiness")) + 10.0))
			if randf() < 0.6:
				v.call("set_level", int(v.get("level")) + 1)
		else:
			v.set("happiness", maxf(0.0, float(v.get("happiness")) - 15.0))
			v.health.current = maxi(1, roundi(v.health.max_health * 0.3))
	done += 1
	var txt := "%s %s : %s — %s" % [m.icon, m.name, "réussite" if ok else "échec (des blessés)", ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "rien"]
	if rare != "":
		txt += "  ·  Trouvaille rare : %s !" % rare
	history.push_front(txt)
	if history.size() > 6:
		history.resize(6)
	if p:
		p.notify.emit("Retour d'expédition · " + txt)
		Sound.ui("levelup" if ok else "ui_close")
	changed.emit()
	return {"ok": ok, "loot": got, "rare": rare}


## Le voyageur sauvé pendant l'expédition arrive au village : il rejoint sans rien demander (parle-lui).
func _bring_traveler(members: Array) -> void:
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or world.villager_scene == null:
		return
	var v := world.villager_scene.instantiate() as Villager
	v.stranger = true
	v.race = world.villager_races[randi() % world.villager_races.size()] if not world.villager_races.is_empty() else null
	v.villager_name = Villager.NAMES[randi() % Villager.NAMES.size()]
	v.level = randi_range(2, 5)
	var jobs := Villager.JOBS.duplicate()
	jobs.shuffle()
	v.talents = {jobs[0]: randf_range(0.5, 0.75), jobs[1]: randf_range(0.15, 0.3)}
	v.recruit_offer = {"items": [], "text": "Tes gens m'ont sauvé la vie. Je veux vivre ici, avec eux."}
	v.set_meta("attracted", true)
	v.wander_radius = 2.0
	world.get_node("Village").add_child(v)
	var pos := world.home_center() + Vector3(2.5, 0, 2.5)
	pos.y = world.ground_height_at(pos + Vector3(0, 3, 0))
	v.global_position = pos
	v.home = pos
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.notify.emit("%s, le voyageur sauvé par l'expédition, attend au feu de camp : parle-lui ({interact}) pour qu'il s'installe." % v.villager_name)


func export_state() -> Dictionary:
	return {"active": active.map(func(e): return {"mission": e.mission, "names": e.names, "left": e.left, "total": e.total, "chance": e.chance,
		"mult": e.get("mult", 1.0), "extra": e.get("extra", []), "recruit": e.get("recruit", false), "event": e.get("event", ""), "event_done": e.get("event_done", false)}),
		"log": history, "done": done}


func import_state(d: Dictionary) -> void:
	history = Array(d.get("log", []))
	done = int(d.get("done", 0))
	_pending = Array(d.get("active", []))


## Après un chargement : les membres sont retrouvés par leur nom et repartent.
func _resolve_pending() -> void:
	var vs := get_tree().get_nodes_in_group("villagers")
	if vs.is_empty():
		return
	for pe in _pending:
		var members := []
		for nm in pe.get("names", []):
			for v in vs:
				if v.get("villager_name") == nm and not v.has_meta("expedition") and not members.has(v):
					members.append(v)
					break
		if members.is_empty() or not MISSIONS.has(str(pe.mission)):
			continue
		for v in members:
			_leave(v)
		var ne := {"mission": str(pe.mission), "members": members, "names": members.map(func(v): return v.get("villager_name")),
			"left": float(pe.left), "total": float(pe.total), "chance": float(pe.chance), "mult": float(pe.get("mult", 1.0)),
			"extra": Array(pe.get("extra", [])), "recruit": bool(pe.get("recruit", false)), "event_done": bool(pe.get("event_done", false))}
		if str(pe.get("event", "")) != "" and EVENTS.has(str(pe.event)):
			ne.event = str(pe.event)
		active.append(ne)
	_pending = []
	changed.emit()
