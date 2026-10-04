class_name Inventory
extends RefCounted
## Sac du joueur : liste d'objets avec leurs quantités (999 au plus par case, voir ItemData.stack_size).

signal changed

## Chaque entrée : { "item": ItemData, "count": int }
var entries: Array[Dictionary] = []


func add(item: ItemData, amount: int = 1) -> void:
	if item == null or amount <= 0:
		return
	for e in entries:
		if e.item == item and e.count < item.stack_size():
			var room: int = item.stack_size() - e.count
			var n := mini(room, amount)
			e.count += n
			amount -= n
			if amount == 0:
				break
	while amount > 0:
		var n := mini(item.stack_size(), amount)
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


## Façons de trier le sac : [identifiant, nom affiché].
const SORTS := [["arrivee", "Arrivée"], ["type", "Type"], ["nom", "Nom"], ["nombre", "Nombre"], ["rarete", "Rareté"]]


## Les cases du sac dans l'ordre demandé (« arrivee » : l'ordre où on les a ramassées). Ne change pas le sac.
func sorted(mode: String) -> Array:
	var out: Array = entries.duplicate()
	var order := {}
	for i in out.size():
		order[out[i]] = i
	var by_name := func(a, b) -> bool:
		var na := (a.item as ItemData).display_name.to_lower()
		var nb := (b.item as ItemData).display_name.to_lower()
		return na < nb if na != nb else order[a] < order[b]
	match mode:
		"type":
			out.sort_custom(func(a, b):
				var fa: int = a.item.family()
				var fb: int = b.item.family()
				return fa < fb if fa != fb else by_name.call(a, b))
		"nom":
			out.sort_custom(by_name)
		"nombre":
			out.sort_custom(func(a, b): return a.count > b.count if a.count != b.count else by_name.call(a, b))
		"rarete":
			out.sort_custom(func(a, b):
				var ra: int = a.item.rarity
				var rb: int = b.item.rarity
				return ra > rb if ra != rb else by_name.call(a, b))
	return out

