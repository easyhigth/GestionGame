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
	["nuit", "Survis à ta première nuit", "Quand la nuit tombe, dors dans ton lit (E) ou tiens jusqu'au matin.", 1],
	# chapitre 2 : l'âge du fer
	["filon_fer", "Mine 2 filons de fer", "Des rochers piquetés d'orange, dans la roche des collines. Il faut une pioche.", 2],
	["four", "Fabrique et pose un four", "Près d'un établi : 6 cailloux et 2 blocs de terre (Artisanat → Mobilier). Pose-le avec V.", 1],
	["lingot", "Fonds 2 lingots de fer", "Près du four : 2 minerais de fer et 1 bois donnent 1 lingot (Artisanat → Matériaux).", 2],
	["enclume", "Fabrique et pose une enclume", "4 lingots de fer, près d'un établi. Toutes les pièces en fer se forgent à côté d'elle.", 1],
	["pioche_fer", "Forge une pioche en fer", "À l'enclume : 2 lingots et 2 bois (Artisanat → Outils). Elle mine l'or et le marbre.", 1],
]
## Chapitres : [titre, première étape, étape suivant la dernière].
const CHAPTERS := [["PREMIERS PAS", 0, 7], ["L'ÂGE DU FER", 7, 12]]

var player: Player
var step := 0
var progress := 0
var _title: Label
var _task: Label
var _hint: Label
var _bar: ColorRect
var _check_timer := 0.0
var _hide_timer := -1.0


func _ready() -> void:
	add_to_group("guide")
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.06, 0.05, 0.78)
	st.border_color = Color("8a6a3a")
	st.set_border_width_all(1)
	st.border_width_left = 3
	st.set_corner_radius_all(4)
	st.set_content_margin_all(7)
	add_theme_stylebox_override("panel", st)
	position = Vector2(10, 118)
	custom_minimum_size = Vector2(250, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	_title = _label("", 10, Color("c8a870"))
	v.add_child(_title)
	_task = _label("", 13, Color("fff2c8"))
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
	if player:
		player.harvested.connect(_on_harvested)
		player.crafted.connect(_on_crafted)
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		_connect_day(dc)
	else:
		_connect_day.call_deferred(null)
	if not SaveGame.guide_state.is_empty():
		import_state(SaveGame.guide_state)
		SaveGame.guide_state = {}
	_refresh()


func _connect_day(dc: DayCycle) -> void:
	if dc == null:
		dc = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and not dc.day_started.is_connected(_on_day):
		dc.day_started.connect(_on_day)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
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
		"pioche_fer":
			var pf := Items.get_item("pioche_fer")
			if pf and player.inventory.count(pf) > 0:
				_advance("pioche_fer")
		"torche":
			var grid := get_tree().get_first_node_in_group("build_grid") as BuildGrid
			if grid:
				for key in grid.furniture:
					if (grid.furniture[key].item as ItemData).furniture_light:
						_advance("torche")
						return


func _process(delta: float) -> void:
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
	var n := int(s[3])
	_task.text = s[1] + ("  (%d / %d)" % [progress, n] if n > 1 else "")
	_hint.text = s[2]
	_bar.size.x = 236.0 * (float(step - first) + float(progress) / float(n)) / float(total)


func export_state() -> Dictionary:
	return {"step": step, "progress": progress}


func import_state(d: Dictionary) -> void:
	step = int(d.get("step", 0))
	progress = int(d.get("progress", 0))
	_hide_timer = -1.0
	_refresh()
