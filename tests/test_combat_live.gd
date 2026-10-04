extends SceneTree
## Combat vivant : zones rouges au sol avant les grands coups (charge, balayage), monstres agiles qui
## esquivent, monstres armés qui lèvent leur garde (brisée par une attaque chargée), boss en trois phases
## (enragé à la moitié, fureur au quart, avec ses lames en croix). Captures cl_XX_nom.png.
var f := 0
var p; var w
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cl_"
var phase := ""
var phase_at := 0.0
var e1; var e2; var boss
var tries := 0

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

func go(ph: String) -> void:
	phase = ph
	phase_at = game_ms

func since() -> float:
	return game_ms - phase_at

func ground(at: Vector3) -> Vector3:
	at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.5)
	return at

func spawn(id: String, off: Vector3, lv := 20):
	var e = load("res://scenes/enemies/enemy.tscn").instantiate()
	e.data = load("res://data/enemies/%s.tres" % id)
	e.level = lv
	w.add_child(e)
	e.global_position = ground(p.global_position + off)
	return e

## Nombre de zones rouges posées au sol en ce moment.
func telegraphs() -> int:
	var n := 0
	for c in current_scene.get_children():
		if c is Node3D and c.get_child_count() == 2 and c.get_child(0) is MeshInstance3D \
				and (c.get_child(0) as MeshInstance3D).material_override is StandardMaterial3D \
				and ((c.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.r > 0.8:
			n += 1
	return n

func look_at_point(target: Vector3) -> void:
	var d: Vector3 = (target - p.camera.global_position).normalized()
	p.cam_yaw = atan2(-d.x, -d.z)
	p.cam_pitch = p.clamp_pitch(asin(-d.y))

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 11.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		p.set_camera_mode(0, false)
		p.cam_pitch = p.clamp_pitch(0.45)
		# un sanglier charge : bande rouge devant lui
		e1 = spawn("sanglier", Vector3(0, 0, -4.5))
		print("== télégraphe de charge")
		go("charge")
	if phase == "":
		return false
	if since() > 15000.0:
		check("l'étape « %s » aboutit" % phase, false)
		print("RÉSULTAT : échec")
		return true
	match phase:
		"charge":
			look_at_point(e1.global_position)
			if since() > 300.0 and not has_meta("charged"):
				set_meta("charged", true)
				e1._target = p
				e1.facing = (p.global_position - e1.global_position).normalized()
				e1.perform("charge_ram", 0.4)
				e1._telegraph_attack("charge_ram", 1.0)
			if has_meta("charged") and since() > 650.0:
				check("zone rouge avant la charge (%d)" % telegraphs(), telegraphs() >= 1)
				shot("01_charge.png")
				e1.queue_free()
				e2 = spawn("squelette", Vector3(0, 0, -2.0))
				print("== balayage d'un squelette")
				go("sweep")
		"sweep":
			look_at_point(e2.global_position)
			if since() > 300.0 and not has_meta("swept"):
				set_meta("swept", true)
				e2.set_physics_process(false)
				e2._telegraph_attack("enemy_sweep", 1.0)
			if has_meta("swept") and since() > 700.0:
				check("disque rouge autour du balayage (%d)" % telegraphs(), telegraphs() >= 1)
				shot("02_balayage.png")
				print("== garde du squelette")
				e2.set_physics_process(true)
				go("guard")
		"guard":
			e2._react_cd = 0.0
			e2._attack_cooldown = 5.0
			if not e2.blocking and tries < 60:
				tries += 1
				e2.on_threatened(p, false)
			if e2.blocking and not has_meta("guarded"):
				set_meta("guarded", true)
				set_meta("guard_at", since())
			if has_meta("guarded") and since() - float(get_meta("guard_at")) > 200.0:
				check("le squelette lève sa garde (%s, %s)" % [e2.temperament(), str(e2.blocking)], e2.blocking)
				shot("03_garde.png")
				e2.break_guard()
				check("attaque chargée : garde brisée", not e2.blocking and e2._stagger_left > 0.0)
				e2.queue_free()
				e1 = spawn("loup", Vector3(0, 0, -1.8))
				tries = 0
				print("== esquive du loup")
				go("dodge")
			elif tries >= 60:
				check("le squelette lève sa garde", false)
				go("dodge")
		"dodge":
			if e1 == null or not is_instance_valid(e1):
				e1 = spawn("loup", Vector3(0, 0, -1.8))
			e1._react_cd = 0.0
			e1._attack_cooldown = 5.0
			if not has_meta("dodged") and tries < 80:
				tries += 1
				var before: Vector3 = e1.global_position
				if e1.on_threatened(p, false):
					set_meta("dodged", true)
					set_meta("dodge_from", before)
					set_meta("dodge_at", since())
			if has_meta("dodged") and since() - float(get_meta("dodge_at")) > 250.0:
				var moved: float = e1.global_position.distance_to(get_meta("dodge_from"))
				check("le loup esquive d'un bond (%.1f m)" % moved, moved > 0.6)
				shot("04_esquive.png")
				e1.queue_free()
				# un boss
				boss = load("res://scenes/enemies/boss.tscn").instantiate()
				boss.data = load("res://data/enemies/boss_ogre_roi.tres")
				boss.level = 10
				boss.powers = PackedStringArray(["onde"])
				w.add_child(boss)
				boss.global_position = ground(p.global_position + Vector3(0, 0, -5.0))
				boss.home = boss.global_position
				boss.wake()
				print("== boss : phases")
				go("boss")
			elif tries >= 80 and not has_meta("dodged"):
				check("le loup esquive", false)
				go("boss_skip")
		"boss":
			look_at_point(boss.global_position + Vector3(0, 1.5, 0))
			if since() > 600.0 and not has_meta("p2"):
				set_meta("p2", true)
				boss.health.take_damage(int(boss.health.max_health * 0.55), p)
			if has_meta("p2") and since() > 1100.0 and not has_meta("p2shot"):
				set_meta("p2shot", true)
				check("moitié de sa vie : phase 2 (enragé)", boss.phase == 2)
				shot("05_boss_enrage.png")
				boss.health.take_damage(int(boss.health.max_health * 0.25), p)
			if has_meta("p2shot") and since() > 1900.0 and not has_meta("p3shot"):
				set_meta("p3shot", true)
				check("un quart de sa vie : phase 3 (fureur)", boss.phase == 3)
				shot("06_boss_fureur.png")
				boss._cross_blades()
			if has_meta("p3shot") and since() > 2600.0:
				check("lames en croix : quatre bandes rouges (%d)" % telegraphs(), telegraphs() >= 4)
				shot("07_lames_croix.png")
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
		"boss_skip":
			print("RÉSULTAT : échec")
			return true
	return false
