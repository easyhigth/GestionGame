class_name Inventory
extends RefCounted
## Sac du joueur : liste d'objets avec leurs quantités.

signal changed

## Chaque entrée : { "item": ItemData, "count": int }
var entries: Array[Dictionary] = []


func add(item: ItemData, amount: int = 1) -> void:
	if item == null or amount <= 0:
		return
	for e in entries:
		if e.item == item and e.count < item.max_stack:
			var room: int = item.max_stack - e.count
			var n := mini(room, amount)
			e.count += n
			amount -= n
			if amount == 0:
				break
	while amount > 0:
		var n := mini(item.max_stack, amount)
		entries.append({"item": item, "count": n})
		amount -= n
	changed.emit()


func remove(item: ItemData, amount: int = 1) -> bool:
	if count(item) < amount:
		return false
	for i in range(entries.size() - 1, -1, -1):
		var e := entries[i]
		if e.item != item:
			continue
		var n := mini(e.count, amount)
		e.count -= n
		amount -= n
		if e.count == 0:
			entries.remove_at(i)
		if amount == 0:
			break
	changed.emit()
	return true


func count(item: ItemData) -> int:
	var total := 0
	for e in entries:
		if e.item == item:
			total += e.count
	return total


func has(item: ItemData) -> bool:
	return count(item) > 0
