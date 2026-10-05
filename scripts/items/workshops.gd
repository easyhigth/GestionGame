class_name Workshops
extends RefCounted
## Les ateliers de l'artisanat : chaque meuble d'artisan (établi, enclume, four...) a son propre menu, qui ne
## montre que ce qu'il sait faire. Sur soi (le sac), on ne fabrique que l'essentiel.
## Aussi : le carnet des recettes découvertes, « que faire avec cet objet ? », « comment l'obtenir ? »,
## et le classement des blocs de construction par forme puis par matière.

## Ateliers : identifiant du poste → [nom, icône (assets/ui/icon_*.png), phrase d'accueil].
const STATIONS := {
	"etabli": ["Établi", "house", "Outils, meubles, armes en bois, en os et en pierre."],
	"enclume": ["Enclume", "sword", "Armes et armures de métal, outils en fer, forge et renforcement."],
	"four": ["Four", "food", "Lingots, verre, terre cuite."],
	"table_tailleur": ["Table du tailleur", "shield", "Blocs de pierre taillée, dalles, escaliers, murets."],
	"feu": ["Feu de cuisson", "food", "Repas cuits."],
	"chaudron": ["Chaudron", "gem", "Potions et préparations."],
	"autel": ["Autel", "gem", "Enchantements et objets légendaires."],
	"meule": ["Meule", "coin", "Farine et pierres broyées."],
	"foyer_forge": ["Foyer de forge", "sword", "Alliages."],
}
## Meubles qui servent d'atelier sous un autre nom (le feu de camp et le four à pain cuisinent).
const ALIASES := {"feu_de_camp": "feu", "four_pain": "feu"}
## Ateliers qui font aussi les recettes d'un autre (le four et le foyer de forge cuisent les repas).
const ALSO := {"four": ["feu"], "foyer_forge": ["feu"]}
## Onglets propres à un atelier, en plus des catégories de ses recettes.
const EXTRA_TABS := {"enclume": ["Forge"], "autel": ["Enchantement"]}
## Formes des blocs de construction (préfixe de l'identifiant → nom), dans l'ordre affiché.
const SHAPES := [["bloc", "Blocs"], ["dalle", "Dalles"], ["escalier", "Escaliers"], ["muret", "Murets"],
	["barriere", "Barrières"], ["portillon", "Portillons"], ["pente", "Toits en pente"], ["autre", "Autres"]]


static func station_name(id: String) -> String:
	return str(STATIONS[id][0]) if STATIONS.has(id) else ("Sur soi" if id == "" else id)


## Atelier d'une recette ("" : sur soi).
static func station_of(r: RecipeData) -> String:
	if r.station != "":
		return r.station
	return "etabli" if r.needs_workbench else ""


## Cet atelier fait-il les recettes de `recipe_station` ?
static func serves(station: String, recipe_station: String) -> bool:
	return recipe_station == station or recipe_station in ALSO.get(station, [])


## Recettes faites à cet atelier ("" : celles qu'on fait sur soi).
static func recipes_at(station: String) -> Array:
	return Items.recipes.filter(func(r): return r.result != null and not r.result.has_meta("hidden") and serves(station, station_of(r)))


## Onglets d'un atelier : les catégories de ses recettes (dans un ordre fixe), plus ses onglets propres.
static func tabs_for(station: String) -> Array:
	var order := ["Outils", "Mobilier", "Construction", "Matériaux", "Cuisine", "Équipement", "Armurerie", "Armures", "Légendaire"]
	var present := {}
	for r in recipes_at(station):
		present[r.category] = true
	var out := []
	for c in order:
		if present.has(c):
			out.append(c)
	for c in present:
		if not out.has(c):
			out.append(c)
	out += EXTRA_TABS.get(station, [])
	return out


## L'atelier qui propose cet onglet (pour ouvrir directement « Forge », « Armurerie »...).
static func station_for_tab(tab: String) -> String:
	for st in EXTRA_TABS:
		if tab in EXTRA_TABS[st]:
			return st
	if tab in tabs_for(""):
		return ""
	var best := ""
	var best_n := 0
	for st in STATIONS:
		var n := recipes_at(st).filter(func(r): return r.category == tab).size()
		if n > best_n:
			best_n = n
			best = st
	return best


## Atelier à portée du héros (le plus proche), ou "".
static func station_near(p: Player, radius := 2.4) -> String:
	var grid := p.get_tree().get_first_node_in_group("build_grid") as BuildGrid
	var best := ""
	var best_d := radius
	if grid:
		for k in grid.furniture:
			var f: Dictionary = grid.furniture[k]
			var id: String = ALIASES.get(f.item.id, f.item.id)
			if not STATIONS.has(id):
				continue
			var d := Vector3(f.col.x + 0.5, f.base, f.col.y + 0.5).distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = id
	for w in p.get_tree().get_nodes_in_group("workbench"):
		var d2 := (w as Node3D).global_position.distance_to(p.global_position)
		if d2 < best_d:
			best_d = d2
			best = "etabli"
	# le feu de camp du village de départ
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world and not GameState.bare_start:
		var d3 := world.home_center().distance_to(p.global_position)
		if d3 < minf(best_d, 2.6):
			best = "feu"
	return best


## L'atelier de ce type le plus proche du héros : [position, distance] (ou [] s'il n'y en a pas).
static func nearest_station_pos(p: Player, station: String) -> Array:
	var grid := p.get_tree().get_first_node_in_group("build_grid") as BuildGrid
	var best := []
	var best_d := INF
	if grid:
		for k in grid.furniture:
			var f: Dictionary = grid.furniture[k]
			if ALIASES.get(f.item.id, f.item.id) != station:
				continue
			var pos := Vector3(f.col.x + 0.5, f.base, f.col.y + 0.5)
			var d := pos.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = [pos, d]
	if station == "etabli":
		for w in p.get_tree().get_nodes_in_group("workbench"):
			var d2 := (w as Node3D).global_position.distance_to(p.global_position)
			if d2 < best_d:
				best_d = d2
				best = [(w as Node3D).global_position, d2]
	return best


## « au nord-est », « au sud »... (direction de `to` vue de `from`).
static func direction_text(from: Vector3, to: Vector3) -> String:
	var d := to - from
	if Vector2(d.x, d.z).length() < 3.0:
		return "tout près"
	var a := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)
	var names := ["au nord", "au nord-est", "à l'est", "au sud-est", "au sud", "au sud-ouest", "à l'ouest", "au nord-ouest"]
	return names[int(round(a / 45.0)) % 8]


# ---------------------------------------------------------------- carnet de découvertes

## Une recette est connue quand le héros a déjà eu en main chacun de ses ingrédients.
static func is_known(p: Player, r: RecipeData) -> bool:
	for it in r.ingredients:
		if it and not p.seen_items.has(it.id):
			return false
	return true


## Note les objets du sac comme « vus » ; renvoie les recettes découvertes grâce à eux.
static func note_seen(p: Player) -> Array:
	var fresh := []
	for e in p.inventory.entries:
		var id: String = (e.item as ItemData).id
		if not p.seen_items.has(id):
			p.seen_items[id] = true
			fresh.append(id)
	if fresh.is_empty():
		return []
	var out := []
	for r in Items.recipes:
		if r.result == null or r.result.has_meta("hidden"):
			continue
		var uses_fresh := false
		for it in r.ingredients:
			if it and fresh.has(it.id):
				uses_fresh = true
				break
		if uses_fresh and is_known(p, r):
			out.append(r)
	return out


## Message « Nouvelles recettes : ... » (quelques noms, puis le nombre).
static func discovery_text(found: Array) -> String:
	var names := []
	for r in found.slice(0, 3):
		names.append(r.result.display_name)
	var more := found.size() - names.size()
	return "%s : %s%s" % ["Nouvelle recette" if found.size() == 1 else "%d nouvelles recettes" % found.size(),
		", ".join(PackedStringArray(names)), (" (+%d)" % more) if more > 0 else ""]


# ---------------------------------------------------------------- usages et sources

## Recettes (connues) qui utilisent cet objet.
static func uses_of(p: Player, item: ItemData) -> Array:
	return Items.recipes.filter(func(r):
		if r.result == null or r.result.has_meta("hidden") or not is_known(p, r):
			return false
		for it in r.ingredients:
			if it == item:
				return true
		return false)


static var _enemy_loot := {}


## Monstres qui lâchent cet objet (noms).
static func enemies_dropping(item: ItemData) -> Array:
	if _enemy_loot.is_empty():
		var dir := DirAccess.open("res://data/enemies")
		if dir:
			for f in dir.get_files():
				var path := "res://data/enemies/" + f.trim_suffix(".remap")
				if not path.ends_with(".tres"):
					continue
				var ed := load(path) as EnemyData
				if ed == null:
					continue
				for it in ed.loot:
					if it:
						var l: Array = _enemy_loot.get(it.id, [])
						if not l.has(ed.display_name):
							l.append(ed.display_name)
						_enemy_loot[it.id] = l
		_enemy_loot["_done"] = []
	return _enemy_loot.get(item.id, [])


## Où trouver cet objet : une liste de phrases (fabriqué à..., récolté sur..., lâché par..., vendu par...).
static func sources_of(item: ItemData) -> Array:
	var out := []
	var made := {}
	for r in Items.recipes:
		if r.result == item:
			made[station_name(station_of(r))] = true
	if not made.is_empty():
		out.append("Se fabrique : " + ", ".join(PackedStringArray(made.keys())).to_lower())
	var harvest := []
	var kind_names := {WorldGenerator.D_OAK: "les arbres", WorldGenerator.D_PINE: "les sapins", WorldGenerator.D_ROCK: "les rochers (pioche)",
		WorldGenerator.D_BUSH: "les buissons", WorldGenerator.D_GRASS: "les hautes herbes", WorldGenerator.D_FLOWERS: "les fleurs",
		WorldGenerator.D_IRON: "les filons de fer (pioche)", WorldGenerator.D_GOLD: "les filons d'or (pioche en fer)"}
	for k in Harvest.DECOR_LOOT:
		for l in Harvest.DECOR_LOOT[k]:
			if l[0] == item.id and not harvest.has(kind_names.get(k, "")):
				harvest.append(kind_names.get(k, ""))
	for k in Harvest.DECOR_BONUS:
		for l in Harvest.DECOR_BONUS[k]:
			if l[0] == item.id and not harvest.has(kind_names.get(k, "")):
				harvest.append(str(kind_names.get(k, "")) + (" (rare)" if float(l[1]) < 0.05 else ""))
	if item.id.begins_with("bois_"):
		harvest.append("les arbres de certaines régions")
	if not harvest.is_empty():
		out.append("Se récolte sur " + ", ".join(PackedStringArray(harvest)))
	for sp in FarmAnimal.SPECIES:
		var inf: Dictionary = FarmAnimal.SPECIES[sp]
		if inf.product == item.id:
			out.append("Produit par les %s nourris" % inf.plural)
		for l in inf.get("loot", []):
			if l[0] == item.id:
				out.append("Sur les %s abattus" % inf.plural)
				break
	var foes := enemies_dropping(item)
	if not foes.is_empty():
		out.append("Lâché par : " + ", ".join(PackedStringArray(foes.slice(0, 5))) + (" ..." if foes.size() > 5 else ""))
	for cat in Trade.GOODS:
		for g in Trade.GOODS[cat]:
			if g[0] == item.id:
				out.append("Vendu par le marchand ambulant")
				break
	if out.is_empty() and item.description != "":
		out.append(item.description)
	return out


# ---------------------------------------------------------------- construction : forme puis matière

## Forme d'un bloc d'après son identifiant (bloc, dalle, escalier...).
static func shape_of(item: ItemData) -> String:
	var id := item.id
	for s in SHAPES:
		if id.begins_with(str(s[0]) + "_"):
			return s[0]
	return "bloc" if item.is_block() else "autre"


## Matière d'une recette de construction : son ingrédient principal (le plus nombreux).
static func material_of(r: RecipeData) -> ItemData:
	var best: ItemData = null
	var best_n := -1
	for i in r.ingredients.size():
		var it: ItemData = r.ingredients[i]
		# la teinture donne la couleur, pas la matière
		if it == null or it.id.begins_with("teinture_"):
			continue
		if r.amount_of(i) > best_n:
			best_n = r.amount_of(i)
			best = it
	return best if best else (r.ingredients[0] if not r.ingredients.is_empty() else null)
