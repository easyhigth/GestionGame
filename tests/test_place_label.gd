extends SceneTree
## Les étiquettes flottantes des lieux s'effacent au loin : lisibles de près, en fondu à mi-distance, cachées au-delà.
var f := 0
var ok := true
var cam: Camera3D
var lab: PlaceLabel

func _initialize():
	var w := Node3D.new()
	root.add_child(w)
	cam = Camera3D.new()
	w.add_child(cam)
	cam.make_current()
	lab = PlaceLabel.new()
	lab.text = "Obélisque"
	w.add_child(lab)

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _process(_d):
	f += 1
	match f:
		# distances tirées de la taille du texte à l'écran (une petite étiquette s'efface plus tôt que fade_start / fade_end)
		1: lab.global_position = Vector3(0, 0, -lab.fade_range().x * 0.5)
		3:
			check("de près : visible et opaque", lab.visible and is_equal_approx(lab.modulate.a, 1.0))
			lab.global_position = Vector3(0, 0, -(lab.fade_range().x + lab.fade_range().y) * 0.5)
		5:
			check("à mi-chemin : en fondu (alpha %.2f)" % lab.modulate.a, lab.visible and lab.modulate.a > 0.2 and lab.modulate.a < 0.8 and is_equal_approx(lab.outline_modulate.a, lab.modulate.a))
			lab.global_position = Vector3(0, 0, -(lab.fade_range().y + 30.0))
		7:
			check("au loin : cachée", not lab.visible)
			lab.global_position = Vector3(0, 0, -lab.fade_range().x * 0.5)
		9:
			check("on se rapproche : elle revient", lab.visible and is_equal_approx(lab.modulate.a, 1.0))
			# tout en haut de l'écran : elle descend pour rester sous la bande du HUD
			lab.global_position = Vector3(0, 3.2, -5.0)
		11:
			var vh := root.get_visible_rect().size.y
			var y := cam.unproject_position(lab.global_position + Vector3.UP * lab.offset.y * lab.pixel_size).y
			check("en haut de l'écran : descendue sous le HUD (y %.0f, alpha %.2f)" % [y, lab.modulate.a], lab.visible and y > vh * PlaceLabel.TOP_MARGIN and lab.offset.y < 0.0)
			lab.global_position = Vector3(0, 0, -5.0)
		13:
			check("au milieu de l'écran : pas déplacée", is_zero_approx(lab.offset.y) and is_equal_approx(lab.modulate.a, 1.0))
			print("RÉSULTAT : " + ("tout est bon" if ok else "des échecs"))
			quit(0 if ok else 1)
	return false
