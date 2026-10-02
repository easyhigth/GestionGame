class_name ItemData
extends Resource
## Un objet : matériau, arme ou pièce d'armure.
## Chaque objet est un fichier .tres dans data/items/ : duplique-en un pour en créer un nouveau.

enum Slot { NONE, MAIN_HAND, OFF_HAND, HEAD, CHEST, ARMS, LEGS, BACK }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }
## Façon de se battre avec l'arme (choisit la suite de coups du combo).
enum WeaponStyle { SWORD, SPEAR, HEAVY, STAFF, UNARMED }

const TIER_NAMES := ["Bois", "Pierre", "Pierre taillée", "Pierre polie", "Marbre", "Or"]
const SLOT_NAMES := {
	Slot.NONE: "Matériau",
	Slot.MAIN_HAND: "Arme",
	Slot.OFF_HAND: "Bouclier",
	Slot.HEAD: "Tête",
	Slot.CHEST: "Torse",
	Slot.ARMS: "Bras",
	Slot.LEGS: "Jambes",
	Slot.BACK: "Dos",
}
const RARITY_COLORS := {
	Rarity.COMMON: Color("e8e4dc"),
	Rarity.UNCOMMON: Color("7ad66a"),
	Rarity.RARE: Color("6aa8ff"),
	Rarity.EPIC: Color("c88aff"),
	Rarity.LEGENDARY: Color("ffa640"),
	Rarity.MYTHIC: Color("ff3a7a"),
}

## Identifiant unique (sert aussi de nom du modèle 3D dans les fichiers <race>_equipment.glb
## ou materials.glb).
@export var id: String = ""
@export var display_name: String = "Objet"
@export_multiline var description: String = ""
## Emplacement où l'objet s'équipe (« NONE » = matériau d'artisanat).
@export var slot: Slot = Slot.NONE
@export var rarity: Rarity = Rarity.COMMON
## Objet amélioré à la forge (voir Forge) : objet de base, niveau (+0 à +10), gemmes serties et leurs bonus
## (mêmes clés que les compétences : burn, crit, lifesteal...).
@export var base_id := ""
@export var upgrade := 0
@export var gems: PackedStringArray = PackedStringArray()
@export var bonus: Dictionary = {}
## Rune gravée (voir Forge.RUNES) : "" ou identifiant de la rune.
@export var rune := ""
## Enchantements (Forge.ENCHANTS) : { enchantement: rang 1 à 5 }.
@export var enchants: Dictionary = {}
## Arme à deux mains : retire le bouclier quand on l'équipe.
@export var two_handed: bool = false
## Nombre maximum d'exemplaires dans une case d'inventaire.
@export var max_stack: int = 1

@export_group("Bonus")
@export var attack: int = 0
@export var defense: int = 0
@export var magic: int = 0
## Bonus de vitesse de déplacement (0.1 = +10 %, négatif pour les armures lourdes).
@export_range(-0.5, 0.5, 0.01) var speed_bonus: float = 0.0

@export_group("Arme")
## Style de combat : épée (combos rapides), lance (estocs), arme lourde, bâton (sorts).
@export var weapon_style: WeaponStyle = WeaponStyle.SWORD
## Portée du coup (mètres). Pour un bâton : distance parcourue par le sort.
@export var reach: float = 1.7
## Vitesse des coups (1 = normal, 1.5 = rapide, 0.6 = lent).
@export_range(0.3, 2.0, 0.05) var attack_speed: float = 1.0
## Recul supplémentaire infligé.
@export var knockback: float = 0.0
## Lance un sort magique au lieu de frapper (dégâts = magie).
@export var projectile: bool = false


@export_group("Nourriture")
## Faim rendue en mangeant (0 = ne se mange pas ; la jauge va de 0 à 100).
@export var food: float = 0.0
## Vie rendue en mangeant.
@export var food_heal: int = 0
## Plat cuisiné (compte pour le guide, rassasie mieux).
@export var food_cooked: bool = false

@export_group("Potion")
## Potion (touche Z) : part de la vie rendue, et bonus temporaires (clés des compétences) pendant potion_time secondes.
@export var potion_heal: float = 0.0
@export var potion_buff: Dictionary = {}
@export var potion_time: float = 0.0

@export_group("Agriculture")
## Culture qu'on obtient en semant cet objet sur de la terre labourée (« ble », « carotte »...). Vide = ne se sème pas.
@export var crop: String = ""


@export_group("Construction")
## Texture du bloc : si elle est renseignée, l'objet est un bloc de construction à poser.
@export var block_texture: Texture2D
## Âge du matériau (0 bois, 1 pierre, 2 pierre taillée, 3 pierre polie, 4 marbre, 5 or).
@export_range(0, 5) var block_tier: int = 0
## Demi-bloc (dalle de 50 cm) : sert de plancher, on peut marcher dessus.
@export var block_slab: bool = false
## Bloc transparent (verre).
@export var block_transparent: bool = false
## Modèle du meuble : s'il est renseigné, l'objet est un meuble à poser.
@export var furniture_model: PackedScene
## Le meuble bloque le passage.
@export var furniture_solid: bool = true
## C'est une porte (on passe à travers, et elle ferme une pièce).
@export var furniture_door: bool = false
## Le meuble éclaire (torche, lanterne...).
@export var furniture_light: bool = false


func is_block() -> bool:
	return block_texture != null


func is_furniture() -> bool:
	return furniture_model != null


func is_food() -> bool:
	return food > 0.0


func is_potion() -> bool:
	return potion_heal > 0.0 or not potion_buff.is_empty()


func is_seed() -> bool:
	return crop != ""


func is_placeable() -> bool:
	return is_block() or is_furniture()


func is_equipment() -> bool:
	return slot != Slot.NONE


## Valeur globale de l'objet (sert aux habitants pour choisir le meilleur équipement).
func power() -> float:
	return attack + defense + magic * 0.8 + speed_bonus * 20.0 + rarity * 2.0


func slot_name() -> String:
	if is_block():
		return "Bloc · %s" % TIER_NAMES[block_tier]
	if is_furniture():
		return "Mobilier"
	return SLOT_NAMES.get(slot, "?")


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Résumé des bonus, ex. « Attaque +8  Défense +2 ».
## Identifiant du modèle 3D (celui de l'objet de base pour un objet amélioré).
func model_id() -> String:
	return base_id if base_id != "" else id


func stats_text() -> String:
	var parts := []
	if attack:
		parts.append("Attaque %+d" % attack)
	if defense:
		parts.append("Défense %+d" % defense)
	if magic:
		parts.append("Magie %+d" % magic)
	if speed_bonus:
		parts.append("Vitesse %+d %%" % roundi(speed_bonus * 100.0))
	if slot == Slot.MAIN_HAND:
		parts.append("Sort à distance" if projectile else "Portée %.1f m" % reach)
	var t := "  ".join(parts)
	if not gems.is_empty():
		# la forge est chargée à l'exécution (elle dépend du héros, qui dépend des objets)
		var all_gems: Dictionary = load("res://scripts/items/forge.gd").GEMS
		var g := []
		for gem in gems:
			g.append(all_gems[gem].name if all_gems.has(gem) else gem)
		t += "\nGemmes : " + ", ".join(PackedStringArray(g))
	if (id.contains("#") or id.begins_with("arm_")) and not bonus.is_empty() and enchants.is_empty() and gems.is_empty():
		t += "\n" + affix_text()
	if not enchants.is_empty():
		t += "\nEnchantements : " + load("res://scripts/items/forge.gd").enchants_text(self)
	if rune != "":
		var all_runes: Dictionary = load("res://scripts/items/forge.gd").RUNES
		t += "\nRune : " + (all_runes[rune].name + " (" + all_runes[rune].text + ")" if all_runes.has(rune) else rune)
	return t


## Bonus tirés au sort d'un objet de butin (voir Loot), ex. « Attaque +12 %  Critique +4 % ».
func affix_text() -> String:
	const NAMES := {"atk_pct": "Attaque", "mag_pct": "Magie", "hp_pct": "Vie", "crit": "Critique",
		"crit_mult": "Dégâts critiques", "lifesteal": "Vol de vie", "cdr_pct": "Recharge", "spd_pct": "Vitesse",
		"regen": "Régénération", "def_flat": "Armure", "aspd_pct": "Vitesse d'attaque", "burn": "Brûlure", "slow": "Givre",
		"execute": "Exécution", "stun": "Assommer", "berserk": "Furie", "kill_heal": "Soin à chaque victoire", "xp": "Expérience",
		"loot": "Butin", "thorns": "Épines", "dodge": "Esquive", "poise": "Équilibre", "parry": "Parade", "absorb": "Absorption",
		"last_stand": "Dernier rempart"}
	var parts := []
	for k in bonus:
		var v := float(bonus[k])
		if k in ["regen", "def_flat", "kill_heal", "last_stand"]:
			parts.append("%s +%s" % [NAMES.get(k, k), str(snappedf(v, 0.1))])
		else:
			parts.append("%s +%s %%" % [NAMES.get(k, k), str(snappedf(v * 100.0, 0.1))])
	return "  ".join(parts)
