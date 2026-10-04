extends SceneTree
## Grille d'artisanat façon Minecraft : 2×2 sur soi, 3×3 à l'établi ; une bûche par case donne des planches,
## Maj+clic sur le résultat fabrique tout d'un coup (4 bûches → 16 planches) ; le livre de recettes « Placer »
## remplit la grille ; fermer le sac rend ce qui est dans la grille. Captures cg_XX_nom.png.
var f := 0
var p; var w; var items; var inv
var ok := true
var step := 0
var wait := 0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cg_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func it(id: String):
	return items.get_item(id)

func recipe_of(id: String):
	for r in items.recipes:
		if r.result and r.result.id == id:
			return r
	return null

func _process(_d) -> bool:
	f += 1
	if wait > 0:
		wait -= 1
		return false
	if f < 40:
		return false
	match step:
		0:
			p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
			inv = get_first_node_in_group("inventory_ui")
			get_first_node_in_group("raids").enabled = false
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			p.inventory.entries.clear()
			p.inventory.add(it("wood"), 10)
			p.inventory.add(it("stone"), 8)
			p.inventory.add(it("fiber"), 6)
			p.open_inventory.emit(p)
			step = 1; wait = 10
		1:
			check("sur soi : grille 2×2 (%d)" % inv._grid_side, inv._grid_side == 2 and inv._grid.size() == 4)
			# 4 bûches dans une case
			inv.grid_put(0, it("wood"), 4)
			check("4 bûches posées, 6 restent dans le sac", inv._grid[0] != null and inv._grid[0].count == 4 and p.inventory.count(it("wood")) == 6)
			var m: Array = load("res://scripts/items/craft_grid.gd").matches(inv._grid, "")
			print("   une bûche donne : ", m.map(func(r): return "%s×%d" % [r.result.id, r.result_count]))
			check("une bûche dans la grille : des planches", m.any(func(r): return r.result.id == "bloc_planches"))
			# choisir les planches parmi les résultats possibles
			for k in m.size():
				if inv.grid_recipe().result.id == "bloc_planches":
					break
				inv._grid_pick += 1
			inv._refresh()
			step = 2; wait = 6
		2:
			check("résultat : planches ×4", inv.grid_recipe().result.id == "bloc_planches" and inv.grid_recipe().result_count == 4)
			shot("01_poche_buches.png")
			# Maj+clic sur le résultat : tout fabriquer
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.shift_pressed = true
			inv._on_result_input(ev)
			check("Maj+clic : 4 bûches → 16 planches (%d)" % p.inventory.count(it("bloc_planches")), p.inventory.count(it("bloc_planches")) == 16)
			check("la grille est vide", inv._grid.all(func(g): return g == null))
			# fermer le sac rend ce qui reste dans la grille
			inv.grid_put(1, it("stone"), 5)
			check("5 pierres dans la grille", p.inventory.count(it("stone")) == 3)
			inv.close()
			check("fermer le sac : les pierres reviennent (%d)" % p.inventory.count(it("stone")), p.inventory.count(it("stone")) == 8)
			# un établi devant le héros : grille 3×3
			var fwd := Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))
			var c: Vector2i = w.cell_at(p.global_position + fwd * 1.4)
			w.build.place_furniture(c, w.terrain_height(c), it("etabli"), 0)
			inv.open_station("etabli")
			step = 3; wait = 10
		3:
			check("à l'établi : grille 3×3 (%d)" % inv._grid_side, inv._grid_side == 3 and inv._grid.size() == 9)
			var r = recipe_of("pioche_pierre")
			inv.grid_fill(r)
			var filled: Array = inv._grid.filter(func(g): return g != null)
			print("   pioche en pierre posée : ", filled.map(func(g): return "%s×%d" % [g.item.id, g.count]))
			check("« Placer » remplit la grille (%d cases)" % filled.size(), filled.size() >= 2 and inv.grid_recipe() == r)
			step = 4; wait = 6
		4:
			shot("02_etabli_pioche.png")
			var r = recipe_of("pioche_pierre")
			check("clic : une pioche en pierre", inv.grid_craft(1) == 1 and p.inventory.count(it("pioche_pierre")) == 1)
			# Maj+Placer : de quoi faire le plus de fois possible
			p.inventory.add(it("wood"), 30)
			p.inventory.add(it("stone"), 30)
			inv.grid_fill(r, true)
			var t: int = load("res://scripts/items/craft_grid.gd").times(inv._grid, r, 3)
			check("Maj+Placer : la grille permet plusieurs pioches (%d)" % t, t >= 3)
			step = 5; wait = 6
		5:
			shot("03_etabli_max.png")
			inv.close()
			# pas de recette en double sans moyen de choisir : combien de dispositions partagées ?
			var cg = load("res://scripts/items/craft_grid.gd")
			for st in ["", "etabli", "enclume"]:
				var idx: Dictionary = cg._recipes_by_signature(st)
				var multi := 0
				for k in idx:
					if idx[k].size() > 1:
						multi += 1
				print("   %s : %d dispositions, %d partagées" % [st if st != "" else "poche", idx.size(), multi])
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
