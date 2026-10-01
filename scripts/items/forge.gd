class_name Forge
extends RefCounted
## Amélioration de l'équipement, à l'enclume (onglet « Forge » de l'artisanat) :
##  - renforcer une arme ou une pièce d'armure de +1 à +10 : ses caractéristiques augmentent de 10 % par
##    niveau (+1 point par niveau) ; le coût monte (fer, puis or et mithril, puis mithril raffiné, puis orichalque) ;
##  - sertir des gemmes : 1 emplacement, 2 à +4, 3 à +8 ; chaque gemme donne un effet (brûlure, givre,
##    vol de vie, critiques, magie, vie et défense).
## Un objet amélioré est une variante de l'objet de base, reconnue par son identifiant :
## « <objet>@<niveau>~<gemme>,<gemme> » (ex. sword_iron@5~gemme_rubis). Il garde le modèle de l'objet de base.

const MAX_LEVEL := 10
## Gemmes : nom, bonus (clés des compétences), texte.
const GEMS := {
	"gemme_rubis": {"name": "Rubis", "bonus": {"burn": 0.12, "atk_pct": 0.04}, "text": "brûlure au contact, +4 % d'attaque"},
	"gemme_saphir": {"name": "Saphir", "bonus": {"slow": 0.15, "mag_pct": 0.04}, "text": "givre (ralentit), +4 % de magie"},
	"gemme_emeraude": {"name": "Émeraude", "bonus": {"lifesteal": 0.04, "regen": 0.5}, "text": "4 % de vol de vie, régénération"},
	"gemme_topaze": {"name": "Topaze", "bonus": {"crit": 0.05, "crit_mult": 0.15}, "text": "+5 % de critiques, +15 % de dégâts critiques"},
	"gemme_amethyste": {"name": "Améthyste", "bonus": {"mag_pct": 0.08, "cdr_pct": 0.05}, "text": "+8 % de magie, recharges -5 %"},
	"gemme_diamant": {"name": "Diamant", "bonus": {"hp_pct": 0.06, "def_flat": 3.0}, "text": "+6 % de vie, +3 défense"},
}


## La base des objets (autoload « Items »), cherchée à l'exécution (la classe peut être compilée avant les autoloads).
static func _item(id: String) -> ItemData:
	var db := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Items")
	return db.get_item(id) if db else null

## Runes (gravées par les enchanteurs, voir le Sanctuaire des runes) : une par objet, remplaçable.
const RUNES := {
	"rune_force": {"name": "Force", "bonus": {"atk_pct": 0.06}, "text": "+6 % d'attaque"},
	"rune_garde": {"name": "Garde", "bonus": {"def_flat": 4.0}, "text": "+4 défense"},
	"rune_vie": {"name": "Vie", "bonus": {"hp_pct": 0.08}, "text": "+8 % de vie"},
	"rune_celerite": {"name": "Célérité", "bonus": {"spd_pct": 0.05, "aspd_pct": 0.05}, "text": "+5 % de vitesse et de vitesse d'attaque"},
}


static func is_upgradable(item: ItemData) -> bool:
	return item != null and item.is_equipment() and (item.attack > 0 or item.defense > 0 or item.magic > 0)


static func base_of(item: ItemData) -> String:
	return item.base_id if item.base_id != "" else item.id


static func variant_id(base: String, level: int, gems: PackedStringArray, rune := "") -> String:
	var id := "%s@%d" % [base, level]
	if not gems.is_empty():
		id += "~" + ",".join(gems)
	if rune != "":
		id += "!" + rune
	return id


## [identifiant de base, niveau, gemmes, rune] d'un identifiant de variante.
static func parse(id: String) -> Array:
	var base := id.get_slice("@", 0)
	var rest := id.get_slice("@", 1)
	var rune := ""
	if rest.contains("!"):
		rune = rest.get_slice("!", 1)
		rest = rest.get_slice("!", 0)
		if not RUNES.has(rune):
			rune = ""
	var level := int(rest.get_slice("~", 0))
	var gems := PackedStringArray()
	if rest.contains("~"):
		for g in rest.get_slice("~", 1).split(","):
			if GEMS.has(g):
				gems.append(g)
	return [base, level, gems, rune]


## Fabrique la variante améliorée d'un objet de base.
static func make_variant(base: ItemData, level: int, gems: PackedStringArray, rune := "") -> ItemData:
	var v := base.duplicate() as ItemData
	v.base_id = base.id
	v.id = variant_id(base.id, level, gems, rune)
	v.rune = rune
	v.upgrade = level
	v.gems = gems
	var mult := 1.0 + 0.1 * level
	if base.attack > 0:
		v.attack = roundi(base.attack * mult) + level
	if base.defense > 0:
		v.defense = roundi(base.defense * mult) + level
	if base.magic > 0:
		v.magic = roundi(base.magic * mult) + level
	v.display_name = base.display_name + (" +%d" % level if level > 0 else "")
	if level >= 10:
		v.rarity = ItemData.Rarity.LEGENDARY
	elif level >= 7:
		v.rarity = maxi(base.rarity, ItemData.Rarity.EPIC)
	elif level >= 4:
		v.rarity = maxi(base.rarity, ItemData.Rarity.RARE)
	var bonus := {}
	for g in gems:
		for k in GEMS[g].bonus:
			bonus[k] = float(bonus.get(k, 0.0)) + float(GEMS[g].bonus[k])
	if rune != "":
		for k in RUNES[rune].bonus:
			bonus[k] = float(bonus.get(k, 0.0)) + float(RUNES[rune].bonus[k])
	v.bonus = bonus
	v.max_stack = 1
	return v


static func sockets(level: int) -> int:
	return 1 + level / 4


## Coût du niveau `level` (1 à 10) : [[objet, nombre], ...].
static func cost(level: int) -> Array:
	if level <= 3:
		return [["iron_ingot", 2 * level], ["piece_or", 30 * level]]
	if level <= 6:
		return [["lingot_or", level - 3], ["mithril_brut", level - 3], ["piece_or", 60 * level]]
	if level <= 9:
		return [["lingot_mithril", level - 6], ["larme_esprit", 1], ["piece_or", 100 * level]]
	return [["orichalque", 1], ["lingot_mithril", 3], ["piece_or", 1000]]


static func cost_text(level: int) -> String:
	var parts := []
	for pair in cost(level):
		var it := _item(pair[0])
		parts.append("%d %s" % [pair[1], it.display_name if it else pair[0]])
	return ", ".join(PackedStringArray(parts))


## Pourquoi on ne peut pas renforcer ("" si c'est possible).
static func upgrade_block(p: Player, item: ItemData, stations: Array) -> String:
	if not is_upgradable(item):
		return "Cet objet ne se renforce pas."
	if item.upgrade >= MAX_LEVEL:
		return "Niveau maximal (+%d)." % MAX_LEVEL
	if not stations.has("enclume"):
		return "Approche-toi d'une enclume."
	for pair in cost(item.upgrade + 1):
		if p.inventory.count(_item(pair[0])) < int(pair[1]):
			return "Il manque : %s." % _item(pair[0]).display_name
	return ""


static func gem_block(p: Player, item: ItemData, gem: String, stations: Array) -> String:
	if not is_upgradable(item):
		return "Cet objet ne se sertit pas."
	if item.gems.size() >= sockets(item.upgrade):
		return "Plus d'emplacement libre (renforce l'objet pour en ouvrir)."
	if not stations.has("enclume"):
		return "Approche-toi d'une enclume."
	if p.inventory.count(_item(gem)) <= 0:
		return "Tu n'as pas de %s." % GEMS[gem].name
	return ""


## Renforce l'objet (dans le sac ou porté) ; renvoie la nouvelle version, ou null.
static func upgrade(p: Player, item: ItemData, stations: Array) -> ItemData:
	if upgrade_block(p, item, stations) != "":
		return null
	for pair in cost(item.upgrade + 1):
		p.inventory.remove(_item(pair[0]), int(pair[1]))
	var v := _item(variant_id(base_of(item), item.upgrade + 1, item.gems, item.rune))
	_replace(p, item, v)
	p.feat.emit("Forge : %s" % v.display_name, v.rarity_color())
	var snd := p.get_tree().root.get_node_or_null("Sound")
	if snd:
		snd.play("hit_heavy", p.global_position)
	return v


## Sertit une gemme ; renvoie la nouvelle version, ou null.
static func socket(p: Player, item: ItemData, gem: String, stations: Array) -> ItemData:
	if gem_block(p, item, gem, stations) != "":
		return null
	p.inventory.remove(_item(gem), 1)
	var gems := item.gems.duplicate()
	gems.append(gem)
	var v := _item(variant_id(base_of(item), item.upgrade, gems, item.rune))
	_replace(p, item, v)
	p.feat.emit("Serti : %s dans %s" % [GEMS[gem].name, v.display_name], Color("c8a8ff"))
	return v


static func rune_block(p: Player, item: ItemData, rune: String, stations: Array) -> String:
	if not is_upgradable(item):
		return "Cet objet ne se grave pas."
	if item.rune == rune:
		return "Cette rune y est déjà gravée."
	if not stations.has("enclume"):
		return "Approche-toi d'une enclume."
	if p.inventory.count(_item(rune)) <= 0:
		return "Tu n'as pas de rune de %s." % RUNES[rune].name.to_lower()
	return ""


## Grave une rune (elle remplace l'ancienne) ; renvoie la nouvelle version, ou null.
static func inscribe(p: Player, item: ItemData, rune: String, stations: Array) -> ItemData:
	if rune_block(p, item, rune, stations) != "":
		return null
	p.inventory.remove(_item(rune), 1)
	var v := _item(variant_id(base_of(item), item.upgrade, item.gems, rune))
	_replace(p, item, v)
	p.feat.emit("Rune de %s gravée : %s" % [RUNES[rune].name.to_lower(), v.display_name], Color("8ad0ff"))
	return v


## Remplace l'objet par sa nouvelle version, là où il est (porté ou dans le sac).
static func _replace(p: Player, old: ItemData, new_item: ItemData) -> void:
	for slot in p.equipment.slots:
		if p.equipment.slots[slot] == old:
			p.equipment.equip(new_item)
			return
	if p.inventory.remove(old, 1):
		p.inventory.add(new_item, 1)


## Les objets du héros que la forge peut travailler (portés puis dans le sac).
static func workable(p: Player) -> Array:
	var out := []
	for slot in p.equipment.slots:
		var it: ItemData = p.equipment.slots[slot]
		if is_upgradable(it):
			out.append(it)
	for e in p.inventory.entries:
		if is_upgradable(e.item) and not out.has(e.item):
			out.append(e.item)
	return out


## Bonus des gemmes de tout ce que porte le héros.
static func equipment_bonus(p: Player) -> Dictionary:
	var out := {}
	for slot in p.equipment.slots:
		var it: ItemData = p.equipment.slots[slot]
		if it and not it.bonus.is_empty():
			for k in it.bonus:
				out[k] = float(out.get(k, 0.0)) + float(it.bonus[k])
	return out
