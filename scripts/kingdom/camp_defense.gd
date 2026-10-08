class_name CampDefense
extends RefCounted
## Défense du camp : ce que le joueur bâtit pour se protéger des raids. Chaque point de défense
## réduit la bande de pillards (1 pillard en moins pour 3 points), allonge l'alerte et renforce les gardes.
##  - murets, barrières et portillons autour du camp : 1 point pour 10 blocs (6 points au plus) ;
##  - blocs de pierre empilés en tours ou remparts (3 blocs de haut ou plus) : 1 point pour 8 colonnes (6 au plus) ;
##  - torches et lanternes du camp : 1 point pour 6 (3 au plus), la nuit ils voient les pillards venir ;
##  - gardes (habitants du camp d'entraînement) : 2 points chacun (10 au plus).

const WALL_PREFIXES := ["muret_", "barriere_", "portillon_"]
const MAX_POINTS := 25


## Calcule la défense du camp : {walls, towers, lights, guards, points}.
static func compute(world: WorldGenerator, center: Vector3, radius: float, guards: int) -> Dictionary:
	var walls := 0
	var cols := {}
	var grid: BuildGrid = world.build if world else null
	if grid:
		var r2 := radius * radius
		for k in grid.blocks:
			var dx := float(k.x) + 0.5 - center.x
			var dz := float(k.z) + 0.5 - center.z
			if dx * dx + dz * dz > r2:
				continue
			var it: ItemData = grid.blocks[k]
			var wall := false
			for p in WALL_PREFIXES:
				if it.id.begins_with(p):
					wall = true
			if wall:
				walls += 1
			elif it.block_tier >= 1:
				var c := Vector2i(k.x, k.z)
				cols[c] = int(cols.get(c, 0)) + 1
	var towers := 0
	for c in cols:
		if int(cols[c]) >= 3:
			towers += 1
	var lights := 0
	if grid:
		for fk in grid.furniture:
			var f: Dictionary = grid.furniture[fk]
			var id: String = f.item.id if f.item else ""
			if id.begins_with("torche") or id.begins_with("lanterne"):
				var p: Vector3 = Vector3(fk.x + 0.5, 0, fk.z + 0.5)
				if Vector2(p.x - center.x, p.z - center.z).length() <= radius:
					lights += 1
	var points := mini(walls / 10, 6) + mini(towers / 8, 6) + mini(lights / 6, 3) + mini(guards * 2, 10)
	return {"walls": walls, "towers": towers, "lights": lights, "guards": guards, "points": mini(points, MAX_POINTS)}


## Texte court pour le panneau du royaume.
static func describe(d: Dictionary) -> String:
	return "Défense du camp : %d point(s) (murets %d, tours %d, torches %d, gardes %d)" % [
		int(d.points), int(d.walls), int(d.towers), int(d.lights), int(d.guards)]
