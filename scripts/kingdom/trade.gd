class_name Trade
extends Node
## Commerce : un marchand ambulant arrive au village tous les quelques jours avec sa charrette
## et reste jusqu'au lendemain matin. E près de lui : acheter et vendre (pièces d'or).
## Son stock change à chaque visite selon la région d'où il vient. Vendre beaucoup du même objet
## fait baisser son prix. Un marché (pièce : 2 étals et un comptoir) le fait venir plus souvent,
## avec de meilleurs prix.

signal changed
signal arrived
signal left
signal sold(item_id: String, count: int, gold: int)
signal bought(item_id: String, count: int, gold: int)

## Jours entre deux visites (sans / avec marché), heure d'arrivée et de départ (le lendemain).
const VISIT_EVERY := 3
const VISIT_EVERY_MARKET := 2
const ARRIVE_HOUR := 8.0
const FIRST_VISIT_DAY := 2
## Le marchand revend deux fois le prix d'un objet ; il rachète au prix de l'objet.
const BUY_MULT := 2.0
const SELL_MULT := 1.0
## Avec un marché : achats moins chers, ventes mieux payées.
const MARKET_BUY := 0.85
const MARKET_SELL := 1.2
## Chaque objet vendu du même type fait baisser son prix (jusqu'à 40 %).
const SATURATION_STEP := 0.04
const SATURATION_MIN := 0.4

## Valeur (en pièces d'or) des matières premières ; les objets fabriqués valent leurs ingrédients (+30 %).
const VALUES := {
	"wood": 1.0, "stone": 1.0, "fiber": 0.6, "leather": 3.0, "iron_ore": 3.0, "or_brut": 8.0, "marbre_brut": 5.0,
	"baies": 0.6, "viande_crue": 2.0, "bloc_terre": 0.0, "bloc_sable": 0.2, "piece_or": 0.0,
	"graines_ble": 0.5, "ble": 1.0, "carotte": 1.0, "pomme_de_terre": 1.0,
	"oeuf": 1.0, "lait": 1.5, "laine": 2.0,
	"gardon": 1.5, "carpe": 2.5, "truite": 3.0, "saumon": 4.0, "brochet": 6.0, "anguille": 6.0, "omble": 6.0,
	"potion_soin": 6.0, "potion_force": 10.0, "potion_garde": 10.0, "potion_celerite": 10.0,
	"rune_force": 25.0, "rune_garde": 25.0, "rune_vie": 25.0, "rune_celerite": 25.0,
	"poisson_scorpion": 8.0, "poisson_lave": 20.0, "poisson_lune": 25.0, "perle": 15.0, "vieille_botte": 0.5,
	# ressources rares (elles valaient 1 pièce faute de recette)
	"mithril_brut": 30.0, "orichalque": 160.0, "ecaille_dragon": 90.0, "larme_esprit": 45.0, "sang_demon": 45.0,
	"fragment_brume": 35.0, "cristal_aube": 120.0,
	"gemme_rubis": 40.0, "gemme_saphir": 40.0, "gemme_emeraude": 40.0, "gemme_topaze": 40.0, "gemme_amethyste": 40.0, "gemme_diamant": 60.0,
	# ressources de l'arsenal et du catalogue de construction
	"minerai_cuivre": 2.0, "minerai_etain": 2.5, "minerai_argent": 7.0, "charbon": 1.5, "os": 1.0, "obsidienne": 25.0,
	"poussiere_arcane": 6.0, "pierre_ame": 120.0, "lazurite": 3.0, "quartz": 3.0, "prismarine": 3.0, "gravier": 0.2, "argile": 0.5,
	"granite": 0.8, "diorite": 0.8, "andesite": 0.8, "basalte": 0.8, "calcaire": 0.8,
	"bois_bouleau": 1.0, "bois_sapin": 1.0, "bois_acajou": 1.5, "bois_ebene": 2.0, "bois_cerisier": 1.5, "bois_acacia": 1.0,
	"bois_saule": 1.0, "bois_palmier": 1.0,
}
const CRAFT_BONUS := 1.3

## Ce que le marchand peut avoir : [catégorie, [identifiant, min, max], ...]
const GOODS := {
	"Graines": [["graines_ble", 6, 12], ["carotte", 4, 8], ["pomme_de_terre", 4, 8]],
	"Nourriture": [["oeuf", 4, 8], ["fromage", 2, 4], ["pain", 3, 6], ["viande_cuite", 2, 5], ["soupe_legumes", 1, 3], ["ragout", 1, 3]],
	"Matériaux": [["iron_ingot", 3, 6], ["leather", 3, 6], ["lingot_or", 1, 2], ["marbre_brut", 3, 6], ["bloc_verre", 6, 12], ["bloc_briques", 10, 20],
		["minerai_cuivre", 6, 12], ["minerai_etain", 4, 8], ["charbon", 6, 12], ["poussiere_arcane", 2, 5], ["teinture_bleu", 2, 4], ["teinture_rouge", 2, 4]],
	"Armes": [["arm_epee_fer_0", 1, 1], ["arm_hache_bronze_0", 1, 1], ["arm_lance_fer_0", 1, 1], ["arm_arc_bois_1", 1, 1], ["arm_dague_acier_2", 1, 1], ["arm_baton_argent_0", 1, 1]],
	"Outils": [["houe", 1, 1], ["canne_peche", 1, 1], ["pioche_pierre", 1, 1], ["hache_pierre", 1, 1], ["pioche_fer", 1, 1], ["hache_fer", 1, 1]],
	"Mobilier": [["lit", 1, 2], ["coffre", 1, 2], ["lanterne", 2, 3], ["etal", 2, 2], ["comptoir", 1, 1], ["table", 1, 1], ["mangeoire", 1, 1], ["barriere", 6, 12]],
}

var world: WorldGenerator
## Prochain jour de visite.
var next_day := FIRST_VISIT_DAY
## Jour où il repart (à ARRIVE_HOUR), -1 s'il n'est pas là.
var leave_day := -1
## Stock : [{"id", "n", "price"}]
var stock: Array = []
## Nombre d'objets vendus au marchand pendant cette visite (par identifiant).
var sold_count := {}
var origin := ""
var specialty := ""
var merchant: Node3D
var cart: Node3D
var _merchant_name := ""
var _merchant_race := ""
var _cart_pos := Vector3.INF
var _check := 0.0
var _values := {}


func _ready() -> void:
	add_to_group("trade")
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	if not SaveGame.trade_state.is_empty():
		import_state.call_deferred(SaveGame.trade_state)
		SaveGame.trade_state = {}


func _day_cycle() -> DayCycle:
	return get_tree().get_first_node_in_group("day_cycle") as DayCycle


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func is_here() -> bool:
	return leave_day >= 0


## Lysandre s'est installée au village (histoire) : visites plus fréquentes, meilleurs prix.
func lysandre() -> bool:
	var st := get_tree().get_first_node_in_group("story")
	return st != null and st.choices.get("lysandre", "") == "join"


func has_market() -> bool:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return false
	for r in k.typed_rooms():
		if (r.type as RoomTypeData).id == "marche":
			return true
	return false


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var dc := _day_cycle()
	if dc == null or world == null:
		return
	var now := dc.day + dc.hour / 24.0
	if is_here():
		if now >= leave_day + ARRIVE_HOUR / 24.0:
			depart()
		elif merchant == null or not is_instance_valid(merchant):
			_spawn()
	elif now >= next_day + ARRIVE_HOUR / 24.0:
		arrive()


# ---------------------------------------------------------------- visites

## Le marchand arrive (nouveau stock) et reste jusqu'au lendemain matin.
func arrive() -> void:
	var dc := _day_cycle()
	var today := dc.day if dc else next_day
	leave_day = today + 1
	sold_count.clear()
	_make_stock()
	_merchant_name = Villager.NAMES[randi() % Villager.NAMES.size()]
	_merchant_race = ""
	_cart_pos = Vector3.INF
	_spawn()
	Sound.ui("horn")
	var p := _player()
	if p:
		p.notify.emit("Un marchand ambulant arrive au village, venu de %s (spécialité : %s). Il repart demain matin." % [origin, specialty.to_lower()])
	arrived.emit()
	changed.emit()


## Le marchand repart ; il reviendra dans quelques jours.
func depart() -> void:
	var dc := _day_cycle()
	var today := dc.day if dc else leave_day
	leave_day = -1
	next_day = today + (VISIT_EVERY_MARKET if has_market() or lysandre() else VISIT_EVERY)
	_despawn()
	stock.clear()
	var p := _player()
	if p:
		p.notify.emit("Le marchand ambulant repart. Prochain passage : jour %d." % next_day)
	left.emit()
	changed.emit()


func _spawn() -> void:
	if world == null or world.villager_scene == null:
		return
	_despawn()
	if _cart_pos == Vector3.INF:
		_cart_pos = _find_spot()
	cart = Node3D.new()
	cart.name = "Charrette"
	var model := load("res://scenes/decor/merchant_cart.tscn") as PackedScene
	if model:
		cart.add_child(model.instantiate())
	var sign := Label3D.new()
	sign.text = "Marchand ambulant"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 44
	sign.pixel_size = 0.008
	sign.outline_size = 9
	sign.modulate = Color("ffe0a0")
	sign.position.y = 2.6
	cart.add_child(sign)
	world.get_node("Village").add_child(cart)
	cart.global_position = _cart_pos
	var to_fire := world.home_center() - _cart_pos
	cart.rotation.y = atan2(to_fire.x, to_fire.z) + PI * 0.5
	var v := world.villager_scene.instantiate() as Villager
	v.stranger = true
	v.set_meta("merchant", true)
	var races := world.villager_races
	if _merchant_race != "":
		v.race = load(_merchant_race)
	elif not races.is_empty():
		v.race = races[randi() % races.size()]
		_merchant_race = v.race.resource_path
	v.villager_name = _merchant_name
	v.level = 5
	v.wander_radius = 1.2
	world.get_node("Village").add_child(v)
	var front := _cart_pos + to_fire.normalized() * 1.8
	front.y = world.ground_height_at(front + Vector3(0, 3, 0))
	v.global_position = front
	v.home = front
	v.equipment.equip(Items.get_item("cape_red"))
	merchant = v
	VoxelBurst.spawn(world, _cart_pos + Vector3(0, 1, 0), Color(1.0, 0.85, 0.5), 20, 3.0, 0.1, 0.6, "up", 6.0, false)


func _despawn() -> void:
	for n in [merchant, cart]:
		if n and is_instance_valid(n):
			VoxelBurst.spawn(world, (n as Node3D).global_position + Vector3(0, 1, 0), Color(1.0, 0.85, 0.5), 14, 2.5, 0.1, 0.5, "up", 6.0, false)
			n.queue_free()
	merchant = null
	cart = null


## Une place libre et praticable près du feu de camp pour la charrette.
func _find_spot() -> Vector3:
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	var center := world.home_cell_or_spawn()
	for r in range(6, 14):
		for i in 24:
			var a := TAU * i / 24.0 + 0.3
			var c := center + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			var ok := true
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var n := c + Vector2i(dx, dz)
					var p := world.cell_center(n)
					if not world.is_walkable(p) or not world.build.column(n).is_empty() or not world.build.furniture_in(n).is_empty() \
							or world.village_prop_at(n, p.y) != null or (fm and fm.plots.has(n)) \
							or absf(world.terrain_height(n) - world.terrain_height(c)) > 0.6:
						ok = false
						break
				if not ok:
					break
			if ok:
				return world.cell_center(c)
	return world.cell_center(center + Vector2i(6, 0))


# ---------------------------------------------------------------- stock et prix

func _make_stock() -> void:
	stock.clear()
	# d'où il vient : une zone du monde (hors village), qui choisit sa spécialité et la qualité de l'équipement
	var zones := world.zones.filter(func(z): return z.dist > 0.0) if world else []
	var z: Dictionary = zones[randi() % zones.size()] if not zones.is_empty() else {}
	origin = z.get("name", "contrées lointaines")
	var cats := GOODS.keys()
	specialty = cats[absi(hash(origin)) % cats.size()] if not z.is_empty() else cats[randi() % cats.size()]
	var lv: int = (z.get("level", Vector2i(1, 3)) as Vector2i).y if not z.is_empty() else 3
	for cat in GOODS:
		var list: Array = GOODS[cat].duplicate()
		list.shuffle()
		var n := 3 if cat == specialty else 2
		for g in list.slice(0, n):
			var it := Items.get_item(g[0])
			if it == null:
				continue
			var count := randi_range(g[1], g[2]) * (2 if cat == specialty and it.max_stack > 1 else 1)
			stock.append({"id": it.id, "n": count, "cat": cat})
	# équipement : quelques pièces, plus rares si le marchand vient d'une zone difficile
	var eq := Items.all_equipment().filter(func(it): return value_of(it) > 0.0)
	eq.shuffle()
	var max_rarity := 1 if lv < 6 else (2 if lv < 14 else 3)
	var added := 0
	for it in eq:
		if (it as ItemData).rarity > max_rarity:
			continue
		stock.append({"id": it.id, "n": 1, "cat": "Équipement"})
		added += 1
		if added >= (4 if specialty == "Équipement" else 3):
			break
	for s in stock:
		s.price = buy_price(Items.get_item(s.id))


## Valeur d'un objet en pièces d'or (0 : le marchand n'en veut pas).
func value_of(it: ItemData, depth := 0) -> float:
	if it == null:
		return 0.0
	if _values.has(it.id):
		return _values[it.id]
	var v := 0.0
	# objet amélioré à la forge : la valeur de l'objet de base, plus son niveau et ses gemmes
	# butin de niveau : la valeur de la base selon son niveau d'objet et sa rareté
	if it.id.contains("#"):
		var spec := Loot.parse(it.id)
		v = value_of(Items.get_item(it.base_id), depth + 1) * (1.0 + float(spec[1]) / 40.0) * (1.0 + 0.6 * int(spec[2]))
		_values[it.id] = v
		return v
	if it.base_id != "":
		v = value_of(Items.get_item(it.base_id), depth + 1) * (1.0 + 0.25 * it.upgrade) + 40.0 * it.gems.size()
		# les enchantements comptent aussi (de plus en plus cher par rang)
		for e in it.enchants:
			v += 30.0 * pow(float(it.enchants[e]), 1.5)
		_values[it.id] = v
		return v
	if VALUES.has(it.id):
		v = VALUES[it.id]
	else:
		var r := _recipe_of(it)
		if r and depth < 6:
			for i in r.ingredients.size():
				v += value_of(r.ingredients[i], depth + 1) * r.amount_of(i)
			v = v * CRAFT_BONUS / maxf(1.0, r.result_count)
		elif it.is_equipment():
			v = 6.0 + it.power() * 2.5
		elif it.is_food():
			v = maxf(0.5, it.food / 8.0)
		else:
			v = 1.0
	if it.is_equipment():
		v *= 1.0 + 0.35 * it.rarity
	_values[it.id] = v
	return v


func _recipe_of(it: ItemData) -> RecipeData:
	for r in Items.recipes:
		if r.result == it or (r.result and r.result.id == it.id):
			return r
	return null


## Traités de commerce (voir Diplomacy) : meilleurs prix.
func _dip_mult(buying: bool) -> float:
	var dip := get_tree().get_first_node_in_group("diplomacy") as Diplomacy if is_inside_tree() else null
	if dip == null:
		return 1.0
	return dip.buy_mult() if buying else dip.sell_mult()


## Prix d'achat au marchand (pièces d'or).
func buy_price(it: ItemData) -> int:
	var v := value_of(it)
	if v <= 0.0:
		return 0
	# toujours plus cher que ce qu'il en donnerait (pas d'achat-revente gagnant)
	return maxi(sell_price(it, 0) + 1, ceili(v * BUY_MULT * (MARKET_BUY if has_market() else 1.0) * (0.9 if lysandre() else 1.0) * _dip_mult(true)))


## Prix de vente d'un exemplaire au marchand, compte tenu de ce qu'on lui a déjà vendu.
func sell_price(it: ItemData, already := -1) -> int:
	var v := value_of(it)
	if v <= 0.0 or it.id == "piece_or":
		return 0
	var n: int = int(sold_count.get(it.id, 0)) if already < 0 else already
	var sat := maxf(SATURATION_MIN, 1.0 - SATURATION_STEP * n)
	var mult := SELL_MULT * (MARKET_SELL if has_market() else 1.0) * (1.1 if lysandre() else 1.0) * _dip_mult(false)
	# les objets de moins d'une demi-pièce ne se vendent pas (planches...)
	if v * mult < 0.5:
		return 0
	return maxi(1, roundi(v * mult * sat))


func gold(p: Player) -> int:
	return p.inventory.count(Items.get_item("piece_or"))


## Achète `n` exemplaires d'une ligne du stock. Renvoie le texte d'erreur, ou « » si c'est fait.
func buy(p: Player, entry: Dictionary, n := 1) -> String:
	n = mini(n, int(entry.n))
	if n <= 0:
		return "Plus en stock."
	var cost: int = int(entry.price) * n
	if gold(p) < cost:
		return "Pas assez d'or (%d pièces, il en faut %d)." % [gold(p), cost]
	var it := Items.get_item(entry.id)
	p.inventory.remove(Items.get_item("piece_or"), cost)
	p.inventory.add(it, n)
	entry.n = int(entry.n) - n
	if entry.n <= 0:
		stock.erase(entry)
	Sound.ui("coins")
	bought.emit(it.id, n, cost)
	changed.emit()
	return ""


## Vend `n` exemplaires d'un objet du sac. Renvoie l'or gagné.
func sell(p: Player, it: ItemData, n := 1) -> int:
	n = mini(n, p.inventory.count(it))
	var total := 0
	var done := 0
	for i in n:
		var price := sell_price(it)
		if price <= 0:
			break
		if not p.inventory.remove(it, 1):
			break
		total += price
		done += 1
		sold_count[it.id] = int(sold_count.get(it.id, 0)) + 1
	if total > 0:
		p.inventory.add(Items.get_item("piece_or"), total)
		Sound.ui("coins")
		sold.emit(it.id, done, total)
		changed.emit()
	return total


## Texte court pour le panneau du royaume et le HUD.
func status_text() -> String:
	if is_here():
		return "Marchand ambulant au village (venu de %s) : il repart le jour %d au matin." % [origin, leave_day]
	return "Prochain passage du marchand ambulant : jour %d%s." % [next_day, " (marché : tous les 2 jours)" if has_market() else ""]


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"next": next_day, "leave": leave_day, "stock": stock.duplicate(true), "sold": sold_count.duplicate(),
		"origin": origin, "specialty": specialty, "name": _merchant_name, "race": _merchant_race,
		"cart": [_cart_pos.x, _cart_pos.y, _cart_pos.z] if _cart_pos != Vector3.INF else []}


func import_state(d: Dictionary) -> void:
	_despawn()
	next_day = int(d.get("next", FIRST_VISIT_DAY))
	leave_day = int(d.get("leave", -1))
	stock = []
	for s in d.get("stock", []):
		stock.append({"id": str(s.id), "n": int(s.n), "price": int(s.price), "cat": str(s.get("cat", ""))})
	sold_count = {}
	var sc: Dictionary = d.get("sold", {})
	for k in sc:
		sold_count[k] = int(sc[k])
	origin = str(d.get("origin", ""))
	specialty = str(d.get("specialty", ""))
	_merchant_name = str(d.get("name", "Marchand"))
	_merchant_race = str(d.get("race", ""))
	var c: Array = d.get("cart", [])
	_cart_pos = Vector3(c[0], c[1], c[2]) if c.size() == 3 else Vector3.INF
	if is_here():
		_spawn()
	changed.emit()
