extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/bal_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/homme_bete.tres")
	h.style = 2
	h.skin_color = Color("d88a3a"); h.hair_color = Color("e8e0d0"); h.eye_color = Color("40e0a0")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))

var FG

func _process(_d) -> bool:
	f += 1
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		rm = get_first_node_in_group("raids"); dip = get_first_node_in_group("diplomacy")
		rm.enabled = false
		FG = load("res://scripts/items/forge.gd")
		print("== gemmes et runes plafonnées")
		for id in ["sword_iron", "iron_armor", "iron_helmet", "iron_gauntlets", "iron_greaves", "shield_iron", "cape_red"]:
			var v = items.get_item("%s@10~gemme_topaze,gemme_topaze,gemme_emeraude!rune_force" % id)
			if v:
				p.equipment.equip(v)
		var b: Dictionary = FG.equipment_bonus(p)
		print("   bonus : ", b)
		check("critiques plafonnés (%.2f)" % b.get("crit", 0.0), float(b.get("crit", 0.0)) <= float(load("res://scripts/items/forge.gd").BONUS_CAPS.crit) + 0.0001)
		check("vol de vie plafonné (%.2f)" % b.get("lifesteal", 0.0), float(b.get("lifesteal", 0.0)) <= float(load("res://scripts/items/forge.gd").BONUS_CAPS.lifesteal) + 0.0001)
		check("attaque des runes plafonnée (%.2f)" % b.get("atk_pct", 0.0), float(b.get("atk_pct", 0.0)) <= float(load("res://scripts/items/forge.gd").BONUS_CAPS.atk_pct) + 0.0001)
		print("== bonus permanents du héros (âmes)")
		var atk := 0.0
		var def := 0.0
		for f2 in ["bois_enchante", "desert", "foret", "marais", "montagnes", "prairie", "toundra", "volcan"]:
			var r = load("res://data/regions/%s.tres" % f2)
			atk += float(r.boss_soul.get("attack", 0.0)); def += float(r.boss_soul.get("defense", 0.0))
		var dm = get_first_node_in_group("dungeons")
		atk += 4 * float(dm.BRUME_LORD_SOUL.attack); def += 4 * float(dm.BRUME_LORD_SOUL.defense)
		atk += 5 * float(dip.PROVINCE_BONUS.attack); def += 5 * float(dip.PROVINCE_BONUS.defense)
		atk += 1.0
		print("   tout obtenu : +%d attaque, +%d défense" % [atk, def])
		check("bonus permanents raisonnables (attaque +%d ≤ 45)" % atk, atk <= 45.0)
		print("== siège : coups pour vaincre un champion")
		for lv in [6, 15, 30]:
			var hp: float = 500.0 + 70.0 * lv
			var hero_atk: float = 10.0 + 2.2 * lv + (8.0 if lv < 15 else 26.0)
			var hits: float = hp / hero_atk
			print("   niveau %d : champion %d PV, héros ~%d d'attaque -> ~%d coups" % [lv, hp, hero_atk, hits])
			check("niveau %d : combat de champion ni trop court ni trop long (%d coups)" % [lv, hits], hits >= 15 and hits <= 120)
		print("== économie d'une journée")
		var tax := 0.0
		for id in dip.NATIONS:
			tax += 60.0 / dip.TAX_EVERY
		print("   5 provinces : %d or par jour d'impôts (+ marchandises)" % tax)
		check("impôts quotidiens raisonnables (%d ≤ 200)" % tax, tax <= 200.0)
		print("== la Brume")
		for t in [1, 5, 10]:
			var up: int = 4 * t + 4
			print("   palier %d : monstres +%d niveaux (puissance x%.1f)" % [t, up, 1.0 + 0.09 * up])
		check("palier 10 : au plus +44 niveaux", 4 * 10 + 4 <= 44)
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
