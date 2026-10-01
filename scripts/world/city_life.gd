class_name CityLife
extends Node3D
## La vie des capitales : quand le héros approche d'une ville, ses rues s'animent (citadins de ses peuples,
## marchands à leurs étals, gardes aux portes, souverain devant son palais) ; quand il s'éloigne, ils disparaissent.
## Seuls quelques dizaines d'habitants sont animés à la fois : la population de la ville (des centaines) est comptée.
## Un bandeau annonce la ville à l'entrée.
## Selon la diplomatie : en guerre, des soldats hostiles gardent les portes ; pendant un siège (CitySiege), les rues
## se vident ; une capitale annexée arbore la bannière du royaume, a un gouverneur et son trésor devant le palais.

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


func _ready() -> void:
	add_to_group("city_life")


func _process(delta: float) -> void:
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
		elif _active.has(city.nation) and _states.get(city.nation, "") != state_of(city.nation):
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
	_states[city.nation] = st
	if st == "siège":
		return    # les habitants se sont barricadés
	var rng := RandomNumberGenerator.new()
	rng.seed = int(city.seed)
	var trade := get_tree().get_first_node_in_group("trade") as Trade
	# marchands à leurs étals (ils gardent leur stock d'une visite à l'autre)
	var shops: Dictionary = city.get("shops", {})
	city["shops"] = shops
	var i := 0
	for s in city.stalls:
		var m := _add(holder, city, s[0], "merchant", rng)
		m.trade_name = str(s[1])
		m.color = Color("ffe08a")
		if trade:
			if not shops.has(i):
				shops[i] = CityMerchant.new(trade, city, m.trade_name, m.display_name, rng)
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
	# citadins le long des rues
	var streets: Array = city.streets
	for n in mini(ACTIVE_CITIZENS, streets.size()):
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
	e.level = maxi(5, player.level + 1)
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


## Nombre d'habitants animés dans une ville (pour les tests).
func active_count(nation: String) -> int:
	var h: Node = _active.get(nation)
	return h.get_child_count() if h and is_instance_valid(h) else 0
