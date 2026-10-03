class_name Crafts
extends RefCounted
## Métiers d'artisanat et de récolte, à la manière des MMORPG (Dofus) : on ne choisit pas son métier, on le
## pratique. Chaque métier monte du niveau 1 au niveau 100 en faisant ce qu'il couvre (forger, miner, cuisiner...).
## Les niveaux débloquent des matériaux, permettent de raffiner et d'enchanter plus loin, et donnent des chances
## de récolte double ou de chef-d'œuvre. Le métier choisi à la création du héros commence au niveau 10.
## L'expérience est stockée dans `player.crafts` : { identifiant: xp totale }.

const MAX_LEVEL := 100
## Métiers : nom, icône, description, bonus par niveau.
const CRAFTS := {
	"forgeron": {"name": "Forgeron d'armes", "icon": "⚔", "color": "e0904a", "text": "Forger les armes de l'arsenal (enclume, établi) et les raffiner.",
		"perk": "Matériaux plus nobles, raffinage plus poussé (+5 au niveau 1, +15 au niveau 100), chance de chef-d'œuvre (arme forgée déjà raffinée)."},
	"armurier": {"name": "Armurier", "icon": "🛡", "color": "a0a8b8", "text": "Fabriquer et raffiner les armures, casques, gantelets, jambières et boucliers.",
		"perk": "Raffinage plus poussé des armures, chance de chef-d'œuvre."},
	"enchanteur": {"name": "Enchanteur", "icon": "✦", "color": "b07aff", "text": "Enchanter les armes et les armures, graver des runes, désenchanter.",
		"perk": "Rangs d'enchantement plus hauts (I au niveau 1, II à 15, III à 35, IV à 60, V à 85), enchantements moins chers."},
	"joaillier": {"name": "Joaillier", "icon": "💎", "color": "6ad8ff", "text": "Sertir des gemmes dans l'équipement.",
		"perk": "Sertissage moins cher, chance de récupérer la gemme quand on la remplace."},
	"mineur": {"name": "Mineur", "icon": "⛏", "color": "b8b8b2", "text": "Briser rochers et filons, fondre les minerais au four.",
		"perk": "Chance de minerai double, minerais rares plus fréquents."},
	"bucheron": {"name": "Bûcheron", "icon": "🪓", "color": "8a6238", "text": "Abattre les arbres, scier planches et rondins.",
		"perk": "Chance de bois double, fibres et graines plus fréquentes."},
	"alchimiste": {"name": "Alchimiste", "icon": "⚗", "color": "7ad87a", "text": "Préparer les potions (chaudron).",
		"perk": "Chance de potion double."},
	"cuisinier": {"name": "Cuisinier", "icon": "🍲", "color": "e8b060", "text": "Cuisiner les repas (four à pain, feu, chaudron).",
		"perk": "Chance de plat double."},
	"pecheur": {"name": "Pêcheur", "icon": "🎣", "color": "4a8ad8", "text": "Pêcher dans les rivières, les lacs et la mer.",
		"perk": "Chance de prise double."},
	"fermier": {"name": "Fermier", "icon": "🌾", "color": "c8d84a", "text": "Récolter les champs et s'occuper des bêtes.",
		"perk": "Chance de récolte double."},
	"tailleur": {"name": "Tailleur", "icon": "🧵", "color": "c86a8a", "text": "Tisser, travailler le cuir, coudre capes et vêtements.",
		"perk": "Chance de double fabrication, chef-d'œuvre sur les vêtements."},
	"batisseur": {"name": "Bâtisseur", "icon": "🧱", "color": "c8a070", "text": "Fabriquer blocs de construction et mobilier.",
		"perk": "Blocs fabriqués en plus grand nombre (+1 tous les 20 niveaux)."},
}
const ORDER := ["forgeron", "armurier", "enchanteur", "joaillier", "mineur", "bucheron", "alchimiste", "cuisinier",
	"pecheur", "fermier", "tailleur", "batisseur"]
## Métier du héros (choisi à la création) -> métiers qui commencent au niveau 10.
const JOB_START := {"forgeron": ["forgeron", "armurier"], "mineur": ["mineur", "joaillier"], "bucheron": ["bucheron", "batisseur"],
	"herboriste": ["alchimiste", "fermier"], "tisserand": ["tailleur", "batisseur"], "chasseur": ["pecheur", "cuisinier"],
	"marchand": ["joaillier", "enchanteur"], "pecheur": ["pecheur", "cuisinier"], "alchimiste": ["alchimiste", "enchanteur"],
	"cuisinier": ["cuisinier", "fermier"], "fermier": ["fermier", "cuisinier"], "joaillier": ["joaillier", "mineur"],
	"enchanteur": ["enchanteur", "joaillier"], "architecte": ["batisseur", "bucheron"]}
const START_LEVEL := 10


## Expérience pour passer du niveau `l` au suivant (courbe douce : ~25 000 xp en tout pour le niveau 100).
static func xp_to_next(l: int) -> int:
	return 20 + 5 * l


static func xp_for_level(l: int) -> int:
	var t := 0
	for i in range(1, l):
		t += xp_to_next(i)
	return t


static func level_of_xp(xp: int) -> int:
	var l := 1
	while l < MAX_LEVEL and xp >= xp_for_level(l + 1):
		l += 1
	return l


static func level(p: Node, craft: String) -> int:
	if p == null or not ("crafts" in p):
		return 1
	return level_of_xp(int(p.crafts.get(craft, 0)))


## Progression dans le niveau : [xp dans le niveau, xp du niveau].
static func progress(p: Node, craft: String) -> Array:
	var xp := int(p.crafts.get(craft, 0))
	var l := level_of_xp(xp)
	if l >= MAX_LEVEL:
		return [1, 1]
	return [xp - xp_for_level(l), xp_to_next(l)]


## Les métiers de départ (selon le métier choisi à la création).
static func init_for(p: Node) -> void:
	if not p.crafts.is_empty():
		return
	for c in ORDER:
		p.crafts[c] = 0
	var job_id := ""
	if p.get("profile") and p.profile and p.profile.job:
		job_id = p.profile.job.resource_path.get_file().get_basename()
	for c in JOB_START.get(job_id, []):
		p.crafts[c] = xp_for_level(START_LEVEL)


## Gagne de l'expérience de métier. `req` : niveau de l'action (une action trop facile rapporte moins).
## Renvoie le nouveau niveau s'il a changé, sinon 0.
static func gain(p: Node, craft: String, amount: float, req := 1) -> int:
	if p == null or not ("crafts" in p) or not CRAFTS.has(craft):
		return 0
	var before := level(p, craft)
	if before >= MAX_LEVEL:
		return 0
	# une action bien en dessous de son niveau rapporte moins (jamais moins de 20 %)
	var f := clampf(1.0 - float(before - req) / 80.0, 0.2, 1.0)
	var add := maxi(1, roundi(amount * f))
	p.crafts[craft] = int(p.crafts.get(craft, 0)) + add
	var after := level(p, craft)
	if after > before:
		var info: Dictionary = CRAFTS[craft]
		if p.has_signal("feat"):
			p.feat.emit("%s %s : niveau %d !" % [info.icon, info.name, after], Color(info.color))
		if p.has_signal("notify") and after % 10 == 0:
			p.notify.emit("%s niveau %d : %s" % [info.name, after, perk_text(craft, after)])
		Sound.ui("levelup")
		return after
	return 0


## Le métier qui fabrique le résultat d'une recette.
static func craft_of_recipe(r: RecipeData) -> String:
	var it := r.result
	if it == null:
		return ""
	if r.has_meta("craft"):
		return r.get_meta("craft")
	if r.category == "Armurerie":
		return "forgeron"
	if it.potion_heal > 0.0 or not it.potion_buff.is_empty():
		return "alchimiste"
	if it.food > 0.0:
		return "cuisinier"
	if it.is_block() or it.is_furniture() or r.category in ["Construction", "Mobilier"]:
		return "batisseur"
	if it.is_equipment():
		if it.slot == ItemData.Slot.MAIN_HAND:
			return "forgeron"
		if it.slot == ItemData.Slot.BACK or it.id.contains("laine") or it.id.contains("leather") or it.id.contains("mage"):
			return "tailleur"
		return "armurier"
	if r.station == "four":
		return "mineur"
	if r.category == "Outils":
		return "forgeron"
	if it.id in ["laine", "leather", "fiber"] or r.station == "metier_tisser":
		return "tailleur"
	if it.id.begins_with("gemme") or it.id.begins_with("rune"):
		return "joaillier"
	return "batisseur"


## Niveau de métier requis pour une recette (seules les armes de l'arsenal en demandent un).
static func recipe_level(r: RecipeData) -> int:
	if r.has_meta("level"):
		return int(r.get_meta("level"))
	if r.result and Arsenal.is_arsenal(r.result.id):
		return int(Arsenal.material(Arsenal.parse(r.result.id)[1]).level)
	return 1


## Expérience d'une fabrication : selon la rareté et la quantité d'ingrédients.
static func recipe_xp(r: RecipeData) -> float:
	var n := 0
	for i in r.ingredients.size():
		n += r.amount_of(i)
	var rar := int(r.result.rarity) if r.result else 0
	return 6.0 + n * 2.0 + rar * 14.0 + recipe_level(r) * 0.8


## Après une fabrication réussie : expérience, et chance de double fabrication / de chef-d'œuvre.
## Renvoie un texte à afficher (vide si rien de spécial).
static func on_crafted(p: Node, r: RecipeData) -> String:
	var c := craft_of_recipe(r)
	if c == "":
		return ""
	var lv := level(p, c)
	gain(p, c, recipe_xp(r), recipe_level(r))
	var it := r.result
	# double fabrication (consommables et blocs)
	if c in ["alchimiste", "cuisinier", "tailleur"] and not it.is_equipment() and randf() < lv / 200.0:
		p.inventory.add(it, r.result_count)
		return "Double fabrication !"
	if c == "batisseur" and (it.is_block() or it.max_stack > 1) and lv >= 20:
		p.inventory.add(it, lv / 20)
		return ""
	# chef-d'œuvre : l'arme ou l'armure sort de la forge déjà raffinée
	if it.is_equipment() and Forge.is_upgradable(it) and randf() < 0.05 + lv / 250.0:
		var bonus_lv := 1 + int(randf() * (1 + lv / 34))
		var v := Items.get_item(Forge.variant_id(Forge.base_of(it), bonus_lv, PackedStringArray()))
		if v and p.inventory.count(it) > 0:
			p.inventory.remove(it, 1)
			p.inventory.add(v, 1)
			if p.has_signal("feat"):
				p.feat.emit("Chef-d'œuvre : %s" % v.display_name, Color("ffd24a"))
			return "Chef-d'œuvre !"
	return ""


## Chance de récolte double (mineur, bûcheron, fermier, pêcheur).
static func double_chance(p: Node, craft: String) -> float:
	return level(p, craft) / 150.0


## Niveau de raffinage maximum (+5 au niveau 1, +15 au niveau 100).
static func max_refine(p: Node, item: ItemData) -> int:
	var c := "forgeron" if item and item.slot == ItemData.Slot.MAIN_HAND else "armurier"
	return mini(Forge.MAX_LEVEL, 5 + level(p, c) / 10)


## Rang d'enchantement maximum (1 à 5).
static func max_enchant_rank(p: Node) -> int:
	var l := level(p, "enchanteur")
	return 5 if l >= 85 else (4 if l >= 60 else (3 if l >= 35 else (2 if l >= 15 else 1)))


static func perk_text(craft: String, lv: int) -> String:
	match craft:
		"forgeron", "armurier":
			return "raffinage jusqu'à +%d, chef-d'œuvre %d %%" % [5 + lv / 10, roundi((0.05 + lv / 250.0) * 100)]
		"enchanteur":
			return "enchantements jusqu'au rang %s" % ["I", "II", "III", "IV", "V"][(5 if lv >= 85 else (4 if lv >= 60 else (3 if lv >= 35 else (2 if lv >= 15 else 1)))) - 1]
		"mineur", "bucheron", "fermier", "pecheur":
			return "récolte double %d %%" % roundi(lv / 1.5)
		"alchimiste", "cuisinier", "tailleur":
			return "double fabrication %d %%" % roundi(lv / 2.0)
		"batisseur":
			return "+%d bloc(s) par fabrication" % (lv / 20)
		"joaillier":
			return "sertissage %d %% moins cher" % mini(50, lv / 2)
	return ""


static func total_level(p: Node) -> int:
	var t := 0
	for c in ORDER:
		t += level(p, c)
	return t
