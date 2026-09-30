class_name Harvest
extends RefCounted
## Récolte à la main, façon Minecraft : le héros frappe les décors (arbres, rochers, buissons,
## herbes, décors du village) jusqu'à les briser ; ils lâchent des ressources à ramasser.
## Il peut aussi creuser le sol (touche G / gâchette droite) : terre, sable ou cailloux.

## Coups pour briser un décor (dégâts de 1 par coup, plus avec le bon outil ou un coup chargé).
const DECOR_HP := {
	WorldGenerator.D_OAK: 5, WorldGenerator.D_PINE: 5, WorldGenerator.D_ROCK: 6,
	WorldGenerator.D_BUSH: 2, WorldGenerator.D_FLOWERS: 1, WorldGenerator.D_GRASS: 1,
}
## Ce que lâche un décor : [identifiant, minimum, maximum].
const DECOR_LOOT := {
	WorldGenerator.D_OAK: [["wood", 3, 4]], WorldGenerator.D_PINE: [["wood", 3, 5]],
	WorldGenerator.D_BUSH: [["fiber", 2, 3]], WorldGenerator.D_FLOWERS: [["fiber", 1, 1]], WorldGenerator.D_GRASS: [["fiber", 1, 1]],
	WorldGenerator.D_ROCK: [["stone", 2, 4]],
}
## Bonus possibles : [identifiant, chance].
const DECOR_BONUS := {
	WorldGenerator.D_OAK: [["fiber", 0.3]], WorldGenerator.D_PINE: [["fiber", 0.3]],
	WorldGenerator.D_ROCK: [["iron_ore", 0.3], ["marbre_brut", 0.1], ["or_brut", 0.05]],
	WorldGenerator.D_GRASS: [["fiber", 0.25]],
}
const DECOR_COLOR := {
	WorldGenerator.D_OAK: Color(0.55, 0.38, 0.22), WorldGenerator.D_PINE: Color(0.5, 0.34, 0.2),
	WorldGenerator.D_ROCK: Color(0.62, 0.62, 0.6), WorldGenerator.D_BUSH: Color(0.35, 0.62, 0.28),
	WorldGenerator.D_FLOWERS: Color(0.5, 0.75, 0.35), WorldGenerator.D_GRASS: Color(0.5, 0.75, 0.35),
}
## Points de vie des décors du village (par sorte).
const PROP_HP := {"hut": 14, "barrel": 3, "crate": 3, "workbench": 5, "rack": 4}
## Outils qui vont plus vite : identifiant d'arme -> sortes de décor.
const TOOL_BONUS := {
	"axe": [WorldGenerator.D_OAK, WorldGenerator.D_PINE, "prop"],
	"war_hammer": [WorldGenerator.D_ROCK, "prop"],
}
## Profondeur retirée à chaque coup de pelle, et profondeur minimale du sol.
const DIG_STEP := 0.5
const DIG_FLOOR := -2.5


## Un coup du héros : frappe le décor le plus utile devant lui. Vrai si quelque chose a été touché.
static func strike(p: Player, reach: float, power: float) -> bool:
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or p.global_position.y < WorldGenerator.UNDERGROUND:
		return false
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
	var w := p.weapon()
	var wid: String = w.id if w else ""
	# 1) décors du village (cabane, tonneau...)
	var best_prop: Node3D = null
	var best_d := INF
	for n in world.village_props_in(Rect2i(world.cell_at(p.global_position) - Vector2i(4, 4), Vector2i(9, 9))):
		var box := WorldGenerator.prop_box(n)
		var off: Vector3 = n.global_position - p.global_position
		off.y = 0.0
		var d := maxf(0.0, off.length() - maxf(box.size.x, box.size.z) * 0.45)
		if d <= reach and (off.length() < 0.3 or off.normalized().dot(fwd) > 0.2) and d < best_d:
			best_d = d
			best_prop = n
	if best_prop:
		var id: String = best_prop.get_meta("prop_id")
		var kind := id.get_slice("_", 0)
		var dmg := power * (2.0 if "prop" in TOOL_BONUS.get(wid, []) else 1.0)
		var left: float = float(world.prop_damage.get(id, PROP_HP.get(kind, 4))) - dmg
		var at: Vector3 = best_prop.global_position + Vector3(0, 0.8, 0)
		VoxelBurst.spawn(p, at, Color(0.6, 0.44, 0.28), 10, 2.5, 0.08, 0.35, "sphere", 8.0, false)
		if left > 0.0:
			world.prop_damage[id] = left
			return true
		world.prop_damage.erase(id)
		for l in world.remove_village_prop(id):
			_drop(world, l[0], l[1], at)
		return true
	# 2) décors naturels : arbres et rochers d'abord, herbes ensuite
	var here := world.cell_at(p.global_position)
	var target := Vector2i(-99999, -99999)
	var best_score := INF
	var r := ceili(reach) + 1
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := here + Vector2i(dx, dz)
			var kind := world.decor_at(c)
			if kind == WorldGenerator.D_NONE:
				continue
			var off: Vector3 = world.cell_center(c) - p.global_position
			off.y = 0.0
			var d := off.length()
			if d > reach + 0.55 or (d > 0.5 and off.normalized().dot(fwd) < 0.35):
				continue
			var small := kind in [WorldGenerator.D_FLOWERS, WorldGenerator.D_GRASS]
			var score := d + (3.0 if small else 0.0)
			if score < best_score:
				best_score = score
				target = c
	if best_score == INF:
		return false
	hit_decor(world, target, power * (2.0 if world.decor_at(target) in TOOL_BONUS.get(wid, []) else 1.0), p)
	return true


## Abîme le décor d'une case ; il se brise quand ses points de vie tombent à zéro.
static func hit_decor(world: WorldGenerator, cell: Vector2i, dmg: float, fx_parent: Node3D) -> void:
	var kind := world.decor_at(cell)
	if kind == WorldGenerator.D_NONE:
		return
	var at := world.cell_center(cell) + Vector3(0, 0.9 if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE] else 0.4, 0)
	var col: Color = DECOR_COLOR.get(kind, Color(0.6, 0.5, 0.4))
	var left: float = float(world.decor_damage.get(cell, DECOR_HP.get(kind, 3))) - dmg
	if left > 0.0:
		world.decor_damage[cell] = left
		VoxelBurst.spawn(fx_parent, at, col, 8, 2.2, 0.07, 0.3, "sphere", 8.0, false)
		return
	world.decor_damage.erase(cell)
	world.remove_decor(cell)
	VoxelBurst.spawn(fx_parent, at, col, 26, 4.0, 0.12, 0.7, "sphere", 10.0, false)
	for l in loot(kind):
		_drop(world, l[0], l[1], world.cell_center(cell))


## Butin d'un décor : [[ItemData, nombre], ...] (aussi utilisé par les habitants).
static func loot(kind: int) -> Array:
	var out := []
	for l in DECOR_LOOT.get(kind, []):
		var it := Items.get_item(l[0]) as ItemData
		if it:
			out.append([it, randi_range(l[1], l[2])])
	for b in DECOR_BONUS.get(kind, []):
		if randf() < float(b[1]):
			var it := Items.get_item(b[0]) as ItemData
			if it:
				out.append([it, 1])
	return out


## Creuse la case devant le héros. Renvoie l'objet obtenu (null si impossible).
static func dig(p: Player) -> ItemData:
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or p.global_position.y < WorldGenerator.UNDERGROUND:
		return null
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
	var cell := world.cell_at(p.global_position + fwd * 1.0)
	if cell == world.cell_at(p.global_position):
		cell = world.cell_at(p.global_position + fwd * 1.5)
	var t := world.terrain_type(cell)
	var h := world.terrain_height(cell)
	if t == WorldGenerator.WATER or t == WorldGenerator.DEEP or h - DIG_STEP < DIG_FLOOR:
		return null
	if not world.build.column(cell).is_empty() or not world.build.furniture_in(cell).is_empty():
		return null
	if world.village_prop_at(cell, h - 0.5) != null:
		return null
	# un décor sur la case : on le frappe d'abord
	if world.decor_at(cell) != WorldGenerator.D_NONE:
		hit_decor(world, cell, 1.0, p)
		return null
	var id := "bloc_terre"
	if t == WorldGenerator.SAND:
		id = "bloc_sable"
	elif t == WorldGenerator.STONE:
		id = "stone"
	world.set_terrain_height(cell, h - DIG_STEP)
	world.refresh_cells([cell])
	var at := Vector3(cell.x + 0.5, h - DIG_STEP + 0.1, cell.y + 0.5)
	VoxelBurst.spawn(p, at, Color(0.55, 0.42, 0.28) if id != "stone" else Color(0.6, 0.6, 0.58), 12, 2.8, 0.09, 0.45, "up", 9.0, false)
	var it := Items.get_item(id) as ItemData
	if it:
		_drop(world, it, 1, at)
	if t == WorldGenerator.STONE and randf() < 0.08:
		_drop(world, Items.get_item("iron_ore"), 1, at)
	return it


## Laisse tomber des objets à ramasser (ils se ramassent en marchant dessus).
static func _drop(world: WorldGenerator, it: ItemData, n: int, at: Vector3) -> void:
	if it == null or n <= 0:
		return
	var a := randf() * TAU
	var pos := at + Vector3(cos(a), 0, sin(a)) * randf_range(0.1, 0.45)
	world.spawn_pickup(it, pos, n)
