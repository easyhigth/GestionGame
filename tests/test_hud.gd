extends SceneTree
## Interface en jeu : l'écran de jeu reste dégagé (éléments compacts) et, dès qu'un menu s'ouvre (carte,
## journal, inventaire, royaume, talents), les barres du bas et le reste de l'interface s'effacent.
## Une capture par écran (hud_XX_nom.png).
var f := 0
var p; var hud
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/hud_"
var step := -1
var step_at := 0.0

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

## Éléments de l'interface de jeu qui ne doivent plus se voir sous un menu.
func chrome_visible() -> Array:
	var out_l := []
	for n in ["_dock", "_skill_box", "guide", "_quest_box", "info", "_clock", "keys_help"] + ([] if get_first_node_in_group("inventory_ui").is_visible_in_tree() else ["_messages"]):
		var c = hud.get(n) if n in hud else null
		if c is CanvasItem and c.is_visible_in_tree():
			out_l.append(n)
	return out_l

const STEPS := ["jeu", "carte", "journal", "inventaire", "royaume", "talents"]

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 11.0
		step = 0
		step_at = game_ms + 5000.0
	if step < 0:
		return false
	if step >= STEPS.size():
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	if game_ms < step_at:
		return false
	var id: String = STEPS[step]
	if not has_meta("open_%d" % step):
		set_meta("open_%d" % step, Engine.get_process_frames())
		match id:
			"carte":
				hud.map_ui.open()
			"journal":
				hud.journal.open()
			"inventaire":
				p.open_inventory.emit(p)
			"royaume":
				hud.kingdom_panel.open()
			"talents":
				hud.talent_ui.open()
		return false
	if Engine.get_process_frames() - int(get_meta("open_%d" % step)) < 20:
		return false
	shot("%02d_%s.png" % [step + 1, id])
	if id == "jeu":
		var vp: Vector2 = root.get_viewport().get_visible_rect().size
		var dock = hud.get("_dock")
		var h: float = dock.get_global_rect().size.y * root.get_final_transform().get_scale().y if dock else 0.0
		print("   barre du bas : %.0f px de haut sur %.0f" % [h, vp.y])
	else:
		var vis := chrome_visible()
		check("%s : l'interface de jeu est masquée %s" % [id, str(vis)], vis.is_empty())
		match id:
			"carte":
				hud.map_ui.close()
			"journal":
				hud.journal.close()
			"inventaire":
				var inv = get_first_node_in_group("inventory_ui")
				if inv: inv.close()
			"royaume":
				hud.kingdom_panel.close()
			"talents":
				hud.talent_ui.close_ui()
	step += 1
	step_at = game_ms
	return false
