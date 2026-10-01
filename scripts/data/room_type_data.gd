class_name RoomTypeData
extends Resource
## Un type de pièce (forge, boulangerie, maison...). Chaque type est un fichier .tres dans data/rooms/.
## Une pièce fermée (murs + porte) devient de ce type quand on y pose tout le mobilier demandé.

@export var id: String = ""
@export var display_name: String = "Pièce"
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
## Mobilier demandé : identifiant de l'objet -> nombre.
@export var required: Dictionary = {}
## Taille minimum de la pièce (cases au sol).
@export var min_cells: int = 4

@export_group("Travail")
## Métier des habitants qui y travaillent (forgeron, boulanger...). Vide = pas de poste.
@export var job_id: String = ""
@export var job_name: String = ""
## Nombre de postes.
@export var job_slots: int = 0
## Objet produit par chaque travailleur, et tous les combien de secondes.
@export var production: ItemData
@export var production_count: int = 1
@export var production_interval: float = 90.0
## Plusieurs produits possibles : l'un d'eux au hasard à chaque fois (à la place de `production`).
@export var production_pool: Array[ItemData] = []

@export_group("Effets")
## Lits : habitants logés.
@export var beds: int = 0
## Bonus pour le héros tant que la pièce existe (xp, magic, regen, attack, defense : pourcentages ou valeurs).
@export var hero_bonus: Dictionary = {}
## Texte affiché pour décrire l'effet.
@export var effect_text: String = ""


## Mobilier manquant pour cette pièce (identifiant -> nombre manquant).
func missing(counts: Dictionary) -> Dictionary:
	var out := {}
	for k in required:
		var need := int(required[k]) - int(counts.get(k, 0))
		if need > 0:
			out[k] = need
	return out
