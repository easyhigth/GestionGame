extends SceneTree
## Accessibilité, langues et difficulté : filtre daltonien, mouvement réduit, anglais, agressivité des monstres.
var ok := true

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

var f := 0

func _process(_d) -> bool:
	f += 1
	if f < 3:
		return false
	run()
	return true

func run() -> void:
	var sg = root.get_node("SaveGame")
	var ac = root.get_node("Access")
	var i18n = root.get_node("I18n")
	# filtre daltonien
	check("filtre éteint au départ", not ac._rect.visible)
	ac.set_colorblind(2)
	check("filtre allumé (deutéranopie)", ac._rect.visible)
	ac.set_colorblind(0)
	check("filtre éteint", not ac._rect.visible)
	# mouvement réduit
	sg.options.reduce_motion = false
	check("secousses normales", is_equal_approx(ac.shake_scale(), 1.0))
	sg.options.reduce_motion = true
	check("secousses réduites", ac.shake_scale() < 0.3)
	root.get_node("TimeFX").hit_stop(0.2)
	check("pas d'arrêt sur image en mouvement réduit", root.get_node("TimeFX")._stop_until == 0)
	root.get_node("TimeFX").slow_motion(0.2, 1.0)
	check("ralenti adouci", root.get_node("TimeFX")._slow_scale > 0.5)
	root.get_node("TimeFX").cancel()
	sg.options.reduce_motion = false
	# langues
	check("français par défaut", i18n.t("Options") == "Options" and i18n.t("Continuer") == "Continuer")
	i18n.set_language("en")
	check("anglais : Continuer -> Continue", i18n.t("Continuer") == "Continue")
	check("anglais : Quitter le jeu", i18n.t("Quitter le jeu") == "Quit game")
	check("texte inconnu inchangé", i18n.t("Texte inconnu xyz") == "Texte inconnu xyz")
	var b := Button.new()
	b.text = "Reprendre"
	root.add_child(b)
	check("un bouton se traduit tout seul", b.get_theme_default_font() != null and b.atr("Reprendre") == "Resume")
	i18n.set_language("fr")
	check("retour au français", i18n.t("Continuer") == "Continuer")
	i18n.set_language("zz")
	check("langue inconnue -> français", i18n.language == "fr")
	# difficulté
	var prev = sg.options.difficulty
	sg.options.difficulty = 0
	var easy_cd = sg.enemy_cooldown_mult()
	var easy_sp = sg.enemy_speed_mult()
	sg.options.difficulty = 2
	check("difficile : attaques plus rapprochées", sg.enemy_cooldown_mult() < easy_cd)
	check("difficile : monstres plus rapides", sg.enemy_speed_mult() > easy_sp)
	sg.options.difficulty = 1
	check("normal : multiplicateurs à 1", is_equal_approx(sg.enemy_cooldown_mult(), 1.0) and is_equal_approx(sg.enemy_speed_mult(), 1.0))
	sg.options.difficulty = prev
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
