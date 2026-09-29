class_name RecipeData
extends Resource
## Une recette d'artisanat. Chaque recette est un fichier .tres dans data/recipes/.
## Les ingrédients et les quantités vont par paires : ingredients[0] x amounts[0], etc.

@export var result: ItemData
@export var result_count: int = 1
@export var ingredients: Array[ItemData] = []
@export var amounts: PackedInt32Array = PackedInt32Array()
## Si activé, il faut être près d'un établi pour fabriquer cet objet.
@export var needs_workbench: bool = false


func amount_of(index: int) -> int:
	return amounts[index] if index < amounts.size() else 1


func can_craft(inventory: Inventory, near_workbench: bool) -> bool:
	if result == null or (needs_workbench and not near_workbench):
		return false
	for i in ingredients.size():
		if inventory.count(ingredients[i]) < amount_of(i):
			return false
	return true


func craft(inventory: Inventory, near_workbench: bool) -> bool:
	if not can_craft(inventory, near_workbench):
		return false
	for i in ingredients.size():
		inventory.remove(ingredients[i], amount_of(i))
	inventory.add(result, result_count)
	return true
