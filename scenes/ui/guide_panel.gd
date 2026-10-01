class_name GuidePanel
extends PanelContainer
## Guide des premiers pas : une suite d'objectifs affichée à gauche de l'écran
## (récolter, fabriquer des outils, construire un abri, survivre à la première nuit).
## L'avancement est sauvegardé ; une fois fini, le guide disparaît.

## [identifiant, texte, conseil, nombre à atteindre]
const STEPS := [
	["arbre", "Coupe 3 arbres", "Frappe-les avec ton arme (clic gauche / X). Le bois tombe au sol : marche dessus.", 3],
	["rocher", "Casse 2 rochers", "Les rochers donnent des cailloux. Sans pioche, pas de minerai.", 2],
	["outil", "Fabrique une hache ou une pioche", "Inventaire (I) → Artisanat → Outils. Il suffit de l'avoir dans ton sac.", 1],
	["planches", "Fabrique des planches", "Inventaire (I) → Artisanat → Construction : 1 bois donne 4 planches.", 1],
	["abri", "Construis un abri", "Une pièce fermée avec une porte et un lit : pose les blocs à la main (C pour choisir, V pour poser) ou avec le mode construction (B).", 1],
	["torche", "Pose une torche", "Choisis-la avec C et pose-la avec V. Les monstres n'apparaissent pas près des lumières.", 1],
	["repas", "Mange un repas cuit", "Baies (buissons) ou viande (animaux) : cuis-les près du feu de camp ou d'un four (Artisanat → Cuisine), puis mange avec H.", 1],
	["nuit", "Survis à ta première nuit", "Quand la nuit tombe, dors dans ton lit (E) ou tiens jusqu'au matin.", 1],
	# chapitre 2 : l'âge du fer
	["filon_fer", "Mine 2 filons de fer", "Des rochers piquetés d'orange, dans la roche des collines. Il faut une pioche.", 2],
	["four", "Fabrique et pose un four", "Près d'un établi : 6 cailloux et 2 blocs de terre (Artisanat → Mobilier). Pose-le avec V.", 1],
	["lingot", "Fonds 2 lingots de fer", "Près du four : 2 minerais de fer et 1 bois donnent 1 lingot (Artisanat → Matériaux).", 2],
	["enclume", "Fabrique et pose une enclume", "4 lingots de fer, près d'un établi. Toutes les pièces en fer se forgent à côté d'elle.", 1],
	["pioche_fer", "Forge une pioche en fer", "À l'enclume : 2 lingots et 2 bois (Artisanat → Outils). Elle mine l'or et le marbre.", 1],
	# chapitre 3 : le village
	["reserve", "Remplis la réserve du village", "Ouvre le royaume (U) et dépose de la nourriture. Une boulangerie ou une grange la remplissent aussi.", 1],
	["lits", "Un lit pour chaque habitant", "Une maison (pièce fermée, porte, un lit et un coffre) donne 2 lits ; un dortoir (4 lits et un coffre) en donne 6.", 1],
	["bonheur", "Rends ton village heureux", "Bonheur moyen de 70 % : nourriture, lits, taverne, temple... Le royaume (U) dit ce qui manque.", 1],
	# chapitre 4 : les champs
	["houe", "Fabrique une houe", "Inventaire (I) → Artisanat → Outils : 2 bois et 2 cailloux. Elle laboure l'herbe et la terre.", 1],
	["semer", "Sème 6 graines", "Coupe les hautes herbes pour trouver des graines de blé. Choisis-les (C) et sème devant toi (V).", 6],
	["recolte", "Récolte 3 cultures mûres", "Frappe une culture mûre (épis dorés, carottes sorties) pour la récolter. Près de l'eau, ça pousse plus vite.", 3],
	["fermier", "Nomme un fermier", "E près d'un habitant → Poste de travail → Champs (4 cases labourées au moins). Confie-lui des graines dans le royaume (U).", 1],
	# chapitre 5 : le commerce
	["vendre", "Vends 10 objets au marchand", "Un marchand ambulant passe au village tous les 3 jours (le royaume, U, dit quand). E près de lui : vends tes surplus.", 10],
	["acheter", "Achète quelque chose au marchand", "Graines, outils, lingots, meubles, équipement : son stock change à chaque visite.", 1],
	["marche", "Construis un marché", "Pièce fermée avec 2 étals et un comptoir (9 cases). Le marchand vient tous les 2 jours et paie mieux ; un marchand du village y gagne de l'or.", 1],
	# chapitre 6 : l'élevage
	["mangeoire", "Fabrique et pose une mangeoire", "Près d'un établi : 2 bois et 2 fibres (Artisanat → Mobilier). Pose-la avec V là où sera l'enclos ; des barrières le fermeront.", 1],
	["apprivoiser", "Mène une bête à la mangeoire", "Poules : graines de blé en main (C). Moutons et vaches : du blé. Elles te suivent : amène-les près de la mangeoire.", 1],
	["produits", "Obtiens 3 produits de tes bêtes", "Œufs, laine, lait apparaissent près des bêtes nourries par la réserve du village. Un fermier à la grange les ramasse.", 3],
	# chapitre 7 : l'eau
	["canne", "Fabrique une canne à pêche", "Inventaire (I) → Artisanat → Outils : 3 bois et 2 fibres.", 1],
	["pecher", "Pêche 3 poissons", "Canne en main (C), V face à l'eau pour lancer. Quand ça mord : V, puis V quand le curseur est dans le vert.", 3],
	["grotte", "Ouvre un coffre englouti", "Nage (entre dans l'eau), plonge avec G et remonte avec Espace. Au fond des eaux profondes, des cristaux bleus marquent l'entrée d'une grotte (E).", 1],
	# chapitre 8 : l'aventure
	["donjon", "Vaincs le boss d'un donjon", "E devant une entrée de donjon. Attention aux dalles qui rougissent (piques) ; le Gardien et la salle secrète valent le détour.", 1],
	["forge", "Renforce un objet à +1", "Près d'une enclume : Inventaire (I) → Artisanat → Forge. Les gemmes et les runes s'y posent aussi.", 1],
	["potion", "Bois une potion (Z)", "Une potion de soin se prépare au chaudron avec 8 baies ; un Laboratoire d'alchimie en fabrique d'autres.", 1],
	["succes", "Ouvre les succès et le bestiaire (F1)", "Chaque succès rapporte des points : titres et auras pour ton héros. Le bestiaire décrit les monstres vaincus.", 1],
	# chapitre 9 : le royaume et ses voisins
	["diplomatie", "Ouvre la diplomatie (Y)", "Cinq nations entourent ton royaume. Leur humeur change selon tes présents, tes traités... et tes guerres.", 1],
	["cadeau", "Offre un présent à une nation", "50 pièces d'or, ou ce qu'elle aime, une fois par jour. Ses demandes rapportent de l'or.", 1],
	["traite", "Signe un traité", "Paix dès que la relation est positive, commerce à 20 (caravanes, meilleurs prix), alliance à 60.", 1],
	["metier", "Ouvre une pièce de métier avancé", "Laboratoire d'alchimie (chaudron, table, tonneau), Sanctuaire des runes, Ménagerie ou Bureau d'architecte.", 1],
	["evenement", "Réussis un événement du monde", "Pluie d'étoiles, invasion, tournoi, fête, épidémie : il y en a un tous les 3 ou 4 jours.", 1],
]
## Chapitres : [titre, première étape, étape suivant la dernière].
const CHAPTERS := [["PREMIERS PAS", 0, 8], ["L'ÂGE DU FER", 8, 13], ["LE VILLAGE", 13, 16], ["LES CHAMPS", 16, 20], ["LE COMMERCE", 20, 23], ["L'ÉLEVAGE", 23, 26], ["L'EAU", 26, 29],
	["L'AVENTURE", 29, 33], ["LES VOISINS", 33, 38]]
## Icône de chaque chapitre (assets/ui/icon_*.png).
const CHAPTER_ICONS := {"PREMIERS PAS": "compass", "L'ÂGE DU FER": "sword", "LE VILLAGE": "house", "LES CHAMPS": "food",
	"LE COMMERCE": "coin", "L'ÉLEVAGE": "people", "L'EAU": "gem", "L'AVENTURE": "skull", "LES VOISINS": "shield"}
var _icon: TextureRect
## Astuces affichées une seule fois, la première fois que la situation se présente : [identifiant, texte].
const TIPS := [
	["gemme", "Une gemme ! Sertis-la à l'enclume (I → Artisanat → Forge) sur une arme ou une armure."],
	["rune", "Une rune ! Grave-la sur une arme ou une armure à l'enclume (onglet Forge)."],
	["potion", "Une potion ! Touche Z pour la boire : soin si tu es blessé, sinon un renfort de 90 secondes."],
	["orichalque", "De l'orichalque ! Le métal du renforcement +10 à la forge et des armes légendaires."],
	["piege", "Ce donjon est piégé : quand une dalle rougit, des piques vont en sortir."],
	["levier", "Une stèle et des leviers : tire-les (E) dans l'ordre gravé sur la stèle pour ouvrir le mur fissuré."],
	["guerre", "Tu es en guerre ! Repousse 3 armées pour faire capituler la nation, ou assiège sa capitale (Y, à partir du niveau 6)."],
	["malade", "Des habitants sont malades : soigne-les dans le panneau du royaume (U) avec une soupe ou une potion."],
	["succes", "Premier succès ! F1 : succès, titres, auras et bestiaire."],
]
## Version de la liste des étapes (pour convertir les anciennes sauvegardes).
const VERSION := 2

var player: Player
var step := 0
var progress := 0
var _title: Label
var _task: Label
var _hint: Label
var _bar: ColorRect
var _check_timer := 0.0
var _hide_timer := -1.0
## Astuces déjà montrées.
var tips_seen := {}
var _tips_timer := 1.5


func _ready() -> void:
	add_to_group("guide")
	add_theme_stylebox_override("panel", UiTheme.small_frame(9))
	modulate.a = 0.94
	position = Vector2(10, 118)
	custom_minimum_size = Vector2(250, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	v.add_child(top)
	_icon = MenuKit.icon("compass", 16)
	top.add_child(_icon)
	_title = _label("", 10, Color("c8a870"))
	top.add_child(_title)
	_task = _label("", 13, Color("fff2c8"))
	_task.add_theme_font_override("font", UiTheme.font("title"))
	v.add_child(_task)
	_hint = _label("", 10, Color("c8b89a"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(236, 0)
	v.add_child(_hint)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.5)
	bar_bg.custom_minimum_size = Vector2(236, 4)
	v.add_child(bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color("f2c86a")
	_bar.size = Vector2(0, 4)
	bar_bg.add_child(_bar)
	var vn0 := get_tree().get_first_node_in_group("village_needs")
	if vn0:
		vn0.deposited.connect(func(_p): _advance("reserve"))
	else:
		(func():
			var vn1 := get_tree().get_first_node_in_group("village_needs")
			if vn1:
				vn1.deposited.connect(func(_p): _advance("reserve"))).call_deferred()
	if player:
		player.planted.connect(func(_c): _advance("semer"))
		player.crop_harvested.connect(func(_c): _advance("recolte"))
		player.harvested.connect(_on_harvested)
		player.crafted.connect(_on_crafted)
		player.ate.connect(func(id: String):
			var it := Items.get_item(id)
			if it and it.food_cooked:
				_advance("repas"))
	_connect_trade.call_deferred()
	_connect_livestock.call_deferred()
	_connect_water.call_deferred()
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		_connect_day(dc)
	else:
		_connect_day.call_deferred(null)
	if not SaveGame.guide_state.is_empty():
		import_state(SaveGame.guide_state)
		SaveGame.guide_state = {}
	_refresh()


func _connect_trade() -> void:
	var tr := get_tree().get_first_node_in_group("trade") as Trade
	if tr == null:
		# le commerce arrive un peu après le guide
		get_tree().create_timer(0.5).timeout.connect(_connect_trade)
		return
	if not tr.sold.is_connected(_on_sold):
		tr.sold.connect(_on_sold)
		tr.bought.connect(func(_id, _n, _g): _advance("acheter"))


func _connect_livestock() -> void:
	var ls := get_tree().get_first_node_in_group("livestock") as Livestock
	if ls == null:
		get_tree().create_timer(0.5).timeout.connect(_connect_livestock)
		return
	if not ls.produced.is_connected(_on_produced):
		ls.produced.connect(_on_produced)


func _connect_water() -> void:
	var fi := get_tree().get_first_node_in_group("fishing") as Fishing
	var cv := get_tree().get_first_node_in_group("caves") as UnderwaterCaves
	if fi == null or cv == null:
		get_tree().create_timer(0.5).timeout.connect(_connect_water)
		return
	if not fi.caught.is_connected(_on_caught):
		fi.caught.connect(_on_caught)
		cv.chest_opened.connect(func(_id): _advance("grotte"))


func _on_caught(_id: String) -> void:
	_advance("pecher")


func _on_produced(_id: String) -> void:
	_advance("produits")


func _on_sold(_id: String, n: int, _gold: int) -> void:
	_advance("vendre", n)


func _connect_day(dc: DayCycle) -> void:
	if dc == null:
		dc = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and not dc.day_started.is_connected(_on_day):
		dc.day_started.connect(_on_day)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size + 1)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 3)
	return l


func current_id() -> String:
	return STEPS[step][0] if step < STEPS.size() else ""


func is_done() -> bool:
	return step >= STEPS.size()


func _advance(id: String, amount := 1) -> void:
	if current_id() != id:
		return
	progress += amount
	if progress >= int(STEPS[step][3]):
		_complete()
	_refresh()


func _complete() -> void:
	if player:
		player.feat.emit("Objectif : %s ✔" % STEPS[step][1], Color("f2c86a"))
	step += 1
	progress = 0
	if not is_done() and player:
		for c in CHAPTERS:
			if step == int(c[1]):
				player.notify.emit("Chapitre terminé ! Nouveau chapitre : %s." % String(c[0]).capitalize())
	if is_done():
		_hide_timer = 8.0
		if player:
			player.notify.emit("Guide terminé ! Le royaume est à toi : agrandis ton village, recrute des habitants, explore le monde.")
	else:
		_check_state()


func _on_harvested(kind: String) -> void:
	_advance(kind)


func _on_crafted(item_id: String) -> void:
	if item_id.begins_with("hache_") or item_id.begins_with("pioche_"):
		_advance("outil")
	elif item_id == "bloc_planches":
		_advance("planches")
	elif item_id == "iron_ingot":
		_advance("lingot")
	if item_id == "pioche_fer":
		_advance("pioche_fer")


func _on_day(_d: int) -> void:
	_advance("nuit")


## Objectifs vérifiés d'après l'état du jeu (outil déjà dans le sac, abri construit, torche posée).
func _check_state() -> void:
	if player == null or is_done():
		return
	match current_id():
		"outil":
			for id in ["hache_bois", "pioche_bois", "hache_pierre", "pioche_pierre"]:
				var it := Items.get_item(id)
				if it and player.inventory.count(it) > 0:
					_advance("outil")
					return
		"abri":
			var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
			if k:
				for r in k.rooms:
					if r.enclosed and r.doors > 0 and r.counts.has("lit"):
						_advance("abri")
						return
		"four", "enclume":
			var grid2 := get_tree().get_first_node_in_group("build_grid") as BuildGrid
			if grid2:
				for key in grid2.furniture:
					if (grid2.furniture[key].item as ItemData).id == current_id():
						_advance(current_id())
						return
		"lits", "bonheur":
			var vn := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
			if vn:
				var m := vn.members().size()
				if current_id() == "lits" and m > 0 and vn.total_beds() >= m:
					_advance("lits")
				elif current_id() == "bonheur" and m > 0 and vn.average_happiness() >= 70.0:
					_advance("bonheur")
		"marche":
			var km := get_tree().get_first_node_in_group("kingdom") as Kingdom
			if km:
				for r in km.typed_rooms():
					if (r.type as RoomTypeData).id == "marche":
						_advance("marche")
						return
		"mangeoire":
			var grid3 := get_tree().get_first_node_in_group("build_grid") as BuildGrid
			if grid3:
				for key in grid3.furniture:
					if (grid3.furniture[key].item as ItemData).id == "mangeoire":
						_advance("mangeoire")
						return
		"apprivoiser":
			var ls := get_tree().get_first_node_in_group("livestock") as Livestock
			if ls and not ls.domestic().is_empty():
				_advance("apprivoiser")
		"canne":
			var rod := Items.get_item("canne_peche")
			if rod and player.inventory.count(rod) > 0:
				_advance("canne")
		"houe":
			var hoe := Items.get_item("houe")
			if hoe and player.inventory.count(hoe) > 0:
				_advance("houe")
		"fermier":
			var fm := get_tree().get_first_node_in_group("farming") as Farming
			if fm and not fm.farmers().is_empty():
				_advance("fermier")
		"pioche_fer":
			var pf := Items.get_item("pioche_fer")
			if pf and player.inventory.count(pf) > 0:
				_advance("pioche_fer")
		"donjon":
			var w := get_tree().get_first_node_in_group("world") as WorldGenerator
			if w and w.zones.any(func(z): return z.get("cleared", false)):
				_advance("donjon")
		"forge":
			if _best_item(func(it): return it.upgrade) >= 1:
				_advance("forge")
		"potion":
			if player.potions_drunk > 0:
				_advance("potion")
		"succes", "diplomatie":
			# les panneaux mettent le jeu en pause : ils laissent une marque sur le héros quand on les ouvre
			if player.has_meta("seen_achievements" if current_id() == "succes" else "seen_diplomacy"):
				_advance(current_id())
		"cadeau", "traite":
			var dip := get_tree().get_first_node_in_group("diplomacy") as Diplomacy
			if dip:
				for id in Diplomacy.NATIONS:
					var s: Dictionary = dip.states[id]
					if (current_id() == "cadeau" and int(s.gift_day) >= 0) or (current_id() == "traite" and not (s.treaties as Array).is_empty()):
						_advance(current_id())
						return
		"metier":
			var km2 := get_tree().get_first_node_in_group("kingdom") as Kingdom
			if km2 and km2.typed_rooms().any(func(r): return ["laboratoire", "sanctuaire_runes", "menagerie", "bureau_architecte"].has((r.type as RoomTypeData).id)):
				_advance("metier")
		"evenement":
			var ach := get_tree().get_first_node_in_group("achievements") as Achievements
			if ach and ach.counters.keys().any(func(k): return str(k).begins_with("event_")):
				_advance("evenement")
		"torche":
			var grid := get_tree().get_first_node_in_group("build_grid") as BuildGrid
			if grid:
				for key in grid.furniture:
					if (grid.furniture[key].item as ItemData).furniture_light:
						_advance("torche")
						return


## Le meilleur d'une valeur parmi les objets portés et ceux du sac.
func _best_item(f: Callable) -> int:
	var best := 0
	var all: Array = player.equipment.slots.values()
	for e in player.inventory.entries:
		all.append(e.item)
	for it in all:
		if it:
			best = maxi(best, int(f.call(it)))
	return best


func _has_prefix(prefix: String) -> bool:
	for e in player.inventory.entries:
		if e.item and (e.item as ItemData).id.begins_with(prefix):
			return true
	return false


## Les astuces de la première fois.
func _check_tips() -> void:
	if player == null:
		return
	var tree := get_tree()
	for t in TIPS:
		var id: String = t[0]
		if tips_seen.has(id):
			continue
		var show_it := false
		match id:
			"gemme", "rune", "potion":
				show_it = _has_prefix(id + ("_" if id != "gemme" else ""))
			"orichalque":
				show_it = player.inventory.count(Items.get_item("orichalque")) > 0
			"piege", "levier":
				var dm := tree.get_first_node_in_group("dungeons") as DungeonManager
				show_it = dm != null and dm.active and (not dm.traps.is_empty() if id == "piege" else not dm.lever_order.is_empty())
			"guerre":
				var dip := tree.get_first_node_in_group("diplomacy") as Diplomacy
				show_it = dip != null and not dip.wars().is_empty()
			"malade":
				var wev := tree.get_first_node_in_group("world_events") as WorldEvents
				show_it = wev != null and not wev.sick().is_empty()
			"succes":
				var ach := tree.get_first_node_in_group("achievements") as Achievements
				show_it = ach != null and not ach.done.is_empty()
		if show_it:
			tips_seen[id] = true
			player.notify.emit("Astuce : " + t[1])
			Sound.ui("ui_open")
			return


func _process(delta: float) -> void:
	_tips_timer -= delta
	if _tips_timer <= 0.0:
		_tips_timer = 1.0
		_check_tips()
	if _hide_timer >= 0.0:
		_hide_timer -= delta
		if _hide_timer < 0.0:
			hide()
		return
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		_check_state()


func _refresh() -> void:
	if is_done():
		_title.text = "GUIDE · terminé"
		_task.text = "Bravo !"
		_hint.text = "Tu sais survivre. À toi de bâtir ton royaume."
		_bar.size.x = 236.0
		visible = _hide_timer >= 0.0
		return
	show()
	var s: Array = STEPS[step]
	var ch: Array = CHAPTERS[0]
	for c in CHAPTERS:
		if step >= int(c[1]) and step < int(c[2]):
			ch = c
	var first := int(ch[1])
	var total := int(ch[2]) - first
	_title.text = "%s · %d / %d" % [ch[0], step - first + 1, total]
	_icon.texture = UiTheme.tex("icon_" + str(CHAPTER_ICONS.get(ch[0], "compass")))
	var n := int(s[3])
	_task.text = s[1] + ("  (%d / %d)" % [progress, n] if n > 1 else "")
	_hint.text = s[2]
	_bar.size.x = 236.0 * (float(step - first) + float(progress) / float(n)) / float(total)


func export_state() -> Dictionary:
	return {"step": step, "progress": progress, "v": VERSION, "tips": tips_seen.keys()}


func import_state(d: Dictionary) -> void:
	step = int(d.get("step", 0))
	progress = int(d.get("progress", 0))
	tips_seen = {}
	for t in d.get("tips", []):
		tips_seen[str(t)] = true
	# version 1 : l'étape « repas » n'existait pas (elle est avant « nuit », 7e étape)
	if int(d.get("v", 1)) < 2 and step >= 6 and step < 99:
		step += 1
	_hide_timer = -1.0
	_refresh()
