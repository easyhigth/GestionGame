class_name CityLife
extends Node3D
## La vie des capitales : quand le héros approche d'une ville, ses rues s'animent (citadins de ses peuples,
## marchands à leurs étals, gardes aux portes, souverain devant son palais) ; quand il s'éloigne, ils disparaissent.
## Seuls quelques dizaines d'habitants sont animés à la fois : la population de la ville (des centaines) est comptée.
## Un bandeau annonce la ville à l'entrée.
## Selon la diplomatie : en guerre, des soldats hostiles gardent les portes ; pendant un siège (CitySiege), les rues
## se vident ; une capitale annexée arbore la bannière du royaume, a un gouverneur et son trésor devant le palais.
## La nuit, le marché ferme, les rues se vident et s'éclairent de torches, les maisons de lanternes.
## Les maisons proches du héros sont meublées (lits, tables, tonneaux...). Chaque ville a sa taverne (dormir,
## manger) et deux citadins qui ont une quête (« ! »). Les stocks des marchands sont sauvegardés et se
## renouvellent chaque semaine.

## Citadins animés en même temps dans une ville.
const ACTIVE_CITIZENS := 40
const SPAWN_MARGIN := 50.0
const DESPAWN_MARGIN := 90.0
const SYLL := {
	"givre": [["Bjor", "Ulf", "Sig", "Hal", "Ey", "Thor", "Ing", "Ragn", "Sv", "Gud"], ["ric", "vald", "rid", "dis", "mund", "a", "grim", "hild", "olf"]],
	"sylvae": [["Ael", "Lin", "Fae", "Ith", "Ela", "Syl", "Mir", "Cael", "Ny"], ["wen", "dril", "thas", "riel", "lys", "nor", "iel", "ra"]],
	"sables": [["Ka", "Sa", "Ra", "Zah", "Ha", "Amr", "Na", "Fa", "Ish"], ["ssim", "rif", "mira", "kesh", "zad", "dir", "ra", "rim"]],
	"karg": [["Gro", "Urk", "Maz", "Gash", "Bol", "Shag", "Nar", "Lug", "Krag"], ["nak", "bag", "gul", "dush", "rok", "za", "mog", "th"]],
	"cendres": [["Azh", "Mal", "Vor", "Ser", "Ka", "Lil", "Bel", "Mor", "Ys"], ["oth", "zeth", "ra", "ius", "an", "ith", "phas", "ael"]],
}
const CITIZEN_LINES := {
	"givre": ["Le Jarl tient conseil dans le grand hall.", "L'hiver sera long : on remplit les greniers.", "Un bon manteau de laine vaut plus que l'or, ici.",
		"Nos guerriers chassent l'ours dans les cols.", "Bienvenue à Hrodgard, étranger. Garde ton épée au fourreau."],
	"sylvae": ["Écoute : même les pierres chantent, à Lothëlia.", "Les arbres se souviennent de ceux qui les abattent.",
		"Les jardins fleurissent toute l'année sur les hautes terrasses.", "Bienvenue, voyageur. Marche doucement."],
	"sables": ["Tout se vend au bazar, même les promesses !", "Le Sultan ne sort qu'à la fraîche.", "L'eau est plus chère que l'or, ici.",
		"Une caravane arrive de l'oasis ce soir.", "Approche, approche, les meilleurs prix du désert !"],
	"karg": ["La forge ne s'éteint jamais, à Gor-Karath.", "La force fait la loi. Tu as l'air faible.", "Hé, toi ! Tu veux te battre ?",
		"La Tour Noire voit tout.", "Bonne viande, bon fer : rien d'autre ne compte."],
	"cendres": ["La Citadelle veille sur les sept cercles.", "Ne lève pas les yeux vers la tour blanche trop longtemps.",
		"Les braises sous nos pieds ne refroidissent jamais.", "Le Prince récompense les ambitieux.", "Sept portes, sept serments."],
}
const GUARD_LINES := ["Halte ! Pas d'arme tirée dans la ville.", "Les marchands sont au marché, près de la grande porte.",
	"Circule, voyageur.", "Rien à signaler sur les remparts.", "Le souverain reçoit au palais, tout en haut."]

var world: WorldGenerator
var player: Player
## nation -> Node3D des habitants animés
var _active := {}
var _inside := ""
var _check := 0.0
var _races := {}
## nation -> état au moment où ses habitants ont été créés (« paix », « guerre », « siège », « province »)
var _states := {}
const NIGHT_CITIZENS := 10
const INN_PRICE := 12
const MEAL_PRICE := 5
const FURNISH_RADIUS := 34.0
const UNFURNISH_RADIUS := 50.0
## Lumières (lanternes, torches) allumées en même temps dans une ville.
const MAX_LIGHTS := 10
const RESTOCK_DAYS := 7
const QUEST_GIVERS := 2
const TAVERN_NAMES := ["Le Sanglier d'or", "La Chope fêlée", "Le Dragon assoupi", "L'Étoile du soir", "Le Tonneau joyeux"]
## Quêtes des citadins : « nation:numéro » -> {type, need, count, progress, state, gold, xp, next_day}
var quests := {}
var _saved_shops := {}
## nation -> {indice de maison: Node3D} (intérieurs meublés autour du héros)
var _interiors := {}
## nation -> Node3D des torches de rue allumées la nuit
var _lamps := {}
var _lamp_at := {}
var _furn_check := 0.0
var _lights_used := {}


func _ready() -> void:
	add_to_group("city_life")
	get_tree().node_added.connect(_on_node_added)
	if not SaveGame.city_life_state.is_empty():
		import_state(SaveGame.city_life_state)
		SaveGame.city_life_state = {}


func _day_cycle() -> Node:
	return get_tree().get_first_node_in_group("day_cycle")


func is_night() -> bool:
	var dc := _day_cycle()
	return dc != null and dc.is_night()


func today() -> int:
	var dc := _day_cycle()
	return int(dc.day) if dc else 1


## L'état qui décide du visage de la ville : diplomatie, et jour ou nuit.
func _look(nation: String) -> String:
	return state_of(nation) + ("/nuit" if is_night() else "")


func _process(delta: float) -> void:
	_furn_check -= delta
	if _furn_check <= 0.0 and world and player and is_instance_valid(player):
		_furn_check = 1.0
		for n in _active:
			_update_interiors(_city(n))
		for t in get_tree().get_nodes_in_group("townsfolk"):
			if t.quest_key != "":
				_refresh_mark(t)
	_check -= delta
	if _check > 0.0 or world == null or player == null or not is_instance_valid(player):
		return
	_check = 0.5
	var pp := player.global_position
	var here := ""
	for city in world.cities:
		var ctr: Vector2i = city.center
		var d := Vector2(pp.x - ctr.x, pp.z - ctr.y).length()
		var r := float(city.radius)
		var underground := pp.y < WorldGenerator.UNDERGROUND
		if not _active.has(city.nation) and d < r + SPAWN_MARGIN and not underground:
			_spawn(city)
		elif _active.has(city.nation) and (d > r + DESPAWN_MARGIN or underground):
			_despawn(city.nation)
		elif _active.has(city.nation) and _states.get(city.nation, "") != _look(city.nation):
			# la guerre est déclarée, la paix signée... : la ville change de visage
			_despawn(city.nation)
			_spawn(city)
		if d < r:
			here = city.nation
	if here != _inside:
		_inside = here
		if here != "":
			_announce(_city(here))


## « paix », « guerre », « siège » ou « province ».
func state_of(nation: String) -> String:
	var cs := get_tree().get_first_node_in_group("city_siege")
	if cs and cs.nation == nation:
		return "siège"
	var dip := get_tree().get_first_node_in_group("diplomacy") as Diplomacy
	if dip and dip.states.has(nation):
		if dip.annexed(nation):
			return "province"
		if dip.at_war(nation):
			return "guerre"
	return "paix"


## Recrée les habitants d'une ville (après un siège, une annexion...).
func refresh(nation: String) -> void:
	if not _active.has(nation):
		return
	_despawn(nation)
	var c := _city(nation)
	if not c.is_empty():
		_spawn(c)


func _city(nation: String) -> Dictionary:
	for c in world.cities:
		if c.nation == nation:
			return c
	return {}


func _announce(city: Dictionary) -> void:
	var nat: Dictionary = Diplomacy.NATIONS.get(city.nation, {})
	var hud := get_tree().get_first_node_in_group("hud")
	var st := state_of(city.nation)
	var line: String = {"paix": "Capitale — %s", "guerre": "Capitale ennemie — %s (en guerre !)", "siège": "Assiégée — %s",
		"province": "Province de ton royaume (ancienne capitale de %s)"}[st] % nat.get("name", "")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(city.name, "%s\n%d habitants · %d marchands" % [line, int(city.population), (city.stalls as Array).size()],
			Color("ff7a6a") if st == "guerre" or st == "siège" else (nat.get("color", Color.WHITE) as Color).lightened(0.35))
	Sound.ui("ui_open")


func _race(id: String) -> RaceData:
	if not _races.has(id):
		_races[id] = load("res://data/races/%s.tres" % id) as RaceData
	return _races[id]


func _name(nation: String, rng: RandomNumberGenerator) -> String:
	return random_name(nation, rng)


## Un prénom dans la langue d'une nation.
static func random_name(nation: String, rng: RandomNumberGenerator) -> String:
	var s: Array = SYLL.get(nation, SYLL.givre)
	return str(s[0][rng.randi() % s[0].size()]) + str(s[1][rng.randi() % s[1].size()])


## Position au sol (au-dessus du relief et des blocs franchissables) d'une case de la ville.
func _ground(cell: Vector2i) -> Vector3:
	var p := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
	p.y = world.terrain_height(cell)
	p.y = world.support_height(p, p.y + 0.3)
	return p


func _add(holder: Node3D, city: Dictionary, cell: Vector2i, role: String, rng: RandomNumberGenerator) -> Townsfolk:
	var t := Townsfolk.new()
	var races: Array = city.races
	t.race = _race(str(races[rng.randi() % races.size()]))
	t.role = role
	t.name = "%s_%d" % [role, holder.get_child_count()]
	t.home = _ground(world_cell(city, cell))
	t.display_name = _name(city.nation, rng)
	match role:
		"citizen":
			t.lines = CITIZEN_LINES.get(city.nation, [])
			t.wander = 12.0
			if rng.randf() < 0.3:
				t.kit = [["cape_red", "iron_helmet", "leather_armor"][rng.randi() % 3]]
		"guard":
			t.kit = ["sword_iron", "iron_helmet", "iron_armor"]
			t.lines = GUARD_LINES
			t.display_name = "Garde de " + str(city.name)
			t.wander = 3.0
		"lord":
			t.kit = ["cape_red", "iron_armor"]
			t.color = Color("f2c86a")
			t.display_name = {"givre": "Jarl ", "sylvae": "Dame ", "sables": "Sultan ", "karg": "Chef de guerre ", "cendres": "Prince "}.get(city.nation, "") \
				+ t.display_name
			t.lines = ["Bienvenue à %s, voyageur." % city.name, "Mon peuple compte %d âmes. Respecte-les." % int(city.population),
				"Les relations entre nos peuples se règlent au panneau de la diplomatie de ton royaume."]
	holder.add_child(t)
	t.global_position = t.home
	return t


func world_cell(city: Dictionary, rel: Vector2i) -> Vector2i:
	return (city.center as Vector2i) + rel


func _spawn(city: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Ville_" + str(city.nation)
	add_child(holder)
	_active[city.nation] = holder
	var st := state_of(city.nation)
	_states[city.nation] = _look(city.nation)
	if st == "siège":
		return    # les habitants se sont barricadés
	var night := is_night()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(city.seed)
	var trade := get_tree().get_first_node_in_group("trade") as Trade
	# marchands à leurs étals (ils gardent leur stock d'une visite à l'autre)
	var shops: Dictionary = city.get("shops", {})
	city["shops"] = shops
	var i := 0
	var day := today()
	for s in city.stalls:
		# la nuit, le marché est fermé (le stock attend le lendemain)
		if night:
			if trade and not shops.has(i):
				shops[i] = CityMerchant.new(trade, city, str(s[1]), _name(city.nation, rng), rng)
				shops[i].day = day
			i += 1
			continue
		var m := _add(holder, city, s[0], "merchant", rng)
		m.trade_name = str(s[1])
		m.color = Color("ffe08a")
		if trade:
			if not shops.has(i):
				shops[i] = CityMerchant.new(trade, city, m.trade_name, m.display_name, rng)
				shops[i].day = day
				var saved: Dictionary = (_saved_shops.get(city.nation, {}) as Dictionary).get(str(i), {})
				if not saved.is_empty():
					shops[i].import_state(saved)
			# réassort chaque semaine
			if day - int(shops[i].day) >= RESTOCK_DAYS:
				var seller: String = shops[i].seller_name
				shops[i] = CityMerchant.new(trade, city, m.trade_name, seller, rng)
				shops[i].day = day
			m.shop = shops[i]
			m.display_name = (shops[i] as CityMerchant).seller_name
		m.lines = ["Approche ! Le meilleur %s de %s !" % [m.trade_name.to_lower(), city.name], "Regarde, regarde, tout est de première qualité."]
		i += 1
	# deux gardes à chaque porte (des soldats hostiles en temps de guerre)
	for g in city.gates:
		var gc: Vector2i = g
		var inward := Vector2(-gc.x, -gc.y).normalized()
		var side := Vector2(-inward.y, inward.x)
		for k in [-1, 1]:
			var c := gc + Vector2i(roundi(inward.x * 2.5 + side.x * 2.5 * k), roundi(inward.y * 2.5 + side.y * 2.5 * k))
			if st == "guerre":
				_add_soldier(holder, city, c, rng)
			else:
				var gd := _add(holder, city, c, "guard", rng)
				if st == "province":
					gd.display_name = "Garde de " + _kingdom_name()
					gd.lines = ["Gloire à notre souverain !", "La ville est calme depuis l'annexion.", "Les marchands te font de bons prix, maintenant."]
	var lord := _add(holder, city, city.hall, "lord", rng)
	if st == "province":
		lord.display_name = "Gouverneur " + _name(city.nation, rng)
		lord.lines = ["%s est fière d'être une province de ton royaume." % city.name, "Les impôts rentrent bien, seigneur.",
			"Le trésor de la ville t'attend devant le palais."]
		_add_province_marks(holder, city)
	elif st == "guerre":
		lord.lines = ["Tu oses venir ici, alors que nos peuples sont en guerre ?", "Mes soldats t'attendent aux portes.",
			"Assiège ma ville si tu l'oses (panneau de la diplomatie)."]
	# la taverne et son aubergiste, devant la porte
	var tv := tavern_of(city)
	if not tv.is_empty():
		var inn := _add(holder, city, tv.door, "innkeeper", rng)
		inn.display_name = "Aubergiste"
		inn.trade_name = "« %s »" % tv.name
		inn.color = Color("ffb870")
		var plate := Label3D.new()
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.text = "Taverne\n« %s »" % tv.name
		plate.font_size = 40
		plate.pixel_size = 0.008
		plate.outline_size = 10
		plate.modulate = Color("ffcf7a")
		holder.add_child(plate)
		plate.global_position = _ground(world_cell(city, tv.door)) + Vector3(0, 3.6, 0)
	# des citadins qui ont besoin d'aide (pas avec un ennemi)
	if st != "guerre":
		for k in QUEST_GIVERS:
			var qrng := RandomNumberGenerator.new()
			qrng.seed = hash([int(city.seed), k, 77])
			var streets0: Array = city.streets
			var qc: Vector2i = streets0[(k * 37 + 11) % streets0.size()]
			var qt := _add(holder, city, qc, "citizen", qrng)
			qt.quest_key = "%s:%d" % [city.nation, k]
			qt.display_name = _name(city.nation, qrng)
			_refresh_mark(qt)
	# citadins le long des rues (moins nombreux la nuit)
	var streets: Array = city.streets
	for n in mini(NIGHT_CITIZENS if night else ACTIVE_CITIZENS, streets.size()):
		_add(holder, city, streets[rng.randi() % streets.size()], "citizen", rng)


func _kingdom_name() -> String:
	var her := get_tree().get_first_node_in_group("heraldry")
	if her and str(her.get("custom_name")) != "":
		return str(her.custom_name)
	return "ton royaume"


## Un soldat ennemi qui garde une porte (en temps de guerre).
func _add_soldier(holder: Node3D, city: Dictionary, cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var army: Dictionary = Diplomacy.NATIONS[city.nation].army
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.data = load("res://data/enemies/%s.tres" % army.types[rng.randi() % army.types.size()])
	e.level = maxi(5, player.power_level() + 1)
	e.power = 1.0 + 0.06 * e.level
	e.set_meta("city_guard", city.nation)
	holder.add_child(e)
	e.global_position = _ground(world_cell(city, cell))
	e.home = e.global_position


## Province : les bannières du royaume aux portes et devant le palais, et le trésor de la ville.
func _add_province_marks(holder: Node3D, city: Dictionary) -> void:
	var her := get_tree().get_first_node_in_group("heraldry")
	var c1: Color = her.primary_color() if her else Color("8a1e2e")
	var c2: Color = her.secondary_color() if her else Color("e0b030")
	var em: String = her.emblem_char() if her else "♛"
	for g in city.gates:
		var gc: Vector2i = g
		var out := Vector2(gc).normalized()
		for k in [-1, 1]:
			var side: Vector2 = Vector2(-out.y, out.x) * 3.0 * k
			var b := make_banner(c1, c2, em)
			holder.add_child(b)
			b.global_position = _ground(world_cell(city, gc + Vector2i(roundi(out.x * 2.0 + side.x), roundi(out.y * 2.0 + side.y))))
	var hall: Vector2i = city.hall
	for k in [-2, 2]:
		var b := make_banner(c1, c2, em)
		holder.add_child(b)
		b.global_position = _ground(world_cell(city, hall + Vector2i(k, 1)))
	var chest := WorldChest.new()
	chest.chest_id = "capital_" + str(city.nation)
	chest.kind = "capital"
	chest.opened = world.opened_chests.has(chest.chest_id)
	holder.add_child(chest)
	chest.global_position = _ground(world_cell(city, hall + Vector2i(0, 2)))


## Un étendard aux couleurs du royaume : un mât, une toile, l'emblème.
static func make_banner(c1: Color, c2: Color, emblem: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Banniere"
	root.add_to_group("province_banners")
	var pole := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.14, 4.6, 0.14)
	pole.mesh = pm
	pole.position.y = 2.3
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3a22")
	pole.material_override = wood
	root.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.3, 2.0, 0.06)
	cloth.mesh = cm
	cloth.position = Vector3(0.72, 3.4, 0)
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = c1
	cloth.material_override = m1
	root.add_child(cloth)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.32, 0.25, 0.07)
	band.mesh = bm
	band.position = Vector3(0.72, 2.5, 0)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = c2
	band.material_override = m2
	root.add_child(band)
	for z in [0.05, -0.05]:
		var l := Label3D.new()
		l.text = emblem
		l.font_size = 96
		l.pixel_size = 0.008
		l.modulate = c2
		l.outline_size = 0
		l.position = Vector3(0.72, 3.5, z)
		l.rotation.y = 0.0 if z > 0 else PI
		root.add_child(l)
	return root


func _despawn(nation: String) -> void:
	var h: Node = _active.get(nation)
	_active.erase(nation)
	if h and is_instance_valid(h):
		h.queue_free()
	for n in (_interiors.get(nation, {}) as Dictionary).values():
		if is_instance_valid(n):
			n.queue_free()
	_interiors.erase(nation)
	var l: Node = _lamps.get(nation)
	if l and is_instance_valid(l):
		l.queue_free()
	_lamps.erase(nation)
	_lamp_at.erase(nation)


## Nombre d'habitants animés dans une ville (pour les tests).
func active_count(nation: String) -> int:
	var h: Node = _active.get(nation)
	return h.get_child_count() if h and is_instance_valid(h) else 0


# ---------------------------------------------------------------- taverne

## La taverne d'une ville : la maison la plus proche du marché (hors palais).
## {index, door (case devant la porte, relative au centre), name} ou {}.
func tavern_of(city: Dictionary) -> Dictionary:
	if city.has("tavern"):
		return city.tavern
	var houses: Array = city.get("houses", [])
	var stalls: Array = city.stalls
	var best := -1
	var bd := INF
	var target: Vector2i = stalls[0][0] if not stalls.is_empty() else Vector2i.ZERO
	for i in houses.size():
		var h: Array = houses[i]
		if int(h[1]) * int(h[2]) > 90 or int(h[1]) < 5 or int(h[2]) < 5:
			continue
		var c := Vector2(h[0]) + Vector2(int(h[1]), int(h[2])) / 2.0
		var d := c.distance_to(Vector2(target))
		if d < bd:
			bd = d
			best = i
	var out := {}
	if best >= 0:
		out = {"index": best, "door": _door_outside(houses[best]), "name": TAVERN_NAMES[absi(int(city.seed)) % TAVERN_NAMES.size()]}
	city["tavern"] = out
	return out


## Case juste devant la porte d'une maison [coin, l, p, sol, porte].
static func _door_outside(h: Array) -> Vector2i:
	var o: Vector2i = h[0]
	var w: int = h[1]
	var d: int = h[2]
	match int(h[4]):
		0:
			return o + Vector2i(w / 2, d)
		1:
			return o + Vector2i(w / 2, -1)
		2:
			return o + Vector2i(w, d / 2)
	return o + Vector2i(-1, d / 2)


## E auprès de l'aubergiste : la nuit, une chambre jusqu'au matin ; le jour, un repas chaud.
func inn(p: Player, _t: Node) -> String:
	var gold_it := Items.get_item("piece_or")
	if is_night():
		if p.inventory.count(gold_it) < INN_PRICE:
			return "Une chambre, c'est %d pièces d'or. Reviens quand tu les auras !" % INN_PRICE
		var dc := _day_cycle()
		var msg: String = dc.sleep() if dc else ""
		if msg == "" or msg.begins_with("Impossible"):
			return msg if msg != "" else "Pas de chambre libre ce soir."
		p.inventory.remove(gold_it, INN_PRICE)
		p.hunger = Player.HUNGER_MAX
		Sound.ui("coins")
		p.notify.emit("Une nuit à la taverne (%d or) : tu te réveilles reposé et repu." % INN_PRICE)
		return "Bonne nuit, voyageur ! La chambre du fond est à toi."
	if p.inventory.count(gold_it) < MEAL_PRICE:
		return "Un repas chaud, c'est %d pièces d'or. Et une chambre, le soir venu." % MEAL_PRICE
	p.inventory.remove(gold_it, MEAL_PRICE)
	p.hunger = Player.HUNGER_MAX
	p.health.heal(roundi(p.health.max_health * 0.3))
	Sound.ui("coins")
	p.notify.emit("Un repas chaud à la taverne (%d or) : faim rassasiée." % MEAL_PRICE)
	return "Voilà, ragoût du jour et pain chaud ! Reviens ce soir pour une chambre."


# ---------------------------------------------------------------- intérieurs et lumières

func _update_interiors(city: Dictionary) -> void:
	if city.is_empty() or state_of(city.nation) == "siège":
		return
	var ins: Dictionary = _interiors.get(city.nation, {})
	_interiors[city.nation] = ins
	var ctr: Vector2i = city.center
	var pp := Vector2(player.global_position.x - ctr.x, player.global_position.z - ctr.y)
	var houses: Array = city.get("houses", [])
	var night := is_night()
	var tv := tavern_of(city)
	for i in houses.size():
		var h: Array = houses[i]
		var hc := Vector2(h[0]) + Vector2(int(h[1]), int(h[2])) / 2.0
		var d := hc.distance_to(pp)
		if d < FURNISH_RADIUS and not ins.has(i):
			ins[i] = _furnish(city, h, i == int(tv.get("index", -1)))
		elif d > UNFURNISH_RADIUS and ins.has(i):
			if is_instance_valid(ins[i]):
				ins[i].queue_free()
			ins.erase(i)
	_update_lights(city, ins, pp, night)


## Meuble une maison : un lit, une table et sa chaise, un tonneau, un coffre, une lanterne (une taverne : des tables).
func _furnish(city: Dictionary, h: Array, tavern: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Interieur"
	add_child(root)
	var o: Vector2i = (city.center as Vector2i) + (h[0] as Vector2i)
	var w: int = h[1]
	var d: int = h[2]
	var base := float(int(city.base) + int(h[3]))
	if w < 4 or d < 4:
		return root
	var door_in: Vector2i = _door_outside(h) + (city.center as Vector2i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([o.x, o.y, 5])
	var spots: Array = []
	if tavern:
		for x in range(2, w - 2, 2):
			spots.append([Vector2i(x, d / 2), "table"])
			spots.append([Vector2i(x, d / 2 + 1), "chaise"])
		spots.append_array([[Vector2i(1, 1), "tonneau"], [Vector2i(w - 2, 1), "tonneau"], [Vector2i(1, d - 2), "lanterne"],
			[Vector2i(w - 2, d - 2), "lanterne"], [Vector2i(2, 1), "tonneau"]])
	else:
		spots.append_array([[Vector2i(1, 1), "lit"], [Vector2i(w - 2, 1), "tonneau"], [Vector2i(w / 2, d / 2), "table"],
			[Vector2i(w / 2 + 1, d / 2), "chaise"], [Vector2i(1, d - 2), "coffre"], [Vector2i(w - 2, d - 2), "lanterne"]])
	var used := {}
	for sp in spots:
		var c: Vector2i = o + (sp[0] as Vector2i)
		if c.x <= o.x or c.y <= o.y or c.x >= o.x + w - 1 or c.y >= o.y + d - 1 or used.has(c):
			continue
		if c.distance_to(door_in) < 2.5:
			continue    # on laisse l'entrée libre
		var it := Items.get_item(sp[1]) as ItemData
		if it == null or it.furniture_model == null:
			continue
		used[c] = true
		var n := it.furniture_model.instantiate() as Node3D
		n.set_meta("furniture", sp[1])
		root.add_child(n)
		n.global_position = Vector3(c.x + 0.5, base, c.y + 0.5)
		n.rotation.y = rng.randi_range(0, 3) * PI * 0.5
	return root


## Les lumières : la nuit, les lanternes des maisons les plus proches et des torches le long des rues.
func _update_lights(city: Dictionary, ins: Dictionary, pp: Vector2, night: bool) -> void:
	var lamps: Node3D = _lamps.get(city.nation)
	var moved: bool = not _lamp_at.has(city.nation) or (_lamp_at[city.nation] as Vector2).distance_to(pp) > 8.0 \
		or bool(lamps.get_meta("night", false)) != night if lamps else true
	if not moved:
		return
	if lamps and is_instance_valid(lamps):
		lamps.queue_free()
	for root in ins.values():
		for n in (root as Node).get_children():
			for c in n.get_children():
				if c is OmniLight3D:
					c.queue_free()
	_lamp_at[city.nation] = pp
	lamps = Node3D.new()
	lamps.name = "Torches"
	lamps.set_meta("night", night)
	add_child(lamps)
	_lamps[city.nation] = lamps
	if not night:
		return
	var budget := MAX_LIGHTS
	# lanternes des maisons les plus proches
	var lanterns: Array = []
	for root in ins.values():
		for n in (root as Node).get_children():
			if n.get_meta("furniture", "") == "lanterne":
				lanterns.append(n)
	var ctr: Vector2i = city.center
	var hero := Vector3(pp.x + ctr.x, 0, pp.y + ctr.y)
	lanterns.sort_custom(func(a, b): return Vector2(a.global_position.x - hero.x, a.global_position.z - hero.z).length() < Vector2(b.global_position.x - hero.x, b.global_position.z - hero.z).length())
	for n in lanterns.slice(0, budget / 2):
		n.add_child(_light(Color(1.0, 0.72, 0.4), 6.0))
		budget -= 1
	# torches de rue
	var streets: Array = (city.streets as Array).duplicate()
	streets.sort_custom(func(a, b): return Vector2(a).distance_to(pp) < Vector2(b).distance_to(pp))
	var torch_it := Items.get_item("torche") as ItemData
	var placed: Array = []
	for st in streets:
		if budget <= 0:
			break
		var sv := Vector2(st)
		if placed.any(func(q): return (q as Vector2).distance_to(sv) < 7.0):
			continue
		placed.append(sv)
		var t: Node3D = torch_it.furniture_model.instantiate() if torch_it and torch_it.furniture_model else Node3D.new()
		lamps.add_child(t)
		t.global_position = _ground(world_cell(city, (st as Vector2i) + Vector2i(1, 1)))
		t.add_child(_light(Color(1.0, 0.65, 0.35), 9.0))
		budget -= 1


func _light(col: Color, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.4
	l.omni_range = rng
	l.position.y = 1.4
	return l


## Nombre de maisons meublées autour du héros (pour les tests).
func furnished_count(nation: String) -> int:
	return (_interiors.get(nation, {}) as Dictionary).size()


# ---------------------------------------------------------------- quêtes des citadins

## Le lieu d'une quête : une capitale (« nation:numéro ») ou un hameau (« hamlet:id »).
## {name, nation, center, radius, seed} ou {}.
func _place_of(key: String) -> Dictionary:
	var head := key.get_slice(":", 0)
	if head == "hamlet":
		if world:
			for st in world.structure_sites:
				if st.kind == "hamlet" and st.id == key.get_slice(":", 1):
					return {"name": st.name, "nation": st.nation, "center": st.cell, "radius": 16, "seed": int(st.seed)}
		return {}
	var city := _city(head)
	if city.is_empty():
		return {}
	return {"name": city.name, "nation": head, "center": city.center, "radius": int(city.radius), "seed": int(city.seed)}


func _quest(key: String) -> Dictionary:
	var q: Dictionary = quests.get(key, {})
	if not q.is_empty() and q.state == "done" and today() >= int(q.get("next_day", 0)):
		quests.erase(key)
		q = {}
	if q.is_empty():
		var city := _place_of(key)
		if city.is_empty():
			return {}
		var nation: String = city.nation
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([key, today(), int(city.seed)])
		if rng.randf() < 0.5 and Diplomacy.NATIONS.has(nation):
			var wants: Array = Diplomacy.NATIONS[nation].wants
			var wnt: Array = wants[rng.randi() % wants.size()]
			var it := Items.get_item(wnt[0]) as ItemData
			var n := maxi(1, int(ceil(int(wnt[1]) / 2.0)))
			var trade := get_tree().get_first_node_in_group("trade") as Trade
			var v := trade.value_of(it) if trade else 3.0
			q = {"type": "apporter", "need": wnt[0], "count": n, "progress": 0, "state": "offer",
				"gold": 15 + roundi(v * n * 1.6), "xp": 40 + 6 * n}
		else:
			var n := rng.randi_range(4, 8)
			q = {"type": "chasser", "need": "", "count": n, "progress": 0, "state": "offer", "gold": 20 + 9 * n, "xp": 60 + 10 * n}
		quests[key] = q
	return q


func _quest_text(q: Dictionary, city_name: String) -> String:
	if q.type == "apporter":
		var it := Items.get_item(q.need) as ItemData
		return "%d %s" % [int(q.count), it.display_name.to_lower() if it else str(q.need)]
	return "%d monstres autour de %s" % [int(q.count), city_name]


func _refresh_mark(t: Townsfolk) -> void:
	var q := _quest(t.quest_key)
	match str(q.get("state", "")):
		"offer":
			t.set_mark("!")
		"active":
			t.set_mark("?" if _quest_ready(q) else "…", Color("ffd24a") if _quest_ready(q) else Color(0.8, 0.8, 0.8))
		_:
			t.set_mark("")


func _quest_ready(q: Dictionary) -> bool:
	if q.type == "apporter":
		var it := Items.get_item(q.need)
		return it != null and player.inventory.count(it) >= int(q.count)
	return int(q.progress) >= int(q.count)


## E auprès d'un citadin qui a une quête : il la propose, puis la récompense quand c'est fait.
func quest_talk(p: Player, t: Node) -> String:
	var key: String = t.quest_key
	var q := _quest(key)
	if q.is_empty():
		return ""
	var city := _place_of(key)
	var nation: String = city.get("nation", "")
	var what := _quest_text(q, str(city.get("name", "")))
	var out := ""
	match str(q.state):
		"offer":
			q.state = "active"
			out = ("Voyageur ! Pourrais-tu m'apporter %s ? Je te paierai %d pièces d'or." if q.type == "apporter" else
				"Les routes ne sont plus sûres : abats %s, et je te paierai %d pièces d'or.") % [what, int(q.gold)]
			p.notify.emit("Quête de %s : %s." % [city.get("name", ""), what])
			Sound.ui("ui_open")
		"active":
			if _quest_ready(q):
				if q.type == "apporter":
					p.inventory.remove(Items.get_item(q.need), int(q.count))
				p.inventory.add(Items.get_item("piece_or"), int(q.gold))
				p.gain_xp(int(q.xp))
				var dip := get_tree().get_first_node_in_group("diplomacy") as Diplomacy
				if dip and nation != "" and dip.states.has(nation) and not dip.at_war(nation):
					dip._add_rel(nation, 6.0)
				q.state = "done"
				q.next_day = today() + 1
				Sound.ui("coins")
				p.notify.emit("Quête réussie : +%d or, +%d XP, amitié avec %s." % [int(q.gold), int(q.xp), Diplomacy.NATIONS.get(nation, {}).get("name", "tes voisins")])
				out = "Merci, du fond du cœur ! Voici ta récompense."
			else:
				out = "Il me faut toujours %s (%d / %d)." % [what, int(q.progress) if q.type == "chasser" else p.inventory.count(Items.get_item(q.need)), int(q.count)]
		_:
			out = "Merci encore pour ton aide ! Repasse demain, j'aurai peut-être autre chose."
	_refresh_mark(t)
	return out


## Les quêtes de chasse comptent les monstres abattus autour de leur ville.
func _on_node_added(n: Node) -> void:
	if n is Enemy and not n.has_meta("siege") and not n.has_meta("city_guard"):
		(n as Enemy).died_at.connect(_on_enemy_died)


func _on_enemy_died(pos: Vector3) -> void:
	if world == null:
		return
	for key in quests:
		var q: Dictionary = quests[key]
		if q.type != "chasser" or q.state != "active":
			continue
		var city := _place_of(key)
		if city.is_empty():
			continue
		var ctr: Vector2i = city.center
		if Vector2(pos.x - ctr.x, pos.z - ctr.y).length() < float(city.radius) + 160.0:
			q.progress = mini(int(q.progress) + 1, int(q.count))
			if int(q.progress) == int(q.count) and player:
				player.notify.emit("Quête de %s : c'est fait, retourne voir le citadin (« ? »)." % city.name)
	for t in get_tree().get_nodes_in_group("townsfolk"):
		if t.quest_key != "":
			_refresh_mark(t)


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	var shops := {}
	for c in world.cities if world else []:
		var sh: Dictionary = c.get("shops", {})
		if sh.is_empty():
			continue
		var d := {}
		for i in sh:
			d[str(i)] = (sh[i] as CityMerchant).export_state()
		shops[c.nation] = d
	# les boutiques jamais rouvertes depuis le chargement restent telles qu'elles étaient
	for n in _saved_shops:
		if not shops.has(n):
			shops[n] = _saved_shops[n]
	return {"shops": shops, "quests": quests.duplicate(true)}


func import_state(d: Dictionary) -> void:
	_saved_shops = (d.get("shops", {}) as Dictionary).duplicate(true)
	quests = (d.get("quests", {}) as Dictionary).duplicate(true)
	if world:
		for c in world.cities:
			c.erase("shops")
	for n in _active.keys():
		refresh(n)
