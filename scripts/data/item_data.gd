class_name ItemData
extends Resource
## Un objet : matériau, arme ou pièce d'armure.
## Chaque objet est un fichier .tres dans data/items/ : duplique-en un pour en créer un nouveau.

enum Slot { NONE, MAIN_HAND, OFF_HAND, HEAD, CHEST, ARMS, LEGS, BACK }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }
## Façon de se battre avec l'arme (choisit la suite de coups du combo).
enum WeaponStyle { SWORD, SPEAR, HEAVY, STAFF, UNARMED }

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
}

## Identifiant unique (sert aussi de nom du modèle 3D dans les fichiers <race>_equipment.glb
## ou materials.glb).
@export var id: String = ""
@export var display_name: String = "Objet"
@export_multiline var description: String = ""
## Emplacement où l'objet s'équipe (« NONE » = matériau d'artisanat).
@export var slot: Slot = Slot.NONE
@export var rarity: Rarity = Rarity.COMMON
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


func is_equipment() -> bool:
	return slot != Slot.NONE


## Valeur globale de l'objet (sert aux habitants pour choisir le meilleur équipement).
func power() -> float:
	return attack + defense + magic * 0.8 + speed_bonus * 20.0 + rarity * 2.0


func slot_name() -> String:
	return SLOT_NAMES.get(slot, "?")


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Résumé des bonus, ex. « Attaque +8  Défense +2 ».
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
	return "  ".join(parts)
