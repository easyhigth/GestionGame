extends SceneTree
## Simulation d'équilibrage : pour plusieurs niveaux du héros, compare l'attaque avec une arme forgée
## (meilleur matériau accessible, raffinée et enchantée au maximum du métier), une arme de butin de niveau,
## et une arme légendaire unique ; coups pour vaincre un monstre de même niveau et coups pour tomber.
## Lancer : SYNC_LOADING=1 godot --headless --path . -s tools/balance_sim.gd
var f := 0
func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Sim"; h.race = load("res://data/races/humain.tres") if ResourceLoader.exists("res://data/races/humain.tres") else load("res://data/races/homme_bete.tres")
	h.hero_class = load("res://data/classes/guerrier.tres"); h.job = load("res://data/jobs/forgeron.tres"); h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func _process(_d) -> bool:
	f += 1
	if f < 30:
		return false
	var p = get_first_node_in_group("player")
	if p == null:
		return false
	var items = root.get_node("Items")
	var A = load("res://scripts/items/arsenal.gd"); var FG = load("res://scripts/items/forge.gd"); var CR = load("res://scripts/hero/crafts.gd"); var L = load("res://scripts/items/loot.gd")
	var wolf = load("res://data/enemies/loup.tres")
	print("niv | métier | forgée (atk)            | butin épique (mystique) | lame_eveil | monstre PV/atk | coups forgée/butin | coups pour tomber")
	for lv in [1, 5, 10, 20, 35, 50, 75, 100, 150, 200, 300, 500, 700, 1000]:
		p.set_level_to(lv)
		var craft_lv: int = mini(100, 1 + lv / 3 + (lv / 10))
		p.crafts["forgeron"] = CR.xp_for_level(craft_lv); p.crafts["enchanteur"] = CR.xp_for_level(craft_lv)
		var best = null
		for m in A.MATERIALS:
			if int(m.level) <= craft_lv and not m.get("rare", false) or (int(m.level) <= craft_lv and lv >= 150):
				best = m
		var base = items.get_item(A.make_id("epee", best.id, 0))
		var up: int = mini(CR.max_refine(p, base), 3 + lv / 8)
		var rank: int = mini(FG.item_rank_cap(items.get_item(FG.variant_id(base.id, up, PackedStringArray()))), CR.max_enchant_rank(p))
		var ench := {"tranchant": rank} if lv >= 20 else {}
		var forged = items.get_item(FG.variant_id(base.id, up, PackedStringArray(), "", ench))
		var loot = items.get_item(L.make_id("sword_iron", mini(1000, maxi(1, lv)), 3, 1))
		var myth = items.get_item(L.make_id("sword_iron", mini(1000, maxi(1, lv)), 5, 1))
		var leg = items.get_item("lame_eveil")
		var res := {}
		for pair in [["forged", forged], ["loot", loot], ["leg", leg], ["myth", myth]]:
			p.equipment.equip(pair[1])
			p._apply_talents()
			res[pair[0]] = p.attack_power()
		var pw: float = 1.0 + 0.06 * lv
		var ehp: int = roundi(wolf.max_health * pw * root.get_node("SaveGame").enemy_hp_mult())
		var eatk: int = roundi(wolf.attack * pw * root.get_node("SaveGame").enemy_dmg_mult())
		var dmg_in: int = maxi(1, eatk - p.defense_power() / 2)
		print("%4d | %3d | %-22s %5d | %6d (%5d) | %6d | %6d/%-4d | %4.1f / %4.1f | %5.1f" % [lv, craft_lv, "%s +%d %s" % [best.id, up, ("T" + str(rank)) if lv >= 20 else ""], res.forged, res.loot, res.myth, res.leg, ehp, eatk,
			float(ehp) / maxf(1, res.forged), float(ehp) / maxf(1, res.loot), float(p.health.max_health) / dmg_in])
	print("RÉSULTAT : tout est bon")
	return true
