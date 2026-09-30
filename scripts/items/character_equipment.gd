class_name CharacterEquipment
extends Node
## Équipement porté par un personnage (joueur ou habitant).
## Les objets équipés apparaissent sur le modèle 3D (nœud « Visual » du personnage).

signal changed

## Objets équipés au départ (utile pour préparer un personnage dans l'éditeur).
@export var starting_items: Array[ItemData] = []
## Le personnage affiché (VoxelCharacter). Par défaut : le nœud « Visual » du parent.
@export var visual: VoxelCharacter

## Emplacement (ItemData.Slot) -> ItemData
var slots := {}


func _ready() -> void:
	if visual == null:
		visual = get_parent().get_node_or_null("Visual") as VoxelCharacter
	for item in starting_items:
		equip(item)


func get_item(slot: int) -> ItemData:
	return slots.get(slot)


## Équipe l'objet. Renvoie les objets retirés pour lui faire de la place.
func equip(item: ItemData) -> Array[ItemData]:
	var removed: Array[ItemData] = []
	if item == null or not item.is_equipment():
		return removed
	var old := unequip(item.slot, false)
	if old:
		removed.append(old)
	if item.two_handed:
		var shield := unequip(ItemData.Slot.OFF_HAND, false)
		if shield:
			removed.append(shield)
	elif item.slot == ItemData.Slot.OFF_HAND:
		var weapon := get_item(ItemData.Slot.MAIN_HAND)
		if weapon and weapon.two_handed:
			removed.append(unequip(ItemData.Slot.MAIN_HAND, false))
	slots[item.slot] = item
	if visual:
		visual.show_equipment(item.slot, item.model_id())
	changed.emit()
	return removed


func unequip(slot: int, notify := true) -> ItemData:
	var old: ItemData = slots.get(slot)
	if old == null:
		return null
	slots.erase(slot)
	if visual:
		visual.show_equipment(slot, "")
	if notify:
		changed.emit()
	return old


## Vrai si l'objet est meilleur que celui porté au même emplacement.
func is_upgrade(item: ItemData) -> bool:
	if item == null or not item.is_equipment():
		return false
	var current := get_item(item.slot)
	return current == null or item.power() > current.power()


func total_attack() -> int:
	var t := 0
	for it in slots.values():
		t += it.attack
	return t


func total_defense() -> int:
	var t := 0
	for it in slots.values():
		t += it.defense
	return t


func total_magic() -> int:
	var t := 0
	for it in slots.values():
		t += it.magic
	return t


func speed_multiplier() -> float:
	var t := 1.0
	for it in slots.values():
		t += it.speed_bonus
	return maxf(t, 0.3)


## Remet l'équipement sur le modèle 3D (après un changement de race par exemple).
func refresh_visuals() -> void:
	if visual == null:
		return
	for s in ItemData.Slot.values():
		var it: ItemData = slots.get(s)
		visual.show_equipment(s, it.id if it else "")
