class_name Aim
extends RefCounted
## Visée à la souris, façon Minecraft : un rayon part de la caméra (par le viseur au centre de l'écran en
## 3e et 1re personne, par le curseur de la souris en vue de dessus) et s'arrête sur la première chose
## touchée : un ennemi, un bloc ou un meuble posé, un décor (arbre, rocher, buisson, filon, plante), un
## décor du village, une culture, ou le sol.
## Le résultat dit quoi (« kind »), où (« point »), la face touchée (« normal ») et de quoi le retrouver
## (« key » d'un bloc, « cell » d'un décor, « node » d'un ennemi ou d'un décor du village).
## C'est lui qui décide où l'on frappe, ce que l'on récolte ou casse, et où l'on pose un bloc.

const REACH_HIT := 3.2     # distance (depuis le héros) jusqu'où l'on frappe, récolte ou casse
const REACH_PLACE := 5.5   # distance jusqu'où l'on pose un bloc


## Forme d'un décor naturel dans sa case : [demi-largeur, hauteur].
static func decor_shape(kind: int) -> Vector2:
	match kind:
		WorldGenerator.D_OAK, WorldGenerator.D_PINE:
			return Vector2(0.42, 3.6)
		WorldGenerator.D_ROCK, WorldGenerator.D_IRON, WorldGenerator.D_GOLD:
			return Vector2(0.42, 0.95)
		WorldGenerator.D_BUSH:
			return Vector2(0.4, 0.8)
		WorldGenerator.D_FLOWERS, WorldGenerator.D_GRASS:
			return Vector2(0.3, 0.45)
	return Vector2(0.4, 0.8)


## Intersection rayon / boîte (méthode des plaques). Renvoie [t, normale] ou [] si rien.
static func ray_box(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3, t_max: float) -> Array:
	var t0 := 0.0
	var t1 := t_max
	var n := Vector3.ZERO
	for a in 3:
		var oa := o[a]
		var da := d[a]
		if absf(da) < 1e-6:
			if oa < lo[a] or oa > hi[a]:
				return []
			continue
		var inv := 1.0 / da
		var ta := (lo[a] - oa) * inv
		var tb := (hi[a] - oa) * inv
		var sign := -1.0
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
			sign = 1.0
		if ta > t0:
			t0 = ta
			n = Vector3.ZERO
			n[a] = sign
		t1 = minf(t1, tb)
		if t0 > t1:
			return []
	if n == Vector3.ZERO:
		n = -d.normalized()
	return [t0, n]


## Lance le rayon. `p` : le héros (pour exclure son propre corps et choisir les ennemis).
static func cast(p: Player, origin: Vector3, dir: Vector3, max_t := 40.0) -> Dictionary:
	var world := p.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null:
		return {}
	dir = dir.normalized()
	var best := {"kind": "none", "t": max_t, "point": origin + dir * max_t, "normal": Vector3.UP}
	# 1) ennemis : une boîte autour de chaque corps
	for n in p.get_tree().get_nodes_in_group(p.hostile_group()):
		var c := n as Combatant
		if c == null or not c.is_alive():
			continue
		var cp := c.global_position
		if cp.distance_to(origin) > max_t + 3.0:
			continue
		var r := c.body_radius + 0.2
		var hgt := 1.9 * (c.visual.height_scale() if c.visual else 1.0)
		var hit := ray_box(origin, dir, cp + Vector3(-r, 0, -r), cp + Vector3(r, hgt, r), best.t)
		if not hit.is_empty() and float(hit[0]) < float(best.t):
			best = {"kind": "enemy", "t": hit[0], "point": origin + dir * float(hit[0]), "normal": hit[1], "node": c}
	# 1 bis) animaux (poules, moutons, vaches) : on peut les chasser
	for n in p.get_tree().get_nodes_in_group("farm_animals"):
		var an := n as Node3D
		if an == null or not an.has_method("is_alive") or not an.is_alive():
			continue
		var ap := an.global_position
		if ap.distance_to(origin) > max_t + 3.0:
			continue
		var ah := float(an.info().label_y) * 0.8
		var ar := 0.25 + ah * 0.25
		var hit := ray_box(origin, dir, ap + Vector3(-ar, 0, -ar), ap + Vector3(ar, ah, ar), best.t)
		if not hit.is_empty() and float(hit[0]) < float(best.t):
			best = {"kind": "animal", "t": hit[0], "point": origin + dir * float(hit[0]), "normal": hit[1], "node": an}
	# 2) décors du village (cabanes, tonneaux...) près du héros
	var hc := world.cell_at(p.global_position)
	var under := p.global_position.y < WorldGenerator.UNDERGROUND
	if not under:
		for n in world.village_props_in(Rect2i(hc - Vector2i(8, 8), Vector2i(17, 17))):
			var box := WorldGenerator.prop_box(n)
			var center: Vector3 = n.global_position + box.position
			var hit := ray_box(origin, dir, center - box.size * 0.5, center + box.size * 0.5, best.t)
			if not hit.is_empty() and float(hit[0]) < float(best.t):
				best = {"kind": "prop", "t": hit[0], "point": origin + dir * float(hit[0]), "normal": hit[1], "node": n}
	# 3) le monde, colonne par colonne le long du rayon (sol, blocs, meubles, décors, cultures)
	var grid: BuildGrid = world.dungeon_grid if under else world.build
	var fm := p.get_tree().get_first_node_in_group("farming") as Farming
	var cell := Vector2i(floori(origin.x), floori(origin.z))
	var step_x := 1 if dir.x > 0.0 else -1
	var step_z := 1 if dir.z > 0.0 else -1
	var t_dx := absf(1.0 / dir.x) if absf(dir.x) > 1e-6 else INF
	var t_dz := absf(1.0 / dir.z) if absf(dir.z) > 1e-6 else INF
	var next_x := ((cell.x + (1 if step_x > 0 else 0)) - origin.x) / dir.x if absf(dir.x) > 1e-6 else INF
	var next_z := ((cell.y + (1 if step_z > 0 else 0)) - origin.z) / dir.z if absf(dir.z) > 1e-6 else INF
	var t_in := 0.0
	var guard := 0
	while t_in < float(best.t) and guard < 160:
		guard += 1
		var t_out := minf(next_x, next_z)
		var hit := _column(world, grid, fm, cell, origin, dir, t_in, minf(t_out, float(best.t)), under)
		if not hit.is_empty() and float(hit.t) < float(best.t):
			best = hit
			break
		if next_x < next_z:
			cell.x += step_x
			t_in = next_x
			next_x += t_dx
		else:
			cell.y += step_z
			t_in = next_z
			next_z += t_dz
	best["dist"] = (best.point as Vector3).distance_to(p.global_position + Vector3(0, 1.0, 0))
	return best


## Ce que touche le rayon dans une colonne, entre t_in et t_out.
static func _column(world: WorldGenerator, grid: BuildGrid, fm: Farming, cell: Vector2i, o: Vector3, d: Vector3,
		t_in: float, t_out: float, under: bool) -> Dictionary:
	var out := {}
	var best_t := INF
	var lo2 := Vector3(cell.x, 0, cell.y)
	var y_in := o.y + d.y * t_in
	var y_out := o.y + d.y * t_out
	var y_min := minf(y_in, y_out)
	var y_max := maxf(y_in, y_out)
	# le sol (terrain en marches)
	if not under:
		var h := world.terrain_height(cell)
		var t := world.terrain_type(cell)
		if (t == WorldGenerator.WATER or t == WorldGenerator.DEEP) and h < world.water_surface:
			h = world.water_surface
		if y_min <= h:
			var th := t_in
			var nrm := Vector3(-signf(d.x), 0, 0) if absf(d.x) > absf(d.z) else Vector3(0, 0, -signf(d.z))
			if y_in > h and absf(d.y) > 1e-6:
				th = (h - o.y) / d.y
				nrm = Vector3.UP
			if th < best_t:
				best_t = th
				out = {"kind": "terrain", "t": th, "point": o + d * th, "normal": nrm, "cell": cell, "height": h}
	# blocs posés (y compris un portillon ouvert, qu'on peut viser pour le casser)
	if grid:
		for y in grid._block_cols.get(cell, []):
			var key := Vector3i(cell.x, y, cell.y)
			var it: ItemData = grid.blocks.get(key)
			if it == null:
				continue
			var top := float(y) + grid.block_height(it)
			if top < y_min - 1.0 or float(y) > y_max + 1.0:
				continue
			var hit := ray_box(o, d, lo2 + Vector3(0, y, 0), lo2 + Vector3(1, top, 1), best_t)
			if not hit.is_empty() and float(hit[0]) < best_t:
				best_t = hit[0]
				out = {"kind": "block", "t": hit[0], "point": o + d * float(hit[0]), "normal": hit[1], "key": key, "cell": cell}
		for f in grid.furniture_touching(cell):
			var base := float(f.base)
			var hit := ray_box(o, d, lo2 + Vector3(0.08, base, 0.08), lo2 + Vector3(0.92, base + 1.0, 0.92), best_t)
			if not hit.is_empty() and float(hit[0]) < best_t:
				best_t = hit[0]
				out = {"kind": "furniture", "t": hit[0], "point": o + d * float(hit[0]), "normal": hit[1],
					"key": grid.furniture_key(f.col, base), "cell": cell, "base": base}
	if under:
		return out
	var g := world.terrain_height(cell)
	# décors naturels
	var kind := world.decor_at(cell)
	if kind != WorldGenerator.D_NONE:
		var sh := decor_shape(kind)
		var c := Vector3(cell.x + 0.5, g, cell.y + 0.5)
		var hit := ray_box(o, d, c + Vector3(-sh.x, 0, -sh.x), c + Vector3(sh.x, sh.y, sh.x), best_t)
		if not hit.is_empty() and float(hit[0]) < best_t:
			best_t = hit[0]
			out = {"kind": "decor", "t": hit[0], "point": o + d * float(hit[0]), "normal": hit[1], "cell": cell, "decor": kind}
	# cultures mûres
	if fm and fm.is_ripe(cell):
		var c2 := Vector3(cell.x + 0.5, g, cell.y + 0.5)
		var hit2 := ray_box(o, d, c2 + Vector3(-0.42, 0, -0.42), c2 + Vector3(0.42, 0.7, 0.42), best_t)
		if not hit2.is_empty() and float(hit2[0]) < best_t:
			best_t = hit2[0]
			out = {"kind": "crop", "t": hit2[0], "point": o + d * float(hit2[0]), "normal": hit2[1], "cell": cell}
	return out


## Case où poser un bloc d'après la visée : la case voisine de la face visée (sur un bloc : contre cette
## face ; sur le sol : au-dessus, ou à côté si c'est le flanc d'une marche). Vector3i.MAX si rien.
static func place_key(a: Dictionary) -> Vector3i:
	match str(a.get("kind", "none")):
		"block":
			var n: Vector3 = a.normal
			return (a.key as Vector3i) + Vector3i(roundi(n.x), roundi(n.y), roundi(n.z))
		"terrain":
			var n2: Vector3 = a.normal
			var cell: Vector2i = a.cell
			if n2.y > 0.5:
				return Vector3i(cell.x, floori(float(a.height) + 0.45), cell.y)
			var side := cell + Vector2i(roundi(n2.x), roundi(n2.z))
			return Vector3i(side.x, floori((a.point as Vector3).y), side.y)
		"furniture":
			var n3: Vector3 = a.normal
			var c3: Vector2i = a.cell
			if n3.y > 0.5:
				return Vector3i(c3.x, floori(float(a.base) + 1.0), c3.y)
			return Vector3i(c3.x + roundi(n3.x), floori(float(a.base)), c3.y + roundi(n3.z))
	return Vector3i.MAX


## Boîte de ce qui est visé (pour son contour). AABB vide si rien à entourer.
static func target_box(world: WorldGenerator, a: Dictionary) -> AABB:
	if world == null or a.is_empty():
		return AABB()
	match str(a.kind):
		"block":
			var k: Vector3i = a.key
			var it: ItemData = world.build.blocks.get(k) if world.build else null
			if it == null and world.dungeon_grid:
				it = world.dungeon_grid.blocks.get(k)
			var h := BuildGrid.block_height(it) if it else 1.0
			return AABB(Vector3(k.x, k.y, k.z), Vector3(1, h, 1))
		"furniture":
			var c: Vector2i = a.cell
			return AABB(Vector3(c.x + 0.08, float(a.base), c.y + 0.08), Vector3(0.84, 1.0, 0.84))
		"decor":
			var c2: Vector2i = a.cell
			var sh := decor_shape(int(a.decor))
			var g := world.terrain_height(c2)
			return AABB(Vector3(c2.x + 0.5 - sh.x, g, c2.y + 0.5 - sh.x), Vector3(sh.x * 2.0, sh.y, sh.x * 2.0))
		"crop":
			var c3: Vector2i = a.cell
			return AABB(Vector3(c3.x + 0.08, world.terrain_height(c3), c3.y + 0.08), Vector3(0.84, 0.7, 0.84))
		"prop":
			var n := a.node as Node3D
			if not is_instance_valid(n):
				return AABB()
			var box := WorldGenerator.prop_box(n)
			return AABB(n.global_position + box.position - box.size * 0.5, box.size)
	return AABB()


## Arêtes d'un cube unité centré (contour du bloc visé, comme dans Minecraft) : des baguettes épaisses,
## bien visibles de loin (une ligne simple ne fait qu'un pixel).
static func wire_box(t := 0.035) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	# 12 arêtes : 4 selon x, 4 selon y, 4 selon z
	var edges := []
	for a in [-h, h]:
		for b in [-h, h]:
			edges.append([Vector3(0, a, b), Vector3(1 + t * 2, t, t)])
			edges.append([Vector3(a, 0, b), Vector3(t, 1 + t * 2, t)])
			edges.append([Vector3(a, b, 0), Vector3(t, t, 1 + t * 2)])
	for e in edges:
		var c: Vector3 = e[0]
		var sz: Vector3 = e[1] * 0.5
		var v := [c + Vector3(-sz.x, -sz.y, -sz.z), c + Vector3(sz.x, -sz.y, -sz.z), c + Vector3(sz.x, sz.y, -sz.z), c + Vector3(-sz.x, sz.y, -sz.z),
			c + Vector3(-sz.x, -sz.y, sz.z), c + Vector3(sz.x, -sz.y, sz.z), c + Vector3(sz.x, sz.y, sz.z), c + Vector3(-sz.x, sz.y, sz.z)]
		for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
			st.add_vertex(v[f[0]]); st.add_vertex(v[f[1]]); st.add_vertex(v[f[2]])
			st.add_vertex(v[f[0]]); st.add_vertex(v[f[2]]); st.add_vertex(v[f[3]])
	return st.commit()
