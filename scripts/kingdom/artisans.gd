class_name Artisans
extends RefCounted
## Les habitants artisans pratiquent leur métier comme le héros (voir Crafts) : chaque production leur donne de
## l'expérience (niveau 1 à 100, `artisan_xp`), et plus ils sont habiles, plus ils produisent de choses
## nouvelles :
## - forgeron (forge) : les commandes du héros d'abord (onglet Armurerie), sinon des armes de l'arsenal du
##   meilleur matériau qu'il maîtrise, parfois déjà raffinées (chef-d'œuvre) ;
## - enchanteur (sanctuaire des runes) : poussière arcanique, et rarement une pierre d'âme ;
## - maçon : minerais de cuivre et d'étain, charbon, pierres des régions ;
## - bûcheron (scierie) : bois des différentes essences ;
## - tisserand : teintures ; verrier : verre teinté.

const XP_PER_JOB := 30
## Ce que chaque métier peut produire en plus (identifiants), au hasard.
const EXTRA := {
	"enchanteur": ["poussiere_arcane"],
	"macon": ["minerai_cuivre", "minerai_etain", "charbon", "granite", "diorite", "andesite", "calcaire", "basalte"],
	"bucheron": ["bois_bouleau", "bois_sapin", "bois_acajou", "bois_ebene", "bois_cerisier", "bois_acacia", "bois_saule", "bois_palmier"],
	"tisserand": ["teinture_rouge", "teinture_bleu", "teinture_jaune", "teinture_vert", "teinture_blanc", "teinture_noir"],
	"verrier": ["bloc_verre_bleu", "bloc_verre_rouge", "bloc_verre_vert", "bloc_verre_jaune", "bloc_verre_violet", "bloc_verre_cyan"],
}


static func level(v: Node) -> int:
	return Crafts.level_of_xp(int(v.get_meta("artisan_xp", 0)))


## Après une production réussie d'un habitant : son expérience monte, et il fabrique parfois autre chose.
## Renvoie [objet, nombre, étiquette] produit en plus de la production habituelle, ou [] si rien de plus.
static func produce(v: Node, job_id: String, kingdom: Node) -> Array:
	var before := level(v)
	v.set_meta("artisan_xp", int(v.get_meta("artisan_xp", 0)) + XP_PER_JOB)
	var lv := level(v)
	if lv > before and lv % 10 == 0:
		var p := v.get_tree().get_first_node_in_group("player")
		if p:
			p.notify.emit("%s progresse : artisan de niveau %d." % [v.get("villager_name"), lv])
	match job_id:
		"forgeron":
			# les commandes du héros passent avant tout
			if kingdom and not kingdom.forge_orders.is_empty():
				var id: String = kingdom.forge_orders.pop_front()
				return [Items.get_item(id), 1, "Commande"]
			if randf() < 0.5:
				return [forge_weapon(lv), 1, ""]
		"enchanteur":
			if randf() < 0.03 + lv / 1000.0:
				return [Items.get_item("pierre_ame"), 1, ""]
			if randf() < 0.5:
				return [Items.get_item("poussiere_arcane"), 1 + lv / 25, ""]
		_:
			if EXTRA.has(job_id) and randf() < 0.45:
				var pool: Array = EXTRA[job_id]
				return [Items.get_item(pool[randi() % pool.size()]), 2 + lv / 30, ""]
	return []


## Une arme de l'arsenal forgée par un artisan de ce niveau (meilleur matériau maîtrisé, sauf les matériaux rares).
static func forge_weapon(lv: int) -> ItemData:
	var best: Dictionary = Arsenal.MATERIALS[0]
	for m in Arsenal.MATERIALS:
		if int(m.level) <= lv and not m.get("rare", false):
			best = m
	var type: String = Arsenal.TYPE_ORDER[randi() % Arsenal.TYPE_ORDER.size()]
	var id := Arsenal.make_id(type, best.id, randi() % 4)
	# chef-d'œuvre : déjà raffinée
	if randf() < 0.05 + lv / 250.0:
		id = Forge.variant_id(id, 1 + randi() % (1 + lv / 34), PackedStringArray())
	return Items.get_item(id)


## Coût d'une commande au forgeron : les ingrédients de la recette, et de l'or selon le matériau.
static func order_gold(r: RecipeData) -> int:
	return 20 + 4 * Crafts.recipe_level(r)


## Y a-t-il un forgeron au travail au village ?
static func has_smith(tree: SceneTree) -> bool:
	for v in tree.get_nodes_in_group("villagers"):
		var room = v.get("work_room")
		if room != null and room.type and (room.type as RoomTypeData).job_id == "forgeron":
			return true
	return false


## Passe une commande : retire les ingrédients et l'or, la met dans la file du forgeron.
static func order(p: Node, r: RecipeData) -> bool:
	var k := p.get_tree().get_first_node_in_group("kingdom")
	if k == null or not has_smith(p.get_tree()):
		return false
	var gold := Items.get_item("piece_or")
	if p.inventory.count(gold) < order_gold(r):
		return false
	for i in r.ingredients.size():
		if p.inventory.count(r.ingredients[i]) < r.amount_of(i):
			return false
	for i in r.ingredients.size():
		p.inventory.remove(r.ingredients[i], r.amount_of(i))
	p.inventory.remove(gold, order_gold(r))
	k.forge_orders.append(r.result.id)
	return true
