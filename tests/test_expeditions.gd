extends SceneTree
## Lot 3 des classes : le héros ne bouge pas en frappant (seuls les coups reçus le font reculer), spécialisations
## du niveau 30 (une voie, son ultime, titre), expéditions des habitants (départ, chance, retour, butin,
## sauvegarde) ; captures : arbre (spécialisations) et panneau des expéditions.
var f := 0
var p; var w; var hud; var ex; var items
var ok := true
var mark := 0
var pos0 := Vector3.ZERO
var attacking := false
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ex_"

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Eldrin"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/mage.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 5:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); hud = get_first_node_in_group("hud")
		ex = get_first_node_in_group("expeditions"); items = root.get_node("Items")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		check("gestionnaire d'expéditions présent", ex != null)
		# coups sans élan
		p.equipment.equip(items.get_item("sword_iron"))
		p.velocity = Vector3.ZERO
		pos0 = p.global_position
		var combo: Array = load("res://scripts/combat/move_library.gd").combo_for(p.weapon_style())
		check("le héros frappe", p.perform(combo[0], 1.0))
		mark = Engine.get_physics_frames()
		attacking = true
	if attacking and Engine.get_physics_frames() - mark < 40:
		if not p.in_move():
			var combo2: Array = load("res://scripts/combat/move_library.gd").combo_for(p.weapon_style())
			p.perform(combo2[1 % combo2.size()], 1.0)
		f = 6
		return false
	if f == 7:
		attacking = false
		var moved := Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length()
		check("frapper ne fait pas avancer le héros (%.2f m)" % moved, moved < 0.15)
		# un coup reçu, lui, fait reculer
		p._invulnerable_left = 0.0
		var foe = load("res://scenes/enemies/enemy.tscn").instantiate()
		foe.data = load("res://data/enemies/loup.tres")
		w.add_child(foe)
		foe.global_position = p.global_position + Vector3(0, 0, 1.5)
		p.receive_hit(5, foe, 6.0)
		check("un coup reçu fait reculer (%s)" % str(p._knockback), p._knockback.length() > 0.5)
		foe.queue_free()
		# spécialisations
		check("voie refusée avant le niveau 30", p.talent_block_reason("spec_mage_a").contains("niveau 30"))
		p.set_level_to(30)
		check("deux voies pour le mage", load("res://scripts/hero/talent_tree.gd").spec_nodes("mage").size() == 4)
		check("choisir Archimage", p.unlock_talent("spec_mage_a"))
		check("ultime offert et rangé", p.talents.has("spec_mage_a_ult") and p.ability_slots.has("spec_mage_a_ult"))
		check("l'autre voie est fermée", p.talent_block_reason("spec_mage_b") != "" and not p.unlock_talent("spec_mage_b"))
		check("titre : Archimage", p.class_title() == "Archimage")
		check("l'ultime se lance", p.cast_ability(p.ability_slots.find("spec_mage_a_ult")))
		p.reset_talents()
		check("Tout oublier libère la voie", not p.talents.has("spec_mage_a") and p.talent_block_reason("spec_mage_b") == "")
		p.unlock_talent("spec_mage_a")
		# expéditions
		var avail: Array = ex.available()
		print("habitants disponibles : ", avail.size())
		check("des habitants disponibles", avail.size() >= 2)
		var party := avail.slice(0, 2)
		var c1: float = load("res://scripts/kingdom/expeditions.gd").chance("cueillette", party.slice(0, 1))
		var c2: float = load("res://scripts/kingdom/expeditions.gd").chance("cueillette", party)
		check("plus on est nombreux, plus la chance monte (%.2f -> %.2f)" % [c1, c2], c2 > c1)
		var n_before: int = get_nodes_in_group("villagers").size()
		check("départ en cueillette", ex.start("cueillette", party))
		check("ils quittent le village", get_nodes_in_group("villagers").size() == n_before - 2 and not party[0].visible)
		check("une seule expédition au Campement", ex.can_start("chasse", avail.slice(2, 3)) != "")
		set_meta("party", party)
		set_meta("names", party.map(func(v): return v.villager_name))
		root.get_node("SaveGame").save_game("8")
		hud.expedition_panel.open()
	if f == 30:
		shot("02_expeditions.png")
		hud.expedition_panel.close()
		root.get_node("SaveGame").load_game("8")
		mark = Time.get_ticks_msec()
	if f == 31:
		if Time.get_ticks_msec() - mark < 3000:
			f = 30
			OS.delay_msec(20)
			return false
	if f == 40:
		p = get_first_node_in_group("player"); ex = get_first_node_in_group("expeditions"); hud = get_first_node_in_group("hud")
		check("expédition rechargée (%d en route)" % ex.active.size(), ex.active.size() == 1 and get_nodes_in_group("away_villagers").size() == 2)
		check("la voie est rechargée", p.class_title() == "Archimage")
		var e = ex.active[0]
		ex.active.clear()
		var baies: int = p.inventory.count(items.get_item("baies"))
		var res: Dictionary = ex.finish(e, 0.0)
		check("réussite : butin pour le héros (baies %d -> %d)" % [baies, p.inventory.count(items.get_item("baies"))], res.ok and p.inventory.count(items.get_item("baies")) > baies)
		check("les habitants sont revenus", get_nodes_in_group("away_villagers").is_empty() and e.members.all(func(v): return v.visible and v.is_in_group("villagers")))
		# un échec : des blessés
		var party2: Array = ex.available().slice(0, 1)
		ex.start("repaire", party2)
		var e2 = ex.active.pop_back()
		var r2: Dictionary = ex.finish(e2, 0.999)
		check("échec : moins de butin et un blessé", not r2.ok and party2[0].health.current < party2[0].health.max_health)
		get_first_node_in_group("kingdom").rank = 6
		# événements d'expédition
		var party3: Array = ex.available().slice(0, 2)
		ex.start("chasse", party3)
		var e3 = ex.active[0]
		ex.trigger_event(e3, "voyageur")
		check("un événement attend un choix", e3.has("event"))
		var left0: float = e3.left
		ex.choose(e3, 0)
		check("choix : soigner le voyageur (+1 min)", e3.get("recruit", false) and e3.left > left0 and not e3.has("event"))
		var strangers0 := get_nodes_in_group("strangers").size()
		ex.active.clear()
		ex.finish(e3, 0.0)
		var newcomers := get_nodes_in_group("strangers").filter(func(v): return v.has_meta("attracted") and v.recruit_offer.get("items", []).is_empty())
		check("le voyageur sauvé attend au village (%d)" % newcomers.size(), get_nodes_in_group("strangers").size() > strangers0 and not newcomers.is_empty())
		var party4: Array = ex.available().slice(0, 1)
		ex.start("mine", party4)
		var e4 = ex.active[0]
		var c4: float = e4.chance
		ex.trigger_event(e4, "grotte")
		set_meta("e4c", c4)
		hud.expedition_panel.open()
	if f == 52:
		shot("03_evenement.png")
		var e4 = ex.active[0]
		hud.expedition_panel.close()
		ex.active.clear()
		ex.finish(e4, 0.999)
		check("sans réponse, le choix prudent est pris au retour", e4.get("choice", "") == "Passer leur chemin" and is_equal_approx(float(e4.chance), float(get_meta("e4c"))))
		hud.talent_ui.open()
		hud.talent_ui._tab.emit_signal("pressed")
		hud.talent_ui._selected = "spec_mage_a"
		hud.talent_ui._refresh()
	if f == 60:
		shot("01_specialisations.png")
		hud.talent_ui.close_ui()
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
