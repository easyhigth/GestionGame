class_name CityLife
extends Node3D
## La vie des capitales : quand le héros approche d'une ville, ses rues s'animent (citadins de ses peuples,
## marchands à leurs étals, gardes aux portes, souverain devant son palais) ; quand il s'éloigne, ils disparaissent.
## Seuls quelques dizaines d'habitants sont animés à la fois : la population de la ville (des centaines) est comptée.
## Un bandeau annonce la ville à l'entrée.

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
		if d < r:
			here = city.nation
	if here != _inside:
		_inside = here
		if here != "":
			_announce(_city(here))


func _city(nation: String) -> Dictionary:
	for c in world.cities:
		if c.nation == nation:
			return c
	return {}


func _announce(city: Dictionary) -> void:
	var nat: Dictionary = Diplomacy.NATIONS.get(city.nation, {})
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(city.name, "Capitale — %s\n%d habitants · %d marchands" % [nat.get("name", ""), int(city.population), (city.stalls as Array).size()],
			(nat.get("color", Color.WHITE) as Color).lightened(0.35))
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
	# deux gardes à chaque porte
	for g in city.gates:
		var gc: Vector2i = g
		var inward := Vector2(-gc.x, -gc.y).normalized()
		var side := Vector2(-inward.y, inward.x)
		for k in [-1, 1]:
			var c := gc + Vector2i(roundi(inward.x * 2.5 + side.x * 2.5 * k), roundi(inward.y * 2.5 + side.y * 2.5 * k))
			_add(holder, city, c, "guard", rng)
	_add(holder, city, city.hall, "lord", rng)
	# citadins le long des rues
	var streets: Array = city.streets
	for n in mini(ACTIVE_CITIZENS, streets.size()):
		_add(holder, city, streets[rng.randi() % streets.size()], "citizen", rng)


func _despawn(nation: String) -> void:
	var h: Node = _active.get(nation)
	_active.erase(nation)
	if h and is_instance_valid(h):
		h.queue_free()


## Nombre d'habitants animés dans une ville (pour les tests).
func active_count(nation: String) -> int:
	var h: Node = _active.get(nation)
	return h.get_child_count() if h and is_instance_valid(h) else 0
