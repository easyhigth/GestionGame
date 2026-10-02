class_name Forge
extends RefCounted
## Amélioration de l'équipement, à l'enclume (onglet « Forge » de l'artisanat) :
##  - renforcer une arme ou une pièce d'armure de +1 à +10 : ses caractéristiques augmentent de 10 % par
##    niveau (+1 point par niveau) ; le coût monte (fer, puis or et mithril, puis mithril raffiné, puis orichalque) ;
##  - sertir des gemmes : 1 emplacement, 2 à +4, 3 à +8 ; chaque gemme donne un effet (brûlure, givre,
##    vol de vie, critiques, magie, vie et défense).
##  - raffiner jusqu'à +15 (au-delà de +10 : orichalque) ; le niveau du métier (Forgeron, Armurier) fixe le
##    raffinage maximum ;
##  - enchanter (à l'autel) : jusqu'à 5 enchantements par objet selon son raffinage et sa rareté, chacun du
##    rang I au rang V (le rang dépend du raffinage de l'objet et du niveau d'Enchanteur). Un objet très raffiné et
##    puissamment enchanté devient épique, légendaire, voire mystique.
## Un objet amélioré est une variante de l'objet de base, reconnue par son identifiant :
## « <objet>@<niveau>~<gemme>,<gemme>!<rune>^<enchantement>:<rang>,... » (ex. sword_iron@5~gemme_rubis^feu:2).
## Il garde le modèle de l'objet de base.

const MAX_LEVEL := 15
## Enchantements : nom, épithète (ajoutée au nom de l'objet), cible (« w » arme, « a » armure, « * » les deux),
## bonus par rang, texte.
const ENCHANTS := {
	"tranchant": ["Tranchant", "acéré", "w", {"atk_pct": 0.04}, "+4 % d'attaque par rang"],
	"feu": ["Embrasement", "de feu", "w", {"burn": 0.06}, "brûlure : +6 % des dégâts en feu par rang"],
	"givre": ["Givre", "de givre", "w", {"slow": 0.07}, "7 % de chances par rang de ralentir"],
	"vampire": ["Vampirisme", "du vampire", "w", {"lifesteal": 0.015}, "+1,5 % de vol de vie par rang"],
	"precision": ["Précision", "précis", "w", {"crit": 0.02}, "+2 % de critiques par rang"],
	"brutalite": ["Brutalité", "brutal", "w", {"crit_mult": 0.07}, "+7 % de dégâts critiques par rang"],
	"celerite": ["Célérité", "véloce", "w", {"aspd_pct": 0.03}, "+3 % de vitesse d'attaque par rang"],
	"execution": ["Exécution", "du bourreau", "w", {"execute": 0.04}, "+4 % de dégâts par rang contre les ennemis affaiblis"],
	"tonnerre": ["Tonnerre", "du tonnerre", "w", {"stun": 0.025}, "2,5 % de chances par rang d'assommer"],
	"arcanes": ["Arcanes", "des arcanes", "*", {"mag_pct": 0.05}, "+5 % de magie par rang"],
	"furie": ["Furie", "furieux", "w", {"berserk": 0.04}, "+4 % de dégâts par rang quand la vie est basse"],
	"moisson": ["Moisson d'âmes", "des âmes", "w", {"kill_heal": 1.0}, "soigne de 1 % de la vie par rang à chaque ennemi vaincu"],
	"sagesse": ["Sagesse", "du sage", "*", {"xp": 0.04}, "+4 % d'expérience par rang"],
	"fortune": ["Fortune", "de fortune", "*", {"loot": 0.05}, "+5 % de butin par rang"],
	"protection": ["Protection", "protecteur", "a", {"def_flat": 2.5}, "+2,5 défense par rang"],
	"vitalite": ["Vitalité", "vital", "a", {"hp_pct": 0.04}, "+4 % de vie par rang"],
	"epines": ["Épines", "épineux", "a", {"thorns": 0.05}, "renvoie 5 % des dégâts reçus par rang"],
	"regeneration": ["Régénération", "du renouveau", "a", {"regen": 0.6}, "+0,6 vie par seconde par rang"],
	"esquive": ["Esquive", "insaisissable", "a", {"dodge": 0.015}, "fenêtre d'esquive parfaite plus longue"],
	"vivacite": ["Vivacité", "agile", "a", {"spd_pct": 0.02}, "+2 % de vitesse par rang"],
	"concentration": ["Concentration", "du mage", "*", {"cdr_pct": 0.02}, "recharges -2 % par rang"],
	"stabilite": ["Stabilité", "inébranlable", "a", {"poise": 0.05}, "+5 % d'équilibre par rang"],
	"parade": ["Parade", "du duelliste", "*", {"parry": 0.01}, "fenêtre de parade plus longue"],
	"absorption": ["Absorption", "du gouffre", "a", {"absorb": 0.02}, "2 % de chances par rang d'absorber un coup"],
	"dernier_rempart": ["Dernier rempart", "immortel", "a", {"last_stand": 0.2}, "rang V : survit une fois à un coup mortel"],
	"eveil": ["Éveil", "de l'Éveil", "*", {"atk_pct": 0.03, "mag_pct": 0.03, "hp_pct": 0.03}, "+3 % d'attaque, de magie et de vie par rang (rare : pierre d'âme dès le rang I)"],
}
const RANK_NAMES := ["", "I", "II", "III", "IV", "V"]
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
	return item != null and item.is_equipment() and not item.id.contains("#") and (item.attack > 0 or item.defense > 0 or item.magic > 0)


static func base_of(item: ItemData) -> String:
	return item.base_id if item.base_id != "" else item.id


static func variant_id(base: String, level: int, gems: PackedStringArray, rune := "", enchants := {}) -> String:
	var id := "%s@%d" % [base, level]
	if not gems.is_empty():
		id += "~" + ",".join(gems)
	if rune != "":
		id += "!" + rune
	if not enchants.is_empty():
		var parts := []
		for k in ENCHANTS:
			if enchants.has(k):
				parts.append("%s:%d" % [k, int(enchants[k])])
		id += "^" + ",".join(PackedStringArray(parts))
	return id


## Les enchantements d'un identifiant de variante : { enchantement: rang }.
static func parse_enchants(id: String) -> Dictionary:
	var out := {}
	if not id.contains("^"):
		return out
	for part in id.get_slice("^", 1).split(","):
		var k := part.get_slice(":", 0)
		if ENCHANTS.has(k):
			out[k] = clampi(int(part.get_slice(":", 1)), 1, 5)
	return out


## [identifiant de base, niveau, gemmes, rune, enchantements] d'un identifiant de variante.
static func parse(id: String) -> Array:
	var ench := parse_enchants(id)
	id = id.get_slice("^", 0)
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
	return [base, level, gems, rune, ench]


## Fabrique la variante améliorée d'un objet de base.
static func make_variant(base: ItemData, level: int, gems: PackedStringArray, rune := "", enchants := {}) -> ItemData:
	var v := base.duplicate() as ItemData
	v.base_id = base.id
	v.id = variant_id(base.id, level, gems, rune, enchants)
	v.enchants = enchants.duplicate()
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
	var ranks := 0
	var best := ""
	for k in enchants:
		ranks += int(enchants[k])
		if best == "" or int(enchants[k]) > int(enchants[best]):
			best = k
	if best != "":
		v.display_name += " " + str(ENCHANTS[best][1])
	if level >= 15 and ranks >= 20:
		v.rarity = ItemData.Rarity.MYTHIC
	elif level >= 10 or ranks >= 14:
		v.rarity = ItemData.Rarity.LEGENDARY
	elif level >= 7 or ranks >= 8:
		v.rarity = maxi(base.rarity, ItemData.Rarity.EPIC)
	elif level >= 4 or ranks >= 4:
		v.rarity = maxi(base.rarity, ItemData.Rarity.RARE)
	# les bonus de l'objet de base (armes de l'arsenal) restent
	var bonus := base.bonus.duplicate()
	for g in gems:
		for k in GEMS[g].bonus:
			bonus[k] = float(bonus.get(k, 0.0)) + float(GEMS[g].bonus[k])
	if rune != "":
		for k in RUNES[rune].bonus:
			bonus[k] = float(bonus.get(k, 0.0)) + float(RUNES[rune].bonus[k])
	for e in enchants:
		var per: Dictionary = ENCHANTS[e][3]
		for k in per:
			bonus[k] = float(bonus.get(k, 0.0)) + float(per[k]) * int(enchants[e])
	v.bonus = bonus
	v.max_stack = 1
	return v


static func sockets(level: int) -> int:
	return 1 + level / 4


## Coût du niveau `level` (1 à 15) : [[objet, nombre], ...].
static func cost(level: int) -> Array:
	if level > 10:
		return [["orichalque", level - 9], ["lingot_mithril", 3], ["larme_esprit", 1], ["piece_or", 1500 * (level - 9)]]
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
	if item.upgrade >= Crafts.max_refine(p, item):
		return "Ton niveau de %s limite le raffinage à +%d." % ["Forgeron" if item.slot == ItemData.Slot.MAIN_HAND else "Armurier", Crafts.max_refine(p, item)]
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
	var v := _item(variant_id(base_of(item), item.upgrade + 1, item.gems, item.rune, item.enchants))
	_replace(p, item, v)
	p.feat.emit("Forge : %s" % v.display_name, v.rarity_color())
	_sound(p, "hit_heavy")
	Crafts.gain(p, "forgeron" if item.slot == ItemData.Slot.MAIN_HAND else "armurier", 25.0 + 12.0 * v.upgrade, v.upgrade * 6)
	return v


## Sertit une gemme ; renvoie la nouvelle version, ou null.
static func socket(p: Player, item: ItemData, gem: String, stations: Array) -> ItemData:
	if gem_block(p, item, gem, stations) != "":
		return null
	p.inventory.remove(_item(gem), 1)
	var gems := item.gems.duplicate()
	gems.append(gem)
	var v := _item(variant_id(base_of(item), item.upgrade, gems, item.rune, item.enchants))
	_replace(p, item, v)
	Crafts.gain(p, "joaillier", 30.0)
	p.feat.emit("Serti : %s dans %s" % [GEMS[gem].name, v.display_name], Color("c8a8ff"))
	_sound(p, "socket")
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
	var v := _item(variant_id(base_of(item), item.upgrade, item.gems, rune, item.enchants))
	_replace(p, item, v)
	Crafts.gain(p, "enchanteur", 25.0)
	p.feat.emit("Rune de %s gravée : %s" % [RUNES[rune].name.to_lower(), v.display_name], Color("8ad0ff"))
	_sound(p, "rune")
	return v


static func _sound(p: Player, name: String) -> void:
	var snd := p.get_tree().root.get_node_or_null("Sound")
	if snd:
		snd.play(name, p.global_position)


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


## Plafonds des bonus de gemmes et de runes cumulés sur tout l'équipement porté (équilibrage).
const BONUS_CAPS := {"crit": 0.4, "crit_mult": 1.0, "lifesteal": 0.15, "burn": 0.6, "slow": 0.5, "atk_pct": 0.6,
	"mag_pct": 0.7, "hp_pct": 0.6, "cdr_pct": 0.3, "spd_pct": 0.25, "aspd_pct": 0.3, "regen": 20.0, "def_flat": 80.0,
	"execute": 0.4, "stun": 0.25, "berserk": 0.4, "kill_heal": 8.0, "xp": 0.5, "loot": 0.6, "thorns": 0.5,
	"dodge": 0.12, "poise": 0.5, "parry": 0.08, "absorb": 0.2, "last_stand": 1.0}


## Bonus des gemmes et des runes de tout ce que porte le héros (plafonnés).
static func equipment_bonus(p: Player) -> Dictionary:
	var out := {}
	for slot in p.equipment.slots:
		var it: ItemData = p.equipment.slots[slot]
		if it and not it.bonus.is_empty():
			for k in it.bonus:
				out[k] = float(out.get(k, 0.0)) + float(it.bonus[k])
	for k in out:
		if BONUS_CAPS.has(k):
			out[k] = minf(float(out[k]), float(BONUS_CAPS[k]))
	return out


# ---------------------------------------------------------------- enchantements (à l'autel)

static func can_enchant_item(item: ItemData) -> bool:
	return is_upgradable(item)


## Le type d'objet pour les enchantements : « w » arme, « a » armure (et boucliers, bijoux...).
static func ench_target(item: ItemData) -> String:
	return "w" if item.slot == ItemData.Slot.MAIN_HAND else "a"


static func enchants_for(item: ItemData) -> Array:
	var t := ench_target(item)
	var out := []
	for k in ENCHANTS:
		if ENCHANTS[k][2] == "*" or ENCHANTS[k][2] == t:
			out.append(k)
	return out


## Emplacements d'enchantement : 1, +1 tous les 5 niveaux de raffinage, +1 si l'objet de base est épique ou mieux.
static func ench_slots(item: ItemData) -> int:
	var base := _item(base_of(item))
	var r: int = base.rarity if base else item.rarity
	return mini(5, 1 + item.upgrade / 5 + (1 if r >= ItemData.Rarity.EPIC else 0))


## Rang maximal sur cet objet (selon son raffinage) : I de +0 à +3, II dès +4, III dès +7, IV dès +11, V dès +14.
static func item_rank_cap(item: ItemData) -> int:
	return mini(5, 1 + int(item.upgrade / 3.5))


static func max_rank(p: Player, item: ItemData) -> int:
	return mini(item_rank_cap(item), Crafts.max_enchant_rank(p))


## Coût d'un enchantement au rang `rank` (réduit par le niveau d'Enchanteur).
static func ench_cost(p: Player, ench: String, rank: int) -> Array:
	var red := 1.0 - minf(0.4, Crafts.level(p, "enchanteur") / 250.0)
	var out := [["poussiere_arcane", maxi(1, roundi(rank * 3 * red))], ["piece_or", roundi(60 * rank * rank * red)]]
	if rank >= 3:
		out.append(["larme_esprit", rank - 2])
	if rank >= 5 or ench == "eveil":
		out.append(["pierre_ame", 1 if rank < 5 or ench != "eveil" else 2])
	return out


static func ench_cost_text(p: Player, ench: String, rank: int) -> String:
	var parts := []
	for pair in ench_cost(p, ench, rank):
		var it := _item(pair[0])
		parts.append("%d %s" % [pair[1], it.display_name if it else pair[0]])
	return ", ".join(PackedStringArray(parts))


## Pourquoi on ne peut pas poser cet enchantement à ce rang ("" si c'est possible).
static func enchant_block(p: Player, item: ItemData, ench: String, rank: int, stations: Array) -> String:
	if not can_enchant_item(item):
		return "Cet objet ne s'enchante pas."
	if not ENCHANTS.has(ench) or not enchants_for(item).has(ench):
		return "Cet enchantement ne va pas sur cet objet."
	if not stations.has("autel"):
		return "Approche-toi d'un autel."
	var cur := int(item.enchants.get(ench, 0))
	if rank <= cur:
		return "Déjà au rang %s." % RANK_NAMES[cur]
	if cur == 0 and item.enchants.size() >= ench_slots(item):
		return "Plus d'emplacement d'enchantement (%d) : raffine l'objet pour en ouvrir." % ench_slots(item)
	if rank > item_rank_cap(item):
		return "Raffine l'objet pour le rang %s (rang max ici : %s)." % [RANK_NAMES[rank], RANK_NAMES[item_rank_cap(item)]]
	if rank > Crafts.max_enchant_rank(p):
		return "Ton niveau d'Enchanteur limite au rang %s." % RANK_NAMES[Crafts.max_enchant_rank(p)]
	for pair in ench_cost(p, ench, rank):
		if p.inventory.count(_item(pair[0])) < int(pair[1]):
			return "Il manque : %s." % _item(pair[0]).display_name
	return ""


## Enchante (ou monte le rang d'un enchantement) ; renvoie la nouvelle version, ou null.
static func enchant(p: Player, item: ItemData, ench: String, rank: int, stations: Array) -> ItemData:
	if enchant_block(p, item, ench, rank, stations) != "":
		return null
	for pair in ench_cost(p, ench, rank):
		p.inventory.remove(_item(pair[0]), int(pair[1]))
	var en := item.enchants.duplicate()
	en[ench] = rank
	var v := _item(variant_id(base_of(item), item.upgrade, item.gems, item.rune, en))
	_replace(p, item, v)
	Crafts.gain(p, "enchanteur", 20.0 + 25.0 * rank, (rank - 1) * 20)
	p.feat.emit("%s %s : %s" % [ENCHANTS[ench][0], RANK_NAMES[rank], v.display_name], v.rarity_color())
	_sound(p, "rune")
	return v


## Retire un enchantement (rend un peu de poussière arcanique).
static func disenchant(p: Player, item: ItemData, ench: String, stations: Array) -> ItemData:
	if not stations.has("autel") or not item.enchants.has(ench):
		return null
	var en := item.enchants.duplicate()
	var r := int(en[ench])
	en.erase(ench)
	var v := _item(variant_id(base_of(item), item.upgrade, item.gems, item.rune, en))
	_replace(p, item, v)
	p.inventory.add(_item("poussiere_arcane"), r)
	_sound(p, "rune")
	return v


## Réduit un objet en poussière arcanique (à l'autel) : 1 + 2 par rareté, plus ses enchantements.
static func salvage_value(item: ItemData) -> int:
	var n := 1 + 2 * int(item.rarity) + item.upgrade / 3
	for k in item.enchants:
		n += int(item.enchants[k])
	return n


static func salvage(p: Player, item: ItemData, stations: Array) -> int:
	if item == null or not item.is_equipment() or not stations.has("autel"):
		return 0
	for slot in p.equipment.slots:
		if p.equipment.slots[slot] == item:
			return 0
	if not p.inventory.remove(item, 1):
		return 0
	var n := salvage_value(item)
	p.inventory.add(_item("poussiere_arcane"), n)
	Crafts.gain(p, "enchanteur", 6.0 + 4.0 * n)
	_sound(p, "rune")
	return n


## Résumé des enchantements, ex. « Embrasement III, Vampirisme II ».
static func enchants_text(item: ItemData) -> String:
	var parts := []
	for k in ENCHANTS:
		if item.enchants.has(k):
			parts.append("%s %s" % [ENCHANTS[k][0], RANK_NAMES[int(item.enchants[k])]])
	return ", ".join(PackedStringArray(parts))
