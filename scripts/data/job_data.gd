class_name JobData
extends Resource
## Un métier (forgeron, chasseur...). Chaque métier est un fichier .tres dans data/jobs/.
## Il donne des objets de départ et un petit avantage permanent.

@export var display_name: String = "Métier"
@export_multiline var description: String = ""
## Objets de départ (dans le sac). Ils vont par paires avec starting_counts.
@export var starting_items: Array[ItemData] = []
@export var starting_counts: PackedInt32Array = PackedInt32Array()

@export_group("Avantages")
@export var bonus_health: int = 0
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_magic: int = 0
## Bonus de vitesse de déplacement (0.05 = +5 %).
@export var bonus_speed: float = 0.0
## Points de vie rendus par seconde en plus.
@export var bonus_regen: float = 0.0
## Multiplie les chances de butin des monstres (1.3 = +30 %).
@export var loot_multiplier: float = 1.0

## Résumé des avantages pour les menus.
func perks_text() -> String:
	var parts := []
	if bonus_health: parts.append("Vie %+d" % bonus_health)
	if bonus_attack: parts.append("Attaque %+d" % bonus_attack)
	if bonus_defense: parts.append("Défense %+d" % bonus_defense)
	if bonus_magic: parts.append("Magie %+d" % bonus_magic)
	if bonus_speed: parts.append("Vitesse %+d %%" % roundi(bonus_speed * 100))
	if bonus_regen: parts.append("Régénération +%.1f PV/s" % bonus_regen)
	if loot_multiplier != 1.0: parts.append("Butin %+d %%" % roundi((loot_multiplier - 1.0) * 100))
	return ", ".join(parts)
