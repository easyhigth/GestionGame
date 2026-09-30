class_name Harvest
extends RefCounted
## Récolte à la main, façon Minecraft : le héros frappe les décors (arbres, rochers, buissons,
## herbes, décors du village) jusqu'à les briser ; ils lâchent des ressources à ramasser.
## Il peut aussi creuser le sol (touche G / gâchette droite) : terre, sable ou cailloux.

## Coups pour briser un décor (dégâts de 1 par coup, plus avec le bon outil ou un coup chargé).
const DECOR_HP := {
	WorldGenerator.D_OAK: 5, WorldGenerator.D_PINE: 5, WorldGenerator.D_ROCK: 6,
	WorldGenerator.D_BUSH: 2, WorldGenerator.D_FLOWERS: 1, WorldGenerator.D_GRASS: 1,
	WorldGenerator.D_IRON: 8, WorldGenerator.D_GOLD: 10,
}
## Ce que lâche un décor : [identifiant, minimum, maximum].
const DECOR_LOOT := {
	WorldGenerator.D_OAK: [["wood", 3, 4]], WorldGenerator.D_PINE: [["wood", 3, 5]],
	WorldGenerator.D_BUSH: [["fiber", 2, 3]], WorldGenerator.D_FLOWERS: [["fiber", 1, 1]], WorldGenerator.D_GRASS: [["fiber", 1, 1]],
	WorldGenerator.D_ROCK: [["stone", 2, 4]],
	WorldGenerator.D_IRON: [["iron_ore", 2, 3], ["stone", 1, 2]],
	WorldGenerator.D_GOLD: [["or_brut", 1, 2], ["stone", 1, 2]],
}
## Bonus possibles : [identifiant, chance, niveau de pioche requis (0 aucun, 1 bois/pierre, 2 fer)].
const DECOR_BONUS := {
	WorldGenerator.D_OAK: [["fiber", 0.3, 0]], WorldGenerator.D_PINE: [["fiber", 0.3, 0]],
	WorldGenerator.D_ROCK: [["iron_ore", 0.3, 1], ["marbre_brut", 0.1, 2], ["or_brut", 0.05, 2]],
	WorldGenerator.D_IRON: [["iron_ore", 0.4, 1]],
	WorldGenerator.D_GRASS: [["fiber", 0.25, 0]],
}
## Niveau de pioche qu'il faut pour miner un filon (1 : n'importe quelle pioche, 2 : pioche en fer).
const VEIN_TIER := {WorldGenerator.D_IRON: 1, WorldGenerator.D_GOLD: 2}
const DECOR_COLOR := {
	WorldGenerator.D_OAK: Color(0.55, 0.38, 0.22), WorldGenerator.D_PINE: Color(0.5, 0.34, 0.2),
	WorldGenerator.D_ROCK: Color(0.62, 0.62, 0.6), WorldGenerator.D_BUSH: Color(0.35, 0.62, 0.28),
	WorldGenerator.D_FLOWERS: Color(0.5, 0.75, 0.35), WorldGenerator.D_GRASS: Color(0.5, 0.75, 0.35),
	WorldGenerator.D_IRON: Color(0.8, 0.5, 0.3), WorldGenerator.D_GOLD: Color(0.95, 0.8, 0.3),
}
## Points de vie des décors du village (par sorte).
const PROP_HP := {"hut": 14, "barrel": 3, "crate": 3, "workbench": 5, "rack": 4}
## Armes qui vont plus vite : identifiant d'arme -> sortes de décor.
const TOOL_BONUS := {
	"axe": [WorldGenerator.D_OAK, WorldGenerator.D_PINE, "prop"],
	"war_hammer": [WorldGenerator.D_ROCK, WorldGenerator.D_IRON, WorldGenerator.D_GOLD, "prop"],
}
## Outils du sac (il suffit de les avoir) : sorte -> [[identifiant, multiplicateur], ...] du meilleur au moins bon.
const TOOLS := {
	"hache": [["hache_fer", 4.0], ["hache_pierre", 3.0], ["hache_bois", 2.0]],
	"pioche": [["pioche_fer", 4.0], ["pioche_pierre", 3.0], ["pioche_bois", 2.0]],
}
## Profondeur retirée à chaque coup de pelle, et profondeur minimale du sol.
const DIG_STEP := 0.5
const DIG_FLOOR := -2.5

static var _hint_at := -100000


## Un coup du héros : frappe le décor le plus utile devant lui. Vrai si quelque chose a été touché.
static func strike(p: Player, reach: float, power: float, with_blocks := false) -> bool:
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or p.global_position.y < WorldGenerator.UNDERGROUND:
		return false
	var w := p.weapon()
	var wid: String = w.id if w else ""
	var t := find_target(p, reach, with_blocks)
	if t.has("block") or t.has("furniture"):
		hit_built(world, t, power, p)
		return true
	# 1) décors du village (cabane, tonneau...)
	if t.has("prop"):
		var best_prop: Node3D = t.prop
		var id: String = best_prop.get_meta("prop_id")
		var kind := id.get_slice("_", 0)
		var dmg := power * maxf(2.0 if "prop" in TOOL_BONUS.get(wid, []) else 1.0, tool_mult(p, "hache"))
		var left: float = float(world.prop_damage.get(id, PROP_HP.get(kind, 4))) - dmg
		var at: Vector3 = best_prop.global_position + Vector3(0, 0.8, 0)
		VoxelBurst.spawn(p, at, Color(0.6, 0.44, 0.28), 10, 2.5, 0.08, 0.35, "sphere", 8.0, false)
		if left > 0.0:
			world.prop_damage[id] = left
			Sound.play("chop", at)
			return true
		world.prop_damage.erase(id)
		Sound.play("break_wood", at)
		for l in world.remove_village_prop(id):
			_drop(world, l[0], l[1], at)
		return true
	# 2) décors naturels
	if not t.has("cell"):
		return false
	var target: Vector2i = t.cell
	var tk := world.decor_at(target)
	var mult := maxf(2.0 if tk in TOOL_BONUS.get(wid, []) else 1.0, tool_mult(p, "pioche" if is_stone(tk) else "hache"))
	hit_decor(world, target, power * mult, p)
	return true


## Ce que le héros frapperait devant lui : {"prop": décor du village} ou {"cell": case d'un décor}, ou {}.
## Les décors du village d'abord, puis arbres et rochers, puis les petites plantes.
static func find_target(p: Player, reach: float, with_blocks := false) -> Dictionary:
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or p.global_position.y < WorldGenerator.UNDERGROUND:
		return {}
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
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
		return {"prop": best_prop}
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
		return _built_target(p, world) if with_blocks else {}
	return {"cell": target}


## Bloc ou meuble posé juste devant le héros (aux pieds, puis au-dessus, puis le sol posé devant).
static func _built_target(p: Player, world: WorldGenerator) -> Dictionary:
	var grid := world.build
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
	var here := world.cell_at(p.global_position)
	var col := world.cell_at(p.global_position + fwd * 1.1)
	if col == here:
		col = world.cell_at(p.global_position + fwd * 1.6)
	var fy := floori(p.global_position.y + 0.3)
	for f in grid.furniture_in(col):
		if absf(float(f.base) - p.global_position.y) < 1.3:
			return {"furniture": grid.furniture_key(col, f.base)}
	for y in [fy, fy + 1, fy + 2, fy - 1]:
		var k := Vector3i(col.x, y, col.y)
		if grid.block_at(k) != null:
			return {"block": k}
	return {}


## Frappe un bloc ou un meuble posé : il se casse après quelques coups et revient à ramasser.
static func hit_built(world: WorldGenerator, t: Dictionary, power: float, p: Player) -> void:
	var grid := world.build
	var it: ItemData
	var key: Vector3i
	var at: Vector3
	if t.has("block"):
		key = t.block
		it = grid.block_at(key)
		at = Vector3(key.x + 0.5, key.y + 0.5, key.z + 0.5)
	else:
		key = t.furniture
		if not grid.furniture.has(key):
			return
		it = grid.furniture[key].item
		at = Vector3(key.x + 0.5, float(grid.furniture[key].base) + 0.5, key.z + 0.5)
	if it == null:
		return
	var stone := it.is_block() and it.block_tier >= 1
	var hp := 2.0
	if it.is_block():
		hp = 1.0 if it.block_transparent else (1.5 if it.block_slab else 2.0 + it.block_tier * 1.5)
	var dmg := power * tool_mult(p, "pioche" if stone else "hache")
	var dkey := ("f%s" if t.has("furniture") else "b%s") % key
	var left: float = float(world.block_damage.get(dkey, hp)) - dmg
	var col := BuildMode.it_color(it) if it.is_block() else Color(0.7, 0.55, 0.38)
	if left > 0.0:
		world.block_damage[dkey] = left
		VoxelBurst.spawn(p, at, col, 8, 2.2, 0.07, 0.3, "sphere", 8.0, false)
		Sound.play("pick" if stone else "chop", at)
		return
	Sound.play("break_stone" if stone else "break_wood", at)
	world.block_damage.erase(dkey)
	var got: ItemData = grid.remove_block(key) if t.has("block") else grid.remove_furniture(key)
	VoxelBurst.spawn(p, at, col, 20, 3.2, 0.1, 0.55, "sphere", 9.0, false)
	if got:
		_drop(world, got, 1, at - Vector3(0, 0.4, 0))


## Outil à tenir en main pour frapper ce qui est devant le héros (« » s'il n'y en a pas) :
## la meilleure hache du sac pour un arbre ou un décor du village, la meilleure pioche pour un rocher.
static func tool_for_target(p: Player, reach: float, with_blocks := false) -> String:
	var t := find_target(p, reach, with_blocks)
	if t.has("furniture"):
		return best_tool(p, "hache")
	if t.has("block"):
		var world0 := p.get_tree().get_first_node_in_group("world") as WorldGenerator
		var b: ItemData = world0.build.block_at(t.block)
		return best_tool(p, "pioche" if b and b.block_tier >= 1 else "hache")
	if t.has("prop"):
		return best_tool(p, "hache")
	if t.has("cell"):
		var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
		var kind := world.decor_at(t.cell)
		if is_stone(kind):
			return best_tool(p, "pioche")
		if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE, WorldGenerator.D_BUSH]:
			return best_tool(p, "hache")
	return ""


## Identifiant du meilleur outil de cette sorte dans le sac (« » s'il n'y en a pas).
static func best_tool(p: Player, kind: String) -> String:
	for t in TOOLS.get(kind, []):
		var it := Items.get_item(t[0]) as ItemData
		if it and p.inventory.count(it) > 0:
			return t[0]
	return ""


## Multiplicateur du meilleur outil de cette sorte (« hache », « pioche ») présent dans le sac.
static func tool_mult(p: Player, kind: String) -> float:
	for t in TOOLS.get(kind, []):
		var it := Items.get_item(t[0]) as ItemData
		if it and p.inventory.count(it) > 0:
			return float(t[1])
	return 1.0


## Abîme le décor d'une case ; il se brise quand ses points de vie tombent à zéro.
static func hit_decor(world: WorldGenerator, cell: Vector2i, dmg: float, fx_parent: Node3D) -> void:
	var p := fx_parent as Player
	var kind := world.decor_at(cell)
	if kind == WorldGenerator.D_NONE:
		return
	var at := world.cell_center(cell) + Vector3(0, 0.9 if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE] else 0.4, 0)
	var col: Color = DECOR_COLOR.get(kind, Color(0.6, 0.5, 0.4))
	# un filon ne se mine qu'avec la bonne pioche
	if p and VEIN_TIER.has(kind) and pick_tier(p) < int(VEIN_TIER[kind]):
		VoxelBurst.spawn(fx_parent, at, Color(0.6, 0.6, 0.6), 4, 1.5, 0.05, 0.2, "sphere", 8.0, false)
		# un seul rappel toutes les quelques secondes (pas à chaque coup)
		if Time.get_ticks_msec() - _hint_at > 4000:
			_hint_at = Time.get_ticks_msec()
			p.notify.emit("Il te faut une pioche pour miner ce filon." if int(VEIN_TIER[kind]) == 1 else "Il te faut une pioche en fer pour miner l'or.")
		return
	var left: float = float(world.decor_damage.get(cell, DECOR_HP.get(kind, 3))) - dmg
	if left > 0.0:
		world.decor_damage[cell] = left
		VoxelBurst.spawn(fx_parent, at, col, 8, 2.2, 0.07, 0.3, "sphere", 8.0, false)
		Sound.play("pick" if is_stone(kind) else ("step_grass" if kind in [WorldGenerator.D_FLOWERS, WorldGenerator.D_GRASS] else "chop"), at)
		return
	Sound.play("break_stone" if is_stone(kind) else ("step_grass" if kind in [WorldGenerator.D_FLOWERS, WorldGenerator.D_GRASS, WorldGenerator.D_BUSH] else "break_wood"), at)
	world.decor_damage.erase(cell)
	world.remove_decor(cell)
	VoxelBurst.spawn(fx_parent, at, col, 26, 4.0, 0.12, 0.7, "sphere", 10.0, false)
	# sans pioche, un rocher ne donne que des cailloux ; il faut une pioche en fer pour l'or et le marbre
	var tier := 2 if p == null else pick_tier(p)
	for l in loot(kind, tier):
		_drop(world, l[0], l[1], world.cell_center(cell))
	if p:
		p.harvested.emit(_kind_name(kind))


static func _kind_name(kind: int) -> String:
	match kind:
		WorldGenerator.D_OAK, WorldGenerator.D_PINE:
			return "arbre"
		WorldGenerator.D_ROCK:
			return "rocher"
		WorldGenerator.D_BUSH:
			return "buisson"
		WorldGenerator.D_IRON:
			return "filon_fer"
		WorldGenerator.D_GOLD:
			return "filon_or"
	return "plante"


## Roche : rocher ou filon (on la frappe à la pioche).
static func is_stone(kind: int) -> bool:
	return kind == WorldGenerator.D_ROCK or kind == WorldGenerator.D_IRON or kind == WorldGenerator.D_GOLD


## Niveau de la meilleure pioche du sac : 0 aucune, 1 bois ou pierre, 2 fer (un marteau de guerre compte comme 1).
static func pick_tier(p: Player) -> int:
	var best := best_tool(p, "pioche")
	if best == "pioche_fer":
		return 2
	if best != "" or (p.weapon() != null and p.weapon().id == "war_hammer"):
		return 1
	return 0


## Butin d'un décor : [[ItemData, nombre], ...] (aussi utilisé par les habitants).
static func loot(kind: int, pick := 2) -> Array:
	var out := []
	for l in DECOR_LOOT.get(kind, []):
		var it := Items.get_item(l[0]) as ItemData
		if it:
			out.append([it, randi_range(l[1], l[2])])
	for b in DECOR_BONUS.get(kind, []):
		if pick < int(b[2]):
			continue
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
		if tool_mult(p, "pioche") <= 1.0:
			p.notify.emit("Il te faut une pioche pour creuser la roche.")
			return null
	world.set_terrain_height(cell, h - DIG_STEP)
	world.refresh_cells([cell])
	Sound.play("pick" if id == "stone" else "dig", Vector3(cell.x + 0.5, h, cell.y + 0.5))
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
