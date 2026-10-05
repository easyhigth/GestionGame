class_name QuestBoard
extends Node
## Quêtes des habitants. De temps en temps, un habitant a quelque chose à demander (« ! » au-dessus
## de lui) : on lui parle (E) pour accepter. Quand c'est fait, on revient le voir (« ? ») pour la récompense.
## Types : apporter des objets, chasser une bête marquée, activer un obélisque, défendre le village
## la nuit (créatures de la nuit vaincues), construire une pièce qui manque.
## Récompenses : or, expérience, bonheur ; après 3 quêtes, l'habitant devient un ami (cadeau rare).

signal changed
signal quest_completed(q: Dictionary)

const MAX_OFFERS := 3
const MAX_ACTIVE := 4


## Quêtes en cours possibles : 4, +1 par rang du royaume à partir du Village (7 au plus).
static func max_active(tree: SceneTree) -> int:
	var k := tree.get_first_node_in_group("kingdom")
	var r: int = k.rank if k else 0
	return mini(7, MAX_ACTIVE + maxi(0, r - 1))
const OFFER_EVERY := 75.0
## Quêtes réussies pour devenir ami.
const FRIEND_AT := 3
const RARE_GIFTS := ["sword_iron", "iron_armor", "shield_iron", "iron_helmet", "pioche_fer", "hache_fer", "cape_red", "cape_blue"]

## [objet, minimum, maximum, texte (%d = nombre), pièces d'or par objet]
const FETCH := [
	["bloc_planches", 8, 16, "Il me faut %d planches pour réparer ma cabane.", 0.5],
	["wood", 8, 15, "Tu pourrais me rapporter %d bûches pour le feu ?", 0.6],
	["stone", 6, 12, "J'ai besoin de %d cailloux pour un muret.", 0.7],
	["fiber", 6, 10, "Il me manque %d fibres pour tisser des paniers.", 0.7],
	["pain", 2, 4, "Les enfants ont faim : apporte-moi %d pains.", 3.0],
	["viande_cuite", 2, 4, "Ramène-moi %d viandes cuites pour la fête du village.", 4.0],
	["baies", 5, 10, "J'aimerais %d baies pour une tarte.", 1.0],
	["iron_ingot", 2, 4, "Le forgeron réclame %d lingots de fer.", 6.0],
	["or_brut", 1, 2, "Un peu d'or brut me porterait chance : %d, s'il te plaît.", 14.0],
]
## [type de pièce, texte]
const BUILD := [
	["taverne", "Il nous faudrait une taverne pour se retrouver le soir."],
	["temple", "Un temple apaiserait les esprits du village."],
	["maison", "Construis une maison de plus : on est à l'étroit."],
	["marche", "Un marché ferait venir les marchands."],
]

var quests: Array = []
var _next_id := 1
var _offer_timer := 20.0
var _check := 0.0


func _ready() -> void:
	add_to_group("quests")
	_connect_night.call_deferred()
	if not SaveGame.quest_state.is_empty():
		import_state.call_deferred(SaveGame.quest_state)
		SaveGame.quest_state = {}


func _connect_night() -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle")
	if dc and dc.has_signal("night_monster_killed") and not dc.night_monster_killed.is_connected(_on_night_kill):
		dc.night_monster_killed.connect(_on_night_kill)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _world() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world") as WorldGenerator


## Quête proposée ou en cours d'un habitant ({} s'il n'en a pas).
func quest_of(v: Node) -> Dictionary:
	for q in quests:
		if q.giver == v:
			return q
	return {}


func active() -> Array:
	return quests.filter(func(q): return q.state != "offer")


func offers() -> Array:
	return quests.filter(func(q): return q.state == "offer")


# ---------------------------------------------------------------- nouvelles quêtes

func _process(delta: float) -> void:
	_offer_timer -= delta
	if _offer_timer <= 0.0:
		_offer_timer = OFFER_EVERY
		if offers().size() < MAX_OFFERS:
			make_offer()
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update()


## Un habitant sans quête en propose une (renvoie la quête, ou {}).
func make_offer(forced_type := "") -> Dictionary:
	var needs := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	if needs == null:
		return {}
	var free := needs.members().filter(func(v): return quest_of(v).is_empty() and not v.has_meta("story"))
	if free.is_empty():
		return {}
	var v = free[randi() % free.size()]
	var types := ["apporter", "apporter", "apporter", "chasser", "chasser", "explorer", "défendre", "construire"]
	var type: String = forced_type if forced_type != "" else types[randi() % types.size()]
	var q := _generate(type, v)
	if q.is_empty() and forced_type == "":
		q = _generate("apporter", v)
	if q.is_empty():
		return {}
	quests.append(q)
	_mark(v)
	changed.emit()
	return q


func _generate(type: String, v: Node) -> Dictionary:
	var p := _player()
	var lv: int = p.power_level() if p else 1
	var q := {"id": _next_id, "type": type, "giver": v, "giver_name": v.villager_name, "state": "offer",
		"progress": 0, "count": 1, "need": "", "spot": Vector3.INF, "target": null, "base": 0}
	match type:
		"apporter":
			var f: Array = FETCH[randi() % FETCH.size()]
			var it := Items.get_item(f[0])
			if it == null:
				return {}
			var n := randi_range(f[1], f[2])
			q.need = f[0]
			q.count = n
			q.title = "Apporter %d %s" % [n, it.display_name.to_lower()]
			q.text = f[3] % n
			q.gold = 3 + roundi(n * float(f[4]))
			q.xp = 25 + lv * 8
		"chasser":
			var world := _world()
			if world == null:
				return {}
			var spot := _hunt_spot(world)
			if spot == Vector3.INF:
				return {}
			var r := world.region_at(spot)
			if r == null or r.enemies.is_empty():
				return {}
			var ed: EnemyData = r.enemies[randi() % r.enemies.size()]
			q.need = ed.resource_path
			q.spot = spot
			q.title = "Chasser : %s rôdeur" % ed.display_name
			q.text = "Un %s rôde %s du village et fait peur à tout le monde. Débarrasse-nous-en !" % [ed.display_name.to_lower(), _direction(world.home_center(), spot)]
			q.gold = 8 + lv * 3
			q.xp = 60 + lv * 12
		"explorer":
			var world := _world()
			if world == null:
				return {}
			var best := {}
			var best_d := INF
			var center := world.home_center()
			for z in world.zones:
				if (z.obelisk as Vector2i).x < 0 or z.obelisk_on:
					continue
				var d := world.cell_center(z.obelisk).distance_to(center)
				if d < best_d:
					best_d = d
					best = z
			if best.is_empty():
				return {}
			q.need = best.name
			q.spot = world.cell_center(best.obelisk)
			q.title = "Explorer : l'obélisque de %s" % best.name
			q.text = "On raconte qu'un obélisque ancien se dresse à %s, %s d'ici. Va l'éveiller et raconte-moi !" % [best.name, _direction(center, q.spot)]
			q.gold = 5 + lv * 2
			q.xp = 80 + lv * 10
		"défendre":
			q.count = 3
			q.title = "Défendre le village la nuit"
			q.text = "Les créatures de la nuit rôdent autour du village. Élimine-en 3 pour qu'on dorme tranquilles."
			q.gold = 10 + lv * 2
			q.xp = 70 + lv * 10
		"construire":
			var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
			var have := {}
			if k:
				for r in k.typed_rooms():
					var id: String = (r.type as RoomTypeData).id
					have[id] = int(have.get(id, 0)) + 1
			var options := BUILD.filter(func(b): return b[0] == "maison" or not have.has(b[0]))
			if options.is_empty():
				return {}
			var b: Array = options[randi() % options.size()]
			q.need = b[0]
			q.base = int(have.get(b[0], 0))
			q.title = "Construire : %s" % {"taverne": "une taverne", "temple": "un temple", "maison": "une maison", "marche": "un marché"}[b[0]]
			q.text = b[1] + " (Mode construction : B. Le royaume, U, dit ce qu'il faut dans la pièce.)"
			q.gold = 20 + lv * 3
			q.xp = 100 + lv * 12
	_next_id += 1
	return q


## Un endroit praticable à 25-45 m du village, pour la bête à chasser.
func _hunt_spot(world: WorldGenerator) -> Vector3:
	var center := world.home_center()
	for i in 20:
		var a := randf() * TAU
		var p := center + Vector3(cos(a), 0, sin(a)) * randf_range(25.0, 45.0)
		world.load_area(p)
		p.y = world.ground_height_at(p + Vector3(0, 4, 0))
		if world.is_walkable(p) and world.terrain_type(world.cell_at(p)) not in [WorldGenerator.WATER, WorldGenerator.DEEP]:
			return p
	return Vector3.INF


static func _direction(from: Vector3, to: Vector3) -> String:
	var d := to - from
	var a := rad_to_deg(atan2(d.x, -d.z))
	var names := ["au nord", "au nord-est", "à l'est", "au sud-est", "au sud", "au sud-ouest", "à l'ouest", "au nord-ouest"]
	return names[int(round(fposmod(a, 360.0) / 45.0)) % 8]


# ---------------------------------------------------------------- accepter, suivre, rendre

func accept(q: Dictionary) -> bool:
	if q.state != "offer" or active().size() >= max_active(get_tree()):
		return false
	q.state = "active"
	if q.type == "chasser":
		_spawn_target(q)
	if q.type == "construire":
		pass
	_mark(q.giver)
	Sound.ui("ui_open")
	changed.emit()
	return true


func abandon(q: Dictionary) -> void:
	if is_instance_valid(q.target):
		q.target.queue_free()
	quests.erase(q)
	if is_instance_valid(q.giver):
		_mark(q.giver)
	changed.emit()


## La bête à chasser : un monstre de la région, un peu plus fort, marqué d'une étoile.
func _spawn_target(q: Dictionary) -> void:
	var world := _world()
	if world == null or q.spot == Vector3.INF:
		return
	world.load_area(q.spot)
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.data = load(q.need)
	var z := world.zone_at(q.spot)
	var lv: Vector2i = z.get("level", Vector2i(1, 2))
	e.level = lv.y + 1
	e.power = 1.25
	e.set_meta("quest", q.id)
	add_child(e)
	e.global_position = q.spot
	e.home = q.spot
	var star := Label3D.new()
	star.text = "★ Cible de quête"
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.font_size = 40
	star.pixel_size = 0.008
	star.outline_size = 8
	star.modulate = Color("f2c86a")
	star.position.y = 2.6
	e.add_child(star)
	q.target = e
	e.defeated.connect(func():
		if quests.has(q):
			q.progress = 1
			q.state = "ready"
			_mark(q.giver)
			var p := _player()
			if p:
				p.notify.emit("Quête : la bête est vaincue ! Retourne voir %s." % q.giver_name)
			changed.emit())


func _on_night_kill() -> void:
	for q in quests:
		if q.type == "défendre" and q.state == "active":
			q.progress += 1
			if q.progress >= q.count:
				q.state = "ready"
				_mark(q.giver)
				var p := _player()
				if p:
					p.notify.emit("Quête : le village est à l'abri. Retourne voir %s." % q.giver_name)
			changed.emit()


## Avancement des quêtes (objets dans le sac, obélisque éveillé, pièce construite) et habitants partis.
func _update() -> void:
	var p := _player()
	var dirty := false
	for q in quests.duplicate():
		if not is_instance_valid(q.giver):
			# l'habitant a quitté le village
			if is_instance_valid(q.target):
				q.target.queue_free()
			quests.erase(q)
			dirty = true
			continue
		if q.state == "offer":
			continue
		var before: String = q.state
		match q.type:
			"apporter":
				var it := Items.get_item(q.need)
				q.progress = mini(p.inventory.count(it), q.count) if p and it else 0
				q.state = "ready" if q.progress >= q.count else "active"
			"explorer":
				var world := _world()
				if world:
					for z in world.zones:
						if z.name == q.need and z.obelisk_on:
							q.progress = 1
							q.state = "ready"
			"construire":
				var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
				if k:
					var n := k.typed_rooms().filter(func(r): return (r.type as RoomTypeData).id == q.need).size()
					if n > int(q.base):
						q.progress = 1
						q.state = "ready"
			"chasser":
				if q.state == "active" and not is_instance_valid(q.target):
					_spawn_target(q)
		if q.state != before:
			_mark(q.giver)
			dirty = true
	if dirty:
		changed.emit()


## Rend la quête : retire les objets demandés et donne la récompense. Renvoie le texte de récompense.
func turn_in(q: Dictionary) -> String:
	var p := _player()
	if q.state != "ready" or p == null:
		return ""
	if q.type == "apporter":
		var it := Items.get_item(q.need)
		if it == null or not p.inventory.remove(it, q.count):
			q.state = "active"
			return ""
	var parts := []
	var gold := Items.get_item("piece_or")
	if gold and int(q.gold) > 0:
		p.inventory.add(gold, int(q.gold))
		parts.append("%d pièces d'or" % int(q.gold))
	p.gain_xp(int(q.xp))
	parts.append("%d XP" % int(q.xp))
	var v = q.giver
	v.friendship = int(v.friendship) + 1
	v.happiness = minf(100.0, float(v.happiness) + 15.0)
	if v.friendship == FRIEND_AT:
		var gift := Items.get_item(RARE_GIFTS[randi() % RARE_GIFTS.size()])
		if gift:
			p.inventory.add(gift, 1)
			parts.append("un cadeau d'ami : %s" % gift.display_name)
		p.feat.emit("%s est maintenant ton ami !" % v.villager_name, Color("8ad66a"))
	quests.erase(q)
	_mark(v)
	Sound.ui("levelup")
	quest_completed.emit(q)
	changed.emit()
	return "Récompense : " + ", ".join(PackedStringArray(parts)) + "."


func _mark(v: Node) -> void:
	if not is_instance_valid(v):
		return
	var q := quest_of(v)
	var mark := ""
	if not q.is_empty():
		mark = {"offer": "!", "active": "…", "ready": "?"}[q.state]
	v.set_quest_mark(mark)


## Texte d'avancement (pour le suivi à l'écran).
func progress_text(q: Dictionary) -> String:
	var p := _player()
	var t := ""
	match q.type:
		"apporter", "défendre":
			t = "%d / %d" % [q.progress, q.count]
		_:
			t = "fait" if q.state == "ready" else ""
	if q.state == "ready":
		return "prêt · retourne voir %s" % q.giver_name
	if q.spot != Vector3.INF and p:
		var d: float = Vector2(q.spot.x - p.global_position.x, q.spot.z - p.global_position.z).length()
		t += ("  ·  " if t != "" else "") + "%d m %s" % [roundi(d), _direction(p.global_position, q.spot).trim_prefix("au ").trim_prefix("à l'").trim_prefix("à ")]
	return t


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	var list := []
	for q in quests:
		var d := {}
		for key in q:
			if key == "giver" or key == "target":
				continue
			d[key] = q[key]
		if q.spot != Vector3.INF:
			d.spot = [q.spot.x, q.spot.y, q.spot.z]
		else:
			d.spot = []
		list.append(d)
	return {"quests": list, "next": _next_id}


func import_state(d: Dictionary) -> void:
	for q in quests:
		if is_instance_valid(q.target):
			q.target.queue_free()
	quests.clear()
	_next_id = int(d.get("next", 1))
	var needs := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	var members: Array = needs.members() if needs else []
	for qd in d.get("quests", []):
		var giver = null
		for v in members:
			if v.villager_name == qd.giver_name and quest_of(v).is_empty():
				giver = v
				break
		if giver == null:
			continue
		var q: Dictionary = qd.duplicate()
		q.giver = giver
		q.target = null
		var sp: Array = qd.get("spot", [])
		q.spot = Vector3(float(sp[0]), float(sp[1]), float(sp[2])) if sp.size() == 3 else Vector3.INF
		for key in ["id", "progress", "count", "gold", "xp", "base"]:
			if q.has(key):
				q[key] = int(q[key])
		quests.append(q)
		if q.type == "chasser" and q.state == "active":
			_spawn_target(q)
		_mark(giver)
	changed.emit()
