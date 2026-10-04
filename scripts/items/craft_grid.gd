class_name CraftGrid
extends RefCounted
## Grille d'artisanat façon Minecraft : 2×2 sur soi, 3×3 à un atelier (établi, enclume, meule, four...).
## On y dépose des objets du sac ; quand leur disposition correspond à une recette, le résultat apparaît à
## droite. Un clic le fabrique une fois, Maj+clic autant de fois que la grille le permet (4 bûches posées :
## 16 planches d'un coup).
##
## Chaque recette a un modèle par taille de grille : une case par objet (comme dans Minecraft). Les grosses
## recettes (plus d'objets que de cases) demandent plusieurs objets par case : le chiffre est affiché dans la
## case du modèle. Les recettes se reconnaissent au nombre de cases qu'occupe chaque objet, quelle que soit
## leur place dans la grille.

## Côté de la grille : 2 sur soi, 3 à un atelier.
static func side_for(station: String) -> int:
	return 2 if station == "" else 3


static var _patterns := {}
static var _index := {}


## Modèle d'une recette dans une grille de côté `side` : [{slot, item, qty}] (vide : trop d'objets différents).
static func pattern(r: RecipeData, side: int) -> Array:
	var key := "%d:%d" % [r.get_instance_id(), side]
	if _patterns.has(key):
		return _patterns[key]
	var cap := side * side
	var out := []
	var n_ing := r.ingredients.size()
	if n_ing == 0 or n_ing > cap:
		_patterns[key] = out
		return out
	# objets par case : 1 si la recette tient dans la grille, sinon le plus petit nombre qui la fait tenir
	var per := 1
	while true:
		var used := 0
		for i in n_ing:
			used += ceili(float(r.amount_of(i)) / per)
		if used <= cap:
			break
		per += 1
	# les cases, ingrédient par ingrédient (le plus abondant d'abord), réparties au mieux
	var order := range(n_ing)
	order.sort_custom(func(a, b): return r.amount_of(a) > r.amount_of(b))
	var cells: Array = []
	for i in order:
		var amt := r.amount_of(i)
		var k := ceili(float(amt) / per)
		for j in k:
			cells.append({"item": r.ingredients[i], "qty": amt / k + (1 if j < amt % k else 0)})
	var slots := _layout(cells.size(), side)
	for c in cells.size():
		cells[c].slot = slots[c]
		out.append(cells[c])
	_patterns[key] = out
	return out


## Places des cases du modèle : bien centrées, comme une recette dessinée.
static func _layout(n: int, side: int) -> Array:
	if side == 2:
		return [[0], [0, 1], [0, 1, 2], [0, 1, 2, 3]][n - 1]
	return [[4], [3, 5], [3, 4, 5], [0, 1, 3, 4], [1, 3, 4, 5, 7], [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5, 7],
		[0, 1, 2, 3, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 7, 8]][n - 1]


## Signature d'un contenu de grille : « id×cases » triés (les recettes se reconnaissent ainsi).
static func _signature(counts: Dictionary) -> String:
	var parts := []
	for it in counts:
		parts.append("%s×%d" % [(it as ItemData).id, counts[it]])
	parts.sort()
	return "|".join(PackedStringArray(parts))


static func _pattern_signature(pat: Array) -> String:
	var counts := {}
	for c in pat:
		counts[c.item] = counts.get(c.item, 0) + 1
	return _signature(counts)


## Recettes faites dans cette grille, rangées par signature (recalculé si la liste des recettes change).
static func _recipes_by_signature(station: String) -> Dictionary:
	var side := side_for(station)
	var key := "%s:%d" % [station, Items.recipes.size()]
	if _index.has(key):
		return _index[key]
	var all := Workshops.recipes_at(station)
	var idx := {}
	for r in all:
		var pat := pattern(r, side)
		if pat.is_empty():
			continue
		var sig := _pattern_signature(pat)
		if not idx.has(sig):
			idx[sig] = []
		idx[sig].append(r)
	_index[key] = idx
	return idx


## Recettes qui correspondent à la grille (`grid` : une case par élément, null ou {item, count}).
static func matches(grid: Array, station: String) -> Array:
	var counts := {}
	for g in grid:
		if g != null:
			counts[g.item] = counts.get(g.item, 0) + 1
	if counts.is_empty():
		return []
	return _recipes_by_signature(station).get(_signature(counts), [])


## Pour chaque case du modèle, la case de la grille qui la fournit : les plus grosses piles aux plus grosses
## demandes. {} si la grille ne correspond pas.
static func assign(grid: Array, r: RecipeData, side: int) -> Dictionary:
	var pat := pattern(r, side)
	var out := {}
	var by_item := {}
	for i in grid.size():
		if grid[i] != null:
			if not by_item.has(grid[i].item):
				by_item[grid[i].item] = []
			by_item[grid[i].item].append(i)
	for it in by_item:
		var cells: Array = by_item[it]
		cells.sort_custom(func(a, b): return grid[a].count > grid[b].count)
		var needs := pat.filter(func(c): return c.item == it)
		needs.sort_custom(func(a, b): return a.qty > b.qty)
		if needs.size() != cells.size():
			return {}
		for j in needs.size():
			out[cells[j]] = needs[j].qty
	return out


## Combien de fois la recette peut être fabriquée avec ce qu'il y a dans la grille.
static func times(grid: Array, r: RecipeData, side: int) -> int:
	var a := assign(grid, r, side)
	if a.is_empty():
		return 0
	var t := 1 << 30
	for i in a:
		t = mini(t, grid[i].count / int(a[i]))
	return t


## Retire de la grille de quoi fabriquer une fois la recette. Faux si ce n'est pas possible.
static func consume(grid: Array, r: RecipeData, side: int) -> bool:
	if times(grid, r, side) < 1:
		return false
	var a := assign(grid, r, side)
	for i in a:
		grid[i].count -= int(a[i])
		if grid[i].count <= 0:
			grid[i] = null
	return true
