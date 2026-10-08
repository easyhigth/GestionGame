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
	WorldGenerator.D_BUSH: [["fiber", 1, 2], ["baies", 1, 3]], WorldGenerator.D_FLOWERS: [["fiber", 1, 1]], WorldGenerator.D_GRASS: [["fiber", 1, 1]],
	WorldGenerator.D_ROCK: [["stone", 2, 4]],
	WorldGenerator.D_IRON: [["iron_ore", 2, 3], ["stone", 1, 2]],
	WorldGenerator.D_GOLD: [["or_brut", 1, 2], ["stone", 1, 2]],
}
## Bonus possibles : [identifiant, chance, niveau de pioche requis (0 aucun, 1 bois/pierre, 2 fer)].
const DECOR_BONUS := {
	WorldGenerator.D_OAK: [["fiber", 0.3, 0]], WorldGenerator.D_PINE: [["fiber", 0.3, 0]],
	WorldGenerator.D_ROCK: [["iron_ore", 0.3, 1], ["marbre_brut", 0.1, 2], ["or_brut", 0.05, 2], ["mithril_brut", 0.006, 2],
		["minerai_cuivre", 0.3, 1], ["minerai_etain", 0.18, 1], ["charbon", 0.3, 1], ["obsidienne", 0.012, 2]],
	WorldGenerator.D_IRON: [["iron_ore", 0.4, 1], ["mithril_brut", 0.02, 2], ["gemme_saphir", 0.01, 2], ["gemme_emeraude", 0.01, 2], ["gemme_amethyste", 0.008, 2],
		["charbon", 0.4, 1], ["minerai_argent", 0.12, 2], ["minerai_cuivre", 0.2, 1]],
	WorldGenerator.D_GOLD: [["mithril_brut", 0.03, 2], ["orichalque", 0.002, 2], ["gemme_topaze", 0.02, 2], ["gemme_rubis", 0.015, 2], ["gemme_diamant", 0.005, 2],
		["minerai_argent", 0.3, 2], ["obsidienne", 0.05, 2]],
	WorldGenerator.D_GRASS: [["fiber", 0.25, 0], ["graines_ble", 0.45, 0]],
	WorldGenerator.D_FLOWERS: [["graines_ble", 0.2, 0]],
	WorldGenerator.D_BUSH: [["carotte", 0.2, 0], ["pomme_de_terre", 0.15, 0]],
}
## Expérience de métier d'un décor brisé.
const CRAFT_XP := {WorldGenerator.D_OAK: 7, WorldGenerator.D_PINE: 7, WorldGenerator.D_ROCK: 6, WorldGenerator.D_IRON: 14,
	WorldGenerator.D_GOLD: 22, WorldGenerator.D_BUSH: 2, WorldGenerator.D_GRASS: 1, WorldGenerator.D_FLOWERS: 1}
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
const DIG_FLOOR := -40.0
## Profondeur d'un trou à partir de laquelle on tombe sur la roche (il faut une pioche).
const DIG_ROCK_DEPTH := 2.0
## Profondeur à laquelle on perce la voûte d'une galerie souterraine.
const DIG_CAVE_DEPTH := 5.0
## Hauteur d'origine des cases creusées (pour mesurer la profondeur d'un trou).
static var _dug_from := {}

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
	if t.has("crop"):
		harvest_crop(p, t.crop)
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
		# rien à frapper, mais on vise le sol tout près : on creuse (comme dans Minecraft)
		if p.aim_active() and str(p.aim.get("kind", "")) == "terrain" and float(p.aim.get("dist", INF)) <= Aim.REACH_HIT + 0.8 \
				and not p._enemy_close(4.0):
			return dig(p) != null
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
	if world == null:
		return {}
	# à la souris : seulement ce qui est sous le viseur (ou le curseur), à portée
	if p.aim_active():
		return p.aim_target()
	if p.global_position.y < WorldGenerator.UNDERGROUND:
		# dans une grotte de montagne : on creuse les parois
		return _built_target(p, world) if with_blocks and _cave(p) != null else {}
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
	# cultures mûres : comme un arbre (avant l'herbe haute)
	var fm := p.get_tree().get_first_node_in_group("farming") as Farming
	var crop_cell := Vector2i(-99999, -99999)
	if fm:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := here + Vector2i(dx, dz)
				if not fm.is_ripe(c):
					continue
				var off: Vector3 = world.cell_center(c) - p.global_position
				off.y = 0.0
				var d := off.length()
				if d > reach + 0.55 or (d > 0.5 and off.normalized().dot(fwd) < 0.35):
					continue
				if d < best_score:
					best_score = d
					crop_cell = c
	if crop_cell.x != -99999:
		return {"crop": crop_cell}
	if best_score == INF:
		return _built_target(p, world) if with_blocks else {}
	return {"cell": target}


## Récolte une culture mûre à la main : tout tombe au sol à ramasser.
static func harvest_crop(p: Player, cell: Vector2i) -> void:
	var fm := p.get_tree().get_first_node_in_group("farming") as Farming
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if fm == null or world == null:
		return
	var crop: String = fm.crop_at(cell).get("c", "")
	var got: Array = fm.harvest(cell)
	for l in got:
		_drop(world, l[0], l[1], world.cell_center(cell) + Vector3(0, 0.2, 0))
	if crop != "":
		p.crop_harvested.emit(crop)
		Crafts.gain(p, "fermier", 8.0)
		if not got.is_empty() and randf() < Crafts.double_chance(p, "fermier"):
			_drop(world, got[0][0], got[0][1], world.cell_center(cell) + Vector3(0, 0.2, 0))
		if not got.is_empty() and Crafts.hero_job(p) == "fermier" and randf() < 0.3:
			_drop(world, got[0][0], got[0][1], world.cell_center(cell) + Vector3(0, 0.2, 0))


## Bloc ou meuble posé juste devant le héros (aux pieds, puis au-dessus, puis le sol posé devant).
## La grotte de montagne où se trouve le héros (null ailleurs).
static func _cave(p: Player) -> MountainCaves:
	var mc := p.get_tree().get_first_node_in_group("mountain_caves") as MountainCaves
	return mc if mc and mc.active and p.global_position.y < WorldGenerator.UNDERGROUND else null


static func _built_target(p: Player, world: WorldGenerator) -> Dictionary:
	var cave := _cave(p)
	var grid := world.dungeon_grid if cave else world.build
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
	var here := world.cell_at(p.global_position)
	var col := world.cell_at(p.global_position + fwd * 1.1)
	if col == here:
		col = world.cell_at(p.global_position + fwd * 1.6)
	var fy := floori(p.global_position.y + 0.3)
	for f in grid.furniture_touching(col):
		if absf(float(f.base) - p.global_position.y) < 1.3:
			return {"furniture": grid.furniture_key(f.col, f.base)}
	for y in [fy, fy + 1, fy + 2, fy - 1]:
		var k := Vector3i(col.x, y, col.y)
		if grid.block_at(k) != null:
			return {"block": k}
	return {}


## Frappe un bloc ou un meuble posé : il se casse après quelques coups et revient à ramasser.
static func hit_built(world: WorldGenerator, t: Dictionary, power: float, p: Player) -> void:
	var cave := _cave(p)
	var grid := world.dungeon_grid if cave else world.build
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
	VoxelBurst.spawn(p, at, col, 20, 3.2, 0.1, 0.55, "sphere", 9.0, false)
	if cave and t.has("block"):
		# grotte : la paroi s'ouvre, la roche continue derrière ; un minerai rend son métal
		if not cave.can_mine(key):
			return
		var res := cave.mine(key)
		if not res.is_empty() and res[0]:
			_drop(world, res[0], int(res[1]), at - Vector3(0, 0.4, 0), cave._content)
		return
	var got: ItemData = grid.remove_block(key) if t.has("block") else grid.remove_furniture(key)
	if got and got.has_meta("stair_base"):
		got = Items.get_item(got.get_meta("stair_base"))
	if got and got.id == WorldGenerator.FLAG_ID:
		# le drapeau revient directement au sac (on ne le perd pas) : plus de camp tant qu'il n'est pas replanté
		p.inventory.add(got, 1)
		p.notify.emit("Drapeau du royaume repris : plus de camp (ni de raids) tant que tu ne l'as pas replanté.")
		return
	if got:
		_drop(world, got, 1, at - Vector3(0, 0.4, 0))


## Outil à tenir en main pour frapper ce qui est devant le héros (« » s'il n'y en a pas) :
## la meilleure hache du sac pour un arbre ou un décor du village, la meilleure pioche pour un rocher.
static func tool_for_target(p: Player, reach: float, with_blocks := false) -> String:
	var t := find_target(p, reach, with_blocks)
	if t.has("crop"):
		return "houe" if p.inventory.count(Items.get_item("houe")) > 0 else ""
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
	var drops := loot(kind, tier)
	for l in drops:
		_drop(world, l[0], l[1], world.cell_center(cell))
	if p:
		p.harvested.emit(_kind_name(kind))
		# métiers : le mineur et le bûcheron progressent, et récoltent parfois le double
		var craft := "mineur" if is_stone(kind) else ("bucheron" if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE] else "fermier")
		Crafts.gain(p, craft, float(CRAFT_XP.get(kind, 1)), 1 + (30 if kind == WorldGenerator.D_GOLD else (12 if kind == WorldGenerator.D_IRON else 0)))
		if not drops.is_empty() and randf() < Crafts.double_chance(p, craft):
			_drop(world, drops[0][0], drops[0][1], world.cell_center(cell))
		# savoir-faire du métier du héros (voir Crafts.JOB_SPECIALTY)
		var job := Crafts.hero_job(p)
		var extra := 0.0
		if job == "mineur" and is_stone(kind) or job == "bucheron" and kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE]:
			extra = 0.25
		elif job == "herboriste" and kind == WorldGenerator.D_BUSH:
			extra = 0.35
		if not drops.is_empty() and randf() < extra:
			_drop(world, drops[0][0], drops[0][1], world.cell_center(cell))
		if job == "joaillier" and is_stone(kind) and randf() < 0.05:
			var gem := Items.get_item(Crafts.GEMS.pick_random())
			if gem:
				_drop(world, gem, 1, world.cell_center(cell))
				p.notify.emit("Ton œil de joaillier repère une gemme : %s !" % gem.display_name)
	# chaque région a ses essences de bois et ses pierres (voir BlockCatalog)
	var zone := world.zone_at(world.cell_center(cell))
	var rid: String = zone.type.id if not zone.is_empty() and zone.get("type") else "prairie"
	if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE]:
		var wid := BlockCatalog.wood_for_region(rid, cell)
		if wid != "wood":
			_drop(world, Items.get_item(wid), randi_range(2, 3), world.cell_center(cell))
	elif kind == WorldGenerator.D_ROCK and tier >= 1:
		if randf() < 0.6:
			_drop(world, Items.get_item(BlockCatalog.stone_for_region(rid, cell)), randi_range(1, 2), world.cell_center(cell))
		if randf() < 0.07:
			_drop(world, Items.get_item("lazurite"), 1, world.cell_center(cell))


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
	# à la souris : on creuse la case visée (le sol, ou la case d'une plante visée)
	if p.aim_active():
		var a: Dictionary = p.aim
		if a.is_empty() or float(a.get("dist", INF)) > Aim.REACH_HIT + 0.8 or not str(a.get("kind")) in ["terrain", "decor", "crop"]:
			return null
		cell = a.cell
	var t := world.terrain_type(cell)
	var h := world.terrain_height(cell)
	if t == WorldGenerator.WATER or t == WorldGenerator.DEEP or h - DIG_STEP < DIG_FLOOR:
		return null
	if not world.build.column(cell).is_empty() or not world.build.furniture_in(cell).is_empty():
		return null
	if world.village_prop_at(cell, h - 0.5) != null:
		return null
	# une culture sur la case : on l'arrache d'abord (la graine revient)
	var fm := p.get_tree().get_first_node_in_group("farming") as Farming
	if fm and not fm.crop_at(cell).is_empty():
		var s := fm.uproot(cell)
		if s:
			_drop(world, s, 1, world.cell_center(cell) + Vector3(0, 0.2, 0))
		return null
	# un décor sur la case : on le frappe d'abord
	if world.decor_at(cell) != WorldGenerator.D_NONE:
		hit_decor(world, cell, 1.0, p)
		return null
	var id := "bloc_terre"
	var from_h: float = _dug_from.get(cell, h)
	_dug_from[cell] = from_h
	var depth := from_h - (h - DIG_STEP)
	if t == WorldGenerator.SAND and depth < DIG_ROCK_DEPTH:
		id = "bloc_sable"
	elif t == WorldGenerator.STONE or depth > DIG_ROCK_DEPTH:
		# sous la terre, la roche : il faut une pioche
		t = WorldGenerator.STONE
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
	if t == WorldGenerator.STONE and randf() < (0.08 if depth < DIG_CAVE_DEPTH else 0.14):
		_drop(world, Items.get_item("iron_ore"), 1, at)
	if t == WorldGenerator.STONE and depth >= 3.0 and randf() < 0.1:
		_drop(world, Items.get_item("charbon"), 1, at)
	# assez profond : on perce la voûte d'une galerie souterraine
	if depth >= DIG_CAVE_DEPTH:
		_break_into_cave(p, world, cell)
	# gravier et argile en creusant (l'argile surtout près de l'eau, dans le sable)
	if t != WorldGenerator.STONE and randf() < 0.18:
		_drop(world, Items.get_item("gravier"), 1, at)
	if randf() < (0.3 if t == WorldGenerator.SAND else 0.1):
		_drop(world, Items.get_item("argile"), 1, at)
	return it


## Laisse tomber des objets à ramasser (ils se ramassent en marchant dessus).
static func _drop(world: WorldGenerator, it: ItemData, n: int, at: Vector3, parent: Node = null) -> void:
	if it == null or n <= 0:
		return
	var a := randf() * TAU
	var pos := at + Vector3(cos(a), 0, sin(a)) * randf_range(0.1, 0.45)
	if parent:
		world.spawn_pickup(it, pos, n, parent)
	else:
		world.spawn_pickup(it, pos, n)


## Le trou atteint une galerie souterraine : on y descend (et on remonte au bord du trou).
static func _break_into_cave(p: Player, world: WorldGenerator, cell: Vector2i) -> void:
	var mc := p.get_tree().get_first_node_in_group("mountain_caves") as MountainCaves
	if mc == null or mc.active:
		return
	# on ressort sur le bord du trou, du côté le plus haut
	var best := Vector2i(0, 1)
	var best_h := -INF
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var hh := world.terrain_height(cell + d)
		if hh > best_h:
			best_h = hh
			best = d
	p.notify.emit("La roche cède sous ta pioche : une galerie souterraine s'ouvre !")
	Sound.play("break_stone", p.global_position, 2.0)
	mc.enter({"id": "creuse_%d_%d" % [cell.x, cell.y], "cell": cell, "dir": -best, "pos": world.cell_center(cell)})

