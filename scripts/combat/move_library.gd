class_name MoveLibrary
extends RefCounted
## Toutes les animations de combat (« coups »), décrites par des poses clés.
##
## Une pose donne la rotation (en degrés, x / y / z) de chaque os par rapport au repos :
##   ArmL = bras qui tient l'arme (côté +X), ArmR = bras du bouclier, HandL / HandR = mains,
##   Torso, Head, LegL, LegR. « root » décale tout le corps (mètres), « spin » le fait tourner (degrés).
## Repères : bras X négatif = lever vers l'avant ; ArmL Z positif = écarter vers l'extérieur ;
##   HandL X = 180 : la lame prolonge le bras ; Torso Y positif = tourner vers le côté de l'arme.
##
## Un coup :
##   duration   : durée (secondes, à vitesse 1)
##   keys       : [[temps, {os: Vector3}, root: Vector3, spin: float], ...] (le repos est ajouté à la fin)
##   hits       : moments où le coup touche : {t, arc (degrés), reach (× portée de l'arme), dmg (× dégâts),
##                kb (× recul), poise (× déséquilibre), around: vrai = tout autour}
##   trail      : [début, fin] de la traînée de l'arme
##   lunge      : [début, fin, distance] : le personnage avance pendant le coup
##   combo      : à partir de quand on peut enchaîner le coup suivant
##   cancel     : à partir de quand on peut annuler par une roulade

const GUARD := {
	"ArmL": Vector3(-28, 0, 12), "HandL": Vector3(140, 0, 0),
	"ArmR": Vector3(-18, 0, -8), "Torso": Vector3(4, -8, 0),
}

static var _moves := {}


static func get_move(name: String) -> Dictionary:
	if _moves.is_empty():
		_build()
	return _moves.get(name, {})


static func has_move(name: String) -> bool:
	return not get_move(name).is_empty()


## Suite de combo selon le style d'arme.
## Pose de sort d'une classe (identifiant de la classe : mage, guerrier, clerc...).
static func cast_pose(class_id: String) -> String:
	match class_id:
		"mage", "cryomancien", "necromancien":
			return "pose_arcane"
		"guerrier", "barbare", "chevalier":
			return "pose_martial"
		"clerc", "paladin", "barde":
			return "pose_divine"
		"rodeur":
			return "pose_bow"
		"assassin":
			return "pose_shadow"
		"druide":
			return "pose_nature"
		"moine":
			return "pose_monk"
	return "pose_arcane"


static func combo_for(style: int) -> Array[String]:
	match style:
		ItemData.WeaponStyle.SPEAR:
			return ["spear_1", "spear_2", "spear_3"]
		ItemData.WeaponStyle.HEAVY:
			return ["heavy_1", "heavy_2", "heavy_3"]
		ItemData.WeaponStyle.STAFF:
			return ["cast_1", "cast_2", "cast_3"]
		ItemData.WeaponStyle.UNARMED:
			return ["punch_1", "punch_2", "punch_3"]
	return ["slash_1", "slash_2", "slash_3"]


static func _k(t: float, pose: Dictionary, root := Vector3.ZERO, spin := 0.0) -> Array:
	return [t, pose, root, spin]


static func _build() -> void:
	var H := Vector3(175, 0, 0)  # lame dans le prolongement du bras

	# ---------------------------------------------------------------- épée (1 main)
	_moves["slash_1"] = {  # coup horizontal : de l'extérieur vers l'intérieur
		"duration": 0.46, "combo": 0.24, "cancel": 0.2,
		"keys": [
			_k(0.0, GUARD),
			_k(0.09, {"ArmL": Vector3(-78, 0, 62), "HandL": H, "Torso": Vector3(0, 58, 0), "Head": Vector3(0, -30, 0), "ArmR": Vector3(-10, 0, -20)}, Vector3(0, 0, -0.05)),
			_k(0.2, {"ArmL": Vector3(-84, 0, -18), "HandL": H, "Torso": Vector3(8, -52, 0), "Head": Vector3(0, 30, 0), "ArmR": Vector3(20, 0, -30)}, Vector3(0, 0, 0.3)),
			_k(0.3, {"ArmL": Vector3(-60, 0, -30), "HandL": Vector3(160, 0, 0), "Torso": Vector3(6, -40, 0), "Head": Vector3(0, 20, 0), "ArmR": Vector3(15, 0, -25)}, Vector3(0, 0, 0.3)),
		],
		"hits": [{"t": 0.16, "arc": 150}], "trail": [0.1, 0.24], "lunge": [0.08, 0.2, 0.45],
	}
	_moves["slash_2"] = {  # revers : de l'intérieur vers l'extérieur
		"duration": 0.44, "combo": 0.22, "cancel": 0.18,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-60, 0, -30), "HandL": Vector3(160, 0, 0), "Torso": Vector3(6, -40, 0), "Head": Vector3(0, 20, 0), "ArmR": Vector3(15, 0, -25)}, Vector3(0, 0, 0.1)),
			_k(0.08, {"ArmL": Vector3(-92, 0, -40), "HandL": H, "Torso": Vector3(0, -62, 0), "Head": Vector3(0, 35, 0), "ArmR": Vector3(20, 0, -35)}),
			_k(0.19, {"ArmL": Vector3(-80, 0, 70), "HandL": H, "Torso": Vector3(6, 50, 0), "Head": Vector3(0, -30, 0), "ArmR": Vector3(-20, 0, -10)}, Vector3(0, 0, 0.3)),
			_k(0.3, {"ArmL": Vector3(-50, 0, 60), "HandL": Vector3(160, 0, 0), "Torso": Vector3(4, 40, 0), "ArmR": Vector3(-10, 0, -10)}, Vector3(0, 0, 0.3)),
		],
		"hits": [{"t": 0.15, "arc": 150}], "trail": [0.08, 0.22], "lunge": [0.06, 0.18, 0.45],
	}
	_moves["slash_3"] = {  # coup final : saut et frappe verticale
		"duration": 0.66, "combo": 0.5, "cancel": 0.38,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-50, 0, 60), "HandL": Vector3(160, 0, 0), "Torso": Vector3(4, 40, 0)}, Vector3(0, 0, 0.1)),
			_k(0.14, {"ArmL": Vector3(-200, 0, 8), "HandL": H, "Torso": Vector3(-16, 10, 0), "Head": Vector3(-10, 0, 0), "ArmR": Vector3(30, 0, -30), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}, Vector3(0, 0.28, 0.1)),
			_k(0.26, {"ArmL": Vector3(-55, 0, 0), "HandL": H, "Torso": Vector3(28, 0, 0), "Head": Vector3(-15, 0, 0), "ArmR": Vector3(25, 0, -45), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(30, 0, 0)}, Vector3(0, -0.12, 0.55)),
			_k(0.42, {"ArmL": Vector3(-50, 0, 0), "HandL": H, "Torso": Vector3(24, 0, 0), "ArmR": Vector3(20, 0, -40), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(28, 0, 0)}, Vector3(0, -0.12, 0.55)),
		],
		"hits": [{"t": 0.25, "arc": 120, "reach": 1.1, "dmg": 1.8, "kb": 2.2, "poise": 2.0, "shock": true}],
		"trail": [0.13, 0.27], "lunge": [0.08, 0.26, 0.9],
	}
	_moves["charge"] = {  # pose tenue pendant la charge
		"duration": 0.25, "hold": true,
		"keys": [
			_k(0.0, GUARD),
			_k(0.25, {"ArmL": Vector3(-30, 0, 85), "HandL": H, "Torso": Vector3(10, 80, 0), "Head": Vector3(0, -60, 0), "ArmR": Vector3(-40, 0, -30), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(25, 0, 0)}, Vector3(0, -0.1, 0)),
		],
	}
	_moves["spin"] = {  # attaque tournoyante (après la charge)
		"duration": 0.62, "cancel": 0.5,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-30, 0, 85), "HandL": H, "Torso": Vector3(10, 80, 0), "ArmR": Vector3(-40, 0, -30)}, Vector3(0, -0.1, 0)),
			_k(0.08, {"ArmL": Vector3(0, 0, 92), "HandL": H, "Torso": Vector3(0, 30, 0), "ArmR": Vector3(0, 0, -80)}, Vector3(0, 0.05, 0), 0.0),
			_k(0.42, {"ArmL": Vector3(0, 0, 92), "HandL": H, "Torso": Vector3(0, 30, 0), "ArmR": Vector3(0, 0, -80)}, Vector3(0, 0.05, 0), -720.0),
			_k(0.52, {"ArmL": Vector3(-40, 0, 40), "HandL": Vector3(160, 0, 0), "Torso": Vector3(0, 10, 0)}, Vector3.ZERO, -720.0),
		],
		"hits": [{"t": 0.16, "around": true, "reach": 1.15, "dmg": 1.3, "kb": 2.0, "poise": 1.5},
			{"t": 0.32, "around": true, "reach": 1.15, "dmg": 1.3, "kb": 2.5, "poise": 1.5}],
		"trail": [0.08, 0.44],
	}
	_moves["dash_thrust"] = {  # coup d'estoc en sortie de roulade
		"duration": 0.42, "combo": 0.3, "cancel": 0.26,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-40, 0, 20), "HandL": H, "Torso": Vector3(10, 45, 0)}, Vector3(0, -0.08, -0.1)),
			_k(0.12, {"ArmL": Vector3(-92, 0, -4), "HandL": H, "Torso": Vector3(18, -10, 0), "Head": Vector3(-10, 0, 0), "ArmR": Vector3(35, 0, -20), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(35, 0, 0)}, Vector3(0, -0.14, 0.6)),
			_k(0.26, {"ArmL": Vector3(-88, 0, -4), "HandL": H, "Torso": Vector3(15, -8, 0), "ArmR": Vector3(30, 0, -20), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(30, 0, 0)}, Vector3(0, -0.12, 0.6)),
		],
		"hits": [{"t": 0.12, "arc": 60, "reach": 1.35, "dmg": 1.4, "kb": 1.5}], "trail": [0.04, 0.16], "lunge": [0.0, 0.14, 1.6],
	}
	_moves["counter"] = {  # contre après une parade : pivot et estoc dévastateur
		"duration": 0.6, "cancel": 0.45,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-20, 0, 40), "HandL": H, "Torso": Vector3(0, 70, 0), "ArmR": Vector3(-60, 0, 20)}, Vector3(0, -0.05, -0.15)),
			_k(0.12, {"ArmL": Vector3(-150, 0, 30), "HandL": H, "Torso": Vector3(-10, 90, 0), "ArmR": Vector3(-30, 0, -30)}, Vector3(0, 0.1, 0), -180.0),
			_k(0.24, {"ArmL": Vector3(-92, 0, -5), "HandL": H, "Torso": Vector3(20, -10, 0), "ArmR": Vector3(40, 0, -30), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(35, 0, 0)}, Vector3(0, -0.15, 0.7), -360.0),
			_k(0.44, {"ArmL": Vector3(-88, 0, -5), "HandL": H, "Torso": Vector3(18, -8, 0), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(30, 0, 0)}, Vector3(0, -0.12, 0.7), -360.0),
		],
		"hits": [{"t": 0.24, "arc": 90, "reach": 1.3, "dmg": 2.6, "kb": 3.0, "poise": 5.0, "shock": true}],
		"trail": [0.06, 0.28], "lunge": [0.12, 0.26, 1.0],
	}
	_moves["flurry"] = {  # riposte après une esquive parfaite : rafale de coups
		"duration": 0.9, "cancel": 0.8,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-78, 0, 62), "HandL": H, "Torso": Vector3(0, 58, 0)}),
			_k(0.1, {"ArmL": Vector3(-84, 0, -30), "HandL": H, "Torso": Vector3(0, -55, 0)}, Vector3(0, 0, 0.3)),
			_k(0.2, {"ArmL": Vector3(-80, 0, 70), "HandL": H, "Torso": Vector3(0, 55, 0)}, Vector3(0, 0, 0.3)),
			_k(0.3, {"ArmL": Vector3(-84, 0, -30), "HandL": H, "Torso": Vector3(0, -55, 0)}, Vector3(0, 0, 0.3)),
			_k(0.4, {"ArmL": Vector3(-80, 0, 70), "HandL": H, "Torso": Vector3(0, 55, 0)}, Vector3(0, 0, 0.3)),
			_k(0.52, {"ArmL": Vector3(-200, 0, 8), "HandL": H, "Torso": Vector3(-16, 10, 0)}, Vector3(0, 0.3, 0.3)),
			_k(0.64, {"ArmL": Vector3(-55, 0, 0), "HandL": H, "Torso": Vector3(28, 0, 0), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(30, 0, 0)}, Vector3(0, -0.12, 0.6)),
			_k(0.8, {"ArmL": Vector3(-50, 0, 0), "HandL": H, "Torso": Vector3(24, 0, 0)}, Vector3(0, -0.1, 0.6)),
		],
		"hits": [{"t": 0.07, "arc": 200, "reach": 1.4, "dmg": 0.6, "kb": 0.15}, {"t": 0.17, "arc": 200, "reach": 1.4, "dmg": 0.6, "kb": 0.15},
			{"t": 0.27, "arc": 200, "reach": 1.4, "dmg": 0.6, "kb": 0.15}, {"t": 0.37, "arc": 200, "reach": 1.4, "dmg": 0.6, "kb": 0.15},
			{"t": 0.63, "arc": 160, "reach": 1.4, "dmg": 1.8, "kb": 3.0, "poise": 4.0, "shock": true}],
		"trail": [0.02, 0.66], "lunge": [0.0, 0.6, 0.6],
	}

	# ---------------------------------------------------------------- lance
	var S := Vector3(178, 0, 0)
	_moves["spear_1"] = {
		"duration": 0.44, "combo": 0.24, "cancel": 0.2,
		"keys": [
			_k(0.0, GUARD),
			_k(0.08, {"ArmL": Vector3(-70, 0, 10), "HandL": S, "Torso": Vector3(0, 35, 0), "ArmR": Vector3(-50, 0, 20)}, Vector3(0, 0, -0.12)),
			_k(0.17, {"ArmL": Vector3(-92, 0, -4), "HandL": S, "Torso": Vector3(10, -15, 0), "ArmR": Vector3(20, 0, -20), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}, Vector3(0, -0.06, 0.35)),
			_k(0.3, {"ArmL": Vector3(-88, 0, -4), "HandL": S, "Torso": Vector3(8, -12, 0)}, Vector3(0, -0.04, 0.3)),
		],
		"hits": [{"t": 0.16, "arc": 45}], "trail": [0.1, 0.2], "lunge": [0.08, 0.18, 0.4],
	}
	_moves["spear_2"] = _moves["spear_1"].duplicate(true)
	_moves["spear_2"]["duration"] = 0.4
	_moves["spear_3"] = {  # balayage large
		"duration": 0.62, "combo": 0.45, "cancel": 0.36,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-88, 0, -4), "HandL": S, "Torso": Vector3(8, -12, 0)}, Vector3(0, -0.04, 0.2)),
			_k(0.12, {"ArmL": Vector3(-75, 0, 80), "HandL": S, "Torso": Vector3(0, 80, 0), "Head": Vector3(0, -40, 0)}, Vector3(0, -0.1, 0)),
			_k(0.28, {"ArmL": Vector3(-80, 0, -40), "HandL": S, "Torso": Vector3(8, -70, 0), "Head": Vector3(0, 40, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(25, 0, 0)}, Vector3(0, -0.1, 0.3), -40.0),
			_k(0.42, {"ArmL": Vector3(-60, 0, -40), "HandL": S, "Torso": Vector3(6, -50, 0)}, Vector3(0, -0.06, 0.3), -40.0),
		],
		"hits": [{"t": 0.22, "arc": 220, "reach": 1.0, "dmg": 1.6, "kb": 2.5, "poise": 2.0}], "trail": [0.12, 0.3], "lunge": [0.1, 0.26, 0.4],
	}

	# ---------------------------------------------------------------- arme lourde (2 mains)
	_moves["heavy_1"] = {
		"duration": 0.72, "combo": 0.46, "cancel": 0.42,
		"keys": [
			_k(0.0, GUARD),
			_k(0.22, {"ArmL": Vector3(-190, 0, 20), "HandL": H, "ArmR": Vector3(-170, 0, -20), "Torso": Vector3(-18, 25, 0), "Head": Vector3(-10, 0, 0)}, Vector3(0, 0.05, -0.1)),
			_k(0.34, {"ArmL": Vector3(-60, 0, 0), "HandL": H, "ArmR": Vector3(-50, 0, 10), "Torso": Vector3(30, 0, 0), "Head": Vector3(-15, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}, Vector3(0, -0.16, 0.45)),
			_k(0.5, {"ArmL": Vector3(-55, 0, 0), "HandL": H, "ArmR": Vector3(-45, 0, 10), "Torso": Vector3(26, 0, 0), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(28, 0, 0)}, Vector3(0, -0.14, 0.45)),
		],
		"hits": [{"t": 0.33, "arc": 110, "reach": 1.05, "dmg": 1.2, "kb": 1.8, "poise": 1.8, "shock": true}], "trail": [0.22, 0.36], "lunge": [0.24, 0.34, 0.5],
	}
	_moves["heavy_2"] = {
		"duration": 0.7, "combo": 0.46, "cancel": 0.42,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-55, 0, 0), "HandL": H, "ArmR": Vector3(-45, 0, 10), "Torso": Vector3(20, 0, 0)}, Vector3(0, -0.1, 0.2)),
			_k(0.2, {"ArmL": Vector3(-80, 0, 85), "HandL": H, "ArmR": Vector3(-70, 0, 50), "Torso": Vector3(0, 85, 0), "Head": Vector3(0, -40, 0)}, Vector3(0, -0.08, 0)),
			_k(0.34, {"ArmL": Vector3(-82, 0, -35), "HandL": H, "ArmR": Vector3(-70, 0, -10), "Torso": Vector3(10, -70, 0), "Head": Vector3(0, 40, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(25, 0, 0)}, Vector3(0, -0.12, 0.35)),
			_k(0.5, {"ArmL": Vector3(-60, 0, -35), "HandL": H, "ArmR": Vector3(-50, 0, -10), "Torso": Vector3(8, -55, 0)}, Vector3(0, -0.1, 0.35)),
		],
		"hits": [{"t": 0.28, "arc": 200, "reach": 1.0, "dmg": 1.2, "kb": 2.0, "poise": 1.6}], "trail": [0.2, 0.36], "lunge": [0.2, 0.32, 0.35],
	}
	_moves["heavy_3"] = _moves["slash_3"].duplicate(true)
	_moves["heavy_3"]["duration"] = 0.8
	_moves["heavy_3"]["hits"] = [{"t": 0.25, "arc": 140, "reach": 1.2, "dmg": 2.2, "kb": 3.5, "poise": 3.0, "shock": true}]

	# ---------------------------------------------------------------- bâton de mage
	_moves["cast_1"] = {
		"duration": 0.46, "combo": 0.28, "cancel": 0.2,
		"keys": [
			_k(0.0, GUARD),
			_k(0.1, {"ArmL": Vector3(-150, 0, 20), "HandL": H, "Torso": Vector3(-8, 30, 0), "ArmR": Vector3(-60, 0, -30)}, Vector3(0, 0.03, -0.05)),
			_k(0.2, {"ArmL": Vector3(-92, 0, 0), "HandL": H, "Torso": Vector3(10, -10, 0), "ArmR": Vector3(-40, 0, -40)}, Vector3(0, 0, 0.12)),
			_k(0.32, {"ArmL": Vector3(-85, 0, 0), "HandL": H, "Torso": Vector3(8, -8, 0)}, Vector3(0, 0, 0.1)),
		],
		"hits": [{"t": 0.18, "cast": true}], "trail": [0.1, 0.2],
	}
	_moves["cast_2"] = _moves["cast_1"].duplicate(true)
	_moves["cast_3"] = _moves["cast_1"].duplicate(true)
	_moves["cast_3"]["duration"] = 0.62
	_moves["cast_3"]["hits"] = [{"t": 0.18, "cast": true, "spread": 3, "dmg": 0.8}]

	# ---------------------------------------------------------------- récolte (geste d'outil)
	_moves["harvest_chop"] = {  # outil levé au-dessus de l'épaule, puis abattu (bûcheron, mineur)
		"duration": 0.5, "combo": 0.3, "cancel": 0.26,
		"keys": [
			_k(0.0, GUARD),
			_k(0.12, {"ArmL": Vector3(-165, 0, 25), "HandL": Vector3(150, 0, 0), "Torso": Vector3(-14, 22, 0), "Head": Vector3(-8, -10, 0), "ArmR": Vector3(-120, 0, -15)}, Vector3(0, 0.02, -0.05)),
			_k(0.24, {"ArmL": Vector3(-40, 0, 0), "HandL": Vector3(170, 0, 0), "Torso": Vector3(24, -6, 0), "Head": Vector3(12, 0, 0), "ArmR": Vector3(-45, 0, -10)}, Vector3(0, -0.06, 0.12)),
			_k(0.38, {"ArmL": Vector3(-35, 0, 5), "HandL": Vector3(160, 0, 0), "Torso": Vector3(16, -4, 0), "ArmR": Vector3(-35, 0, -12)}, Vector3(0, -0.03, 0.08)),
		],
		"hits": [{"t": 0.24, "arc": 120}], "trail": [0.14, 0.26],
	}

	# ---------------------------------------------------------------- poses de sort, selon la classe
	# (jouées par-dessus l'effet de la compétence : le héros incante à la manière de sa classe)
	_moves["pose_arcane"] = {  # mage, cryomancien, nécromancien : mains levées, puis projetées en avant
		"duration": 0.62,
		"keys": [
			_k(0.0, {}),
			_k(0.16, {"ArmL": Vector3(-165, 0, 30), "ArmR": Vector3(-165, 0, -30), "Torso": Vector3(-14, 0, 0), "Head": Vector3(-18, 0, 0)}, Vector3(0, 0.05, -0.06)),
			_k(0.32, {"ArmL": Vector3(-95, 0, -8), "ArmR": Vector3(-95, 0, 8), "Torso": Vector3(14, 0, 0), "Head": Vector3(6, 0, 0)}, Vector3(0, 0, 0.14)),
			_k(0.5, {"ArmL": Vector3(-85, 0, -5), "ArmR": Vector3(-85, 0, 5), "Torso": Vector3(8, 0, 0)}, Vector3(0, 0, 0.1)),
		],
	}
	_moves["pose_martial"] = {  # guerrier, barbare, chevalier : arme brandie au ciel, puis abattue
		"duration": 0.6,
		"keys": [
			_k(0.0, GUARD),
			_k(0.18, {"ArmL": Vector3(-178, 0, 8), "HandL": Vector3(175, 0, 0), "ArmR": Vector3(-30, 0, -40), "Torso": Vector3(-12, 18, 0), "Head": Vector3(-20, 0, 0)}, Vector3(0, 0.08, 0)),
			_k(0.34, {"ArmL": Vector3(-50, 0, 0), "HandL": Vector3(175, 0, 0), "ArmR": Vector3(-20, 0, -30), "Torso": Vector3(26, -8, 0), "Head": Vector3(10, 0, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}, Vector3(0, -0.14, 0.15)),
			_k(0.5, {"ArmL": Vector3(-45, 0, 0), "HandL": Vector3(170, 0, 0), "Torso": Vector3(18, -6, 0)}, Vector3(0, -0.08, 0.1)),
		],
	}
	_moves["pose_divine"] = {  # clerc, paladin, barde : bras ouverts vers le ciel, regard levé
		"duration": 0.7,
		"keys": [
			_k(0.0, {}),
			_k(0.22, {"ArmL": Vector3(-130, 0, 55), "ArmR": Vector3(-130, 0, -55), "Torso": Vector3(-12, 0, 0), "Head": Vector3(-30, 0, 0)}, Vector3(0, 0.1, 0)),
			_k(0.5, {"ArmL": Vector3(-120, 0, 60), "ArmR": Vector3(-120, 0, -60), "Torso": Vector3(-10, 0, 0), "Head": Vector3(-25, 0, 0)}, Vector3(0, 0.12, 0)),
		],
	}
	_moves["pose_bow"] = {  # rôdeur : un bras tendu, l'autre qui tire la corde jusqu'à la joue
		"duration": 0.6,
		"keys": [
			_k(0.0, {}),
			_k(0.16, {"ArmR": Vector3(-90, 0, -10), "ArmL": Vector3(-95, 0, 70), "HandL": Vector3(0, 0, -60), "Torso": Vector3(0, 40, 0), "Head": Vector3(0, -38, 0)}, Vector3(0, 0, -0.04)),
			_k(0.34, {"ArmR": Vector3(-90, 0, -10), "ArmL": Vector3(-90, 0, 95), "HandL": Vector3(0, 0, -80), "Torso": Vector3(0, 45, 0), "Head": Vector3(0, -42, 0)}, Vector3(0, 0, -0.06)),
			_k(0.42, {"ArmR": Vector3(-85, 0, -10), "ArmL": Vector3(-70, 0, 40), "Torso": Vector3(0, 30, 0), "Head": Vector3(0, -30, 0)}, Vector3(0, 0, -0.02)),
		],
	}
	_moves["pose_shadow"] = {  # assassin : accroupi, bras croisés, puis lames écartées d'un geste sec
		"duration": 0.52,
		"keys": [
			_k(0.0, {}),
			_k(0.14, {"ArmL": Vector3(-70, 0, -60), "ArmR": Vector3(-70, 0, 60), "Torso": Vector3(28, 0, 0), "Head": Vector3(10, 0, 0), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(-20, 0, 0)}, Vector3(0, -0.2, 0)),
			_k(0.28, {"ArmL": Vector3(-60, 0, 80), "ArmR": Vector3(-60, 0, -80), "Torso": Vector3(18, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-15, 0, 0)}, Vector3(0, -0.16, 0.1)),
			_k(0.42, {"ArmL": Vector3(-40, 0, 50), "ArmR": Vector3(-40, 0, -50), "Torso": Vector3(10, 0, 0)}, Vector3(0, -0.06, 0.05)),
		],
	}
	_moves["pose_nature"] = {  # druide : mains vers la terre, puis qui remontent lentement en appelant la sève
		"duration": 0.72,
		"keys": [
			_k(0.0, {}),
			_k(0.2, {"ArmL": Vector3(-20, 0, 35), "ArmR": Vector3(-20, 0, -35), "Torso": Vector3(30, 0, 0), "Head": Vector3(20, 0, 0)}, Vector3(0, -0.14, 0)),
			_k(0.5, {"ArmL": Vector3(-150, 0, 25), "ArmR": Vector3(-150, 0, -25), "Torso": Vector3(-10, 0, 0), "Head": Vector3(-20, 0, 0)}, Vector3(0, 0.08, 0)),
		],
	}
	_moves["pose_monk"] = {  # moine : garde basse, puis double paume projetée
		"duration": 0.5,
		"keys": [
			_k(0.0, {}),
			_k(0.14, {"ArmL": Vector3(-40, 0, -30), "ArmR": Vector3(-40, 0, 30), "Torso": Vector3(0, 30, 0), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(15, 0, 0)}, Vector3(0, -0.12, -0.06)),
			_k(0.26, {"ArmL": Vector3(-95, 0, 0), "ArmR": Vector3(-95, 0, 0), "Torso": Vector3(10, -10, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}, Vector3(0, -0.1, 0.22)),
			_k(0.4, {"ArmL": Vector3(-88, 0, 0), "ArmR": Vector3(-88, 0, 0), "Torso": Vector3(6, -6, 0)}, Vector3(0, -0.06, 0.18)),
		],
	}

	# ---------------------------------------------------------------- mains nues
	_moves["punch_1"] = {
		"duration": 0.3, "combo": 0.14, "cancel": 0.12,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-50, 0, 20), "ArmR": Vector3(-50, 0, -20)}),
			_k(0.08, {"ArmL": Vector3(-92, 0, -10), "ArmR": Vector3(-50, 0, -20), "Torso": Vector3(5, -25, 0)}, Vector3(0, 0, 0.2)),
			_k(0.18, {"ArmL": Vector3(-60, 0, 10), "ArmR": Vector3(-50, 0, -20), "Torso": Vector3(0, -10, 0)}, Vector3(0, 0, 0.15)),
		],
		"hits": [{"t": 0.08, "arc": 90}], "lunge": [0.03, 0.1, 0.25],
	}
	_moves["punch_2"] = {
		"duration": 0.32, "combo": 0.16, "cancel": 0.12,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-60, 0, 10), "ArmR": Vector3(-50, 0, -20)}),
			_k(0.09, {"ArmL": Vector3(-40, 0, 20), "ArmR": Vector3(-95, 0, 10), "Torso": Vector3(5, 30, 0)}, Vector3(0, 0, 0.25)),
			_k(0.2, {"ArmL": Vector3(-40, 0, 20), "ArmR": Vector3(-60, 0, -10), "Torso": Vector3(0, 15, 0)}, Vector3(0, 0, 0.2)),
		],
		"hits": [{"t": 0.09, "arc": 90}], "lunge": [0.03, 0.1, 0.25],
	}
	_moves["punch_3"] = {  # uppercut
		"duration": 0.46, "combo": 0.34, "cancel": 0.26,
		"keys": [
			_k(0.0, {"ArmL": Vector3(-40, 0, 20), "ArmR": Vector3(-60, 0, -10)}, Vector3(0, -0.1, 0)),
			_k(0.08, {"ArmL": Vector3(20, 0, 30), "ArmR": Vector3(-60, 0, -10), "Torso": Vector3(15, 30, 0), "LegL": Vector3(-30, 0, 0)}, Vector3(0, -0.18, 0)),
			_k(0.18, {"ArmL": Vector3(-170, 0, 0), "ArmR": Vector3(-20, 0, -30), "Torso": Vector3(-15, -20, 0)}, Vector3(0, 0.25, 0.3)),
			_k(0.32, {"ArmL": Vector3(-140, 0, 0), "Torso": Vector3(-10, -10, 0)}, Vector3(0, 0.05, 0.3)),
		],
		"hits": [{"t": 0.15, "arc": 100, "dmg": 1.6, "kb": 2.0, "poise": 2.0}], "lunge": [0.08, 0.16, 0.3],
	}

	# ---------------------------------------------------------------- poses tenues
	_moves["block"] = {  # garde : bouclier levé devant soi
		"duration": 0.1, "hold": true,
		"keys": [
			_k(0.0, GUARD),
			_k(0.1, {"ArmR": Vector3(-38, 0, 38), "ArmL": Vector3(-20, 0, 25), "HandL": Vector3(120, 0, 0), "Torso": Vector3(8, -28, 0), "Head": Vector3(0, 20, 0), "LegL": Vector3(-18, 0, 0), "LegR": Vector3(15, 0, 0)}, Vector3(0, -0.08, 0)),
		],
	}
	_moves["block_bare"] = {  # garde sans bouclier : arme en travers
		"duration": 0.1, "hold": true,
		"keys": [
			_k(0.0, GUARD),
			_k(0.1, {"ArmL": Vector3(-78, 0, -35), "HandL": Vector3(95, 0, 0), "ArmR": Vector3(-70, 0, 35), "Torso": Vector3(6, 0, 0), "LegL": Vector3(-18, 0, 0), "LegR": Vector3(15, 0, 0)}, Vector3(0, -0.08, 0)),
		],
	}
	_moves["parry"] = {  # parade réussie : on repousse l'arme adverse
		"duration": 0.34, "cancel": 0.0,
		"keys": [
			_k(0.0, {"ArmR": Vector3(-38, 0, 38), "ArmL": Vector3(-20, 0, 25), "HandL": Vector3(120, 0, 0), "Torso": Vector3(8, -28, 0)}, Vector3(0, -0.08, 0)),
			_k(0.08, {"ArmR": Vector3(-95, 0, -20), "ArmL": Vector3(-30, 0, 45), "HandL": Vector3(140, 0, 0), "Torso": Vector3(-8, 25, 0), "Head": Vector3(-10, -15, 0)}, Vector3(0, 0, -0.12)),
			_k(0.22, {"ArmR": Vector3(-60, 0, -10), "ArmL": Vector3(-30, 0, 30), "HandL": Vector3(150, 0, 0), "Torso": Vector3(0, 15, 0)}, Vector3(0, -0.04, -0.12)),
		],
	}
	_moves["stagger"] = {  # déséquilibré : titube en arrière
		"duration": 0.5,
		"keys": [
			_k(0.0, {}),
			_k(0.12, {"Torso": Vector3(-25, 15, 10), "Head": Vector3(-25, 0, 0), "ArmL": Vector3(40, 0, 40), "ArmR": Vector3(35, 0, -40), "LegL": Vector3(25, 0, 0)}, Vector3(0, -0.05, -0.2)),
			_k(0.35, {"Torso": Vector3(-12, 8, 5), "Head": Vector3(-10, 0, 0), "ArmL": Vector3(20, 0, 30), "ArmR": Vector3(15, 0, -30)}, Vector3(0, -0.04, -0.25)),
		],
	}
	_moves["dizzy"] = {  # étourdi (équilibre brisé)
		"duration": 1.0, "hold": true, "loop": true,
		"keys": [
			_k(0.0, {"Torso": Vector3(18, 0, 12), "Head": Vector3(20, 0, 15), "ArmL": Vector3(10, 0, 20), "ArmR": Vector3(10, 0, -20)}, Vector3(0, -0.15, 0)),
			_k(0.5, {"Torso": Vector3(18, 0, -12), "Head": Vector3(20, 0, -15), "ArmL": Vector3(10, 0, 15), "ArmR": Vector3(10, 0, -15)}, Vector3(0, -0.15, 0)),
			_k(1.0, {"Torso": Vector3(18, 0, 12), "Head": Vector3(20, 0, 15), "ArmL": Vector3(10, 0, 20), "ArmR": Vector3(10, 0, -20)}, Vector3(0, -0.15, 0)),
		],
	}
	_moves["flinch"] = {
		"duration": 0.24,
		"keys": [
			_k(0.0, {}),
			_k(0.06, {"Torso": Vector3(-18, 0, 6), "Head": Vector3(-15, 0, 0), "ArmL": Vector3(20, 0, 15), "ArmR": Vector3(20, 0, -15)}, Vector3(0, 0, -0.1)),
		],
	}
	# attaque des monstres humanoïdes : une frappe lente et bien annoncée
	_moves["enemy_chop"] = {
		"duration": 0.95, "cancel": 0.9,
		"keys": [
			_k(0.0, GUARD),
			_k(0.42, {"ArmL": Vector3(-195, 0, 15), "HandL": H, "Torso": Vector3(-14, 20, 0), "Head": Vector3(-8, 0, 0), "ArmR": Vector3(20, 0, -30)}, Vector3(0, 0.04, -0.1)),
			_k(0.56, {"ArmL": Vector3(-60, 0, -5), "HandL": H, "Torso": Vector3(26, -5, 0), "ArmR": Vector3(20, 0, -40), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}, Vector3(0, -0.12, 0.45)),
			_k(0.75, {"ArmL": Vector3(-55, 0, -5), "HandL": H, "Torso": Vector3(22, -5, 0)}, Vector3(0, -0.1, 0.45)),
		],
		"hits": [{"t": 0.55, "arc": 110}], "trail": [0.43, 0.58], "lunge": [0.44, 0.56, 0.5], "windup": 0.42,
	}
	_moves["enemy_sweep"] = {
		"duration": 0.9, "cancel": 0.85,
		"keys": [
			_k(0.0, GUARD),
			_k(0.4, {"ArmL": Vector3(-78, 0, 70), "HandL": H, "Torso": Vector3(0, 75, 0), "Head": Vector3(0, -30, 0)}, Vector3(0, -0.06, -0.08)),
			_k(0.54, {"ArmL": Vector3(-84, 0, -25), "HandL": H, "Torso": Vector3(8, -60, 0), "Head": Vector3(0, 30, 0)}, Vector3(0, -0.06, 0.35)),
			_k(0.72, {"ArmL": Vector3(-60, 0, -30), "HandL": H, "Torso": Vector3(6, -45, 0)}, Vector3(0, -0.04, 0.35)),
		],
		"hits": [{"t": 0.5, "arc": 170}], "trail": [0.42, 0.56], "lunge": [0.42, 0.54, 0.4], "windup": 0.4,
	}
	# créatures : bond et morsure
	_moves["bite"] = {
		"duration": 0.8, "cancel": 0.75,
		"keys": [
			_k(0.0, {}),
			_k(0.38, {"Head": Vector3(-25, 0, 0), "ArmL": Vector3(-25, 0, 0), "ArmR": Vector3(-25, 0, 0), "LegL": Vector3(30, 0, 0), "LegR": Vector3(30, 0, 0)}, Vector3(0, -0.12, -0.22)),
			_k(0.5, {"Head": Vector3(30, 0, 0), "ArmL": Vector3(-60, 0, 0), "ArmR": Vector3(-60, 0, 0), "LegL": Vector3(40, 0, 0), "LegR": Vector3(40, 0, 0)}, Vector3(0, 0.25, 0.6)),
			_k(0.62, {"Head": Vector3(15, 0, 0), "ArmL": Vector3(-20, 0, 0), "ArmR": Vector3(-20, 0, 0)}, Vector3(0, 0, 0.55)),
		],
		"hits": [{"t": 0.52, "arc": 90}], "lunge": [0.4, 0.55, 1.2], "windup": 0.38,
	}
	_moves["charge_ram"] = {  # sanglier : charge tête baissée
		"duration": 1.1, "cancel": 1.0,
		"keys": [
			_k(0.0, {}),
			_k(0.45, {"Head": Vector3(25, 0, 0), "ArmL": Vector3(-30, 0, 0), "ArmR": Vector3(20, 0, 0), "LegL": Vector3(30, 0, 0), "LegR": Vector3(-20, 0, 0)}, Vector3(0, -0.08, -0.25)),
			_k(0.8, {"Head": Vector3(30, 0, 0), "ArmL": Vector3(-50, 0, 0), "ArmR": Vector3(40, 0, 0), "LegL": Vector3(40, 0, 0), "LegR": Vector3(-40, 0, 0)}, Vector3(0, 0.05, 0.2)),
		],
		"hits": [{"t": 0.62, "arc": 100, "reach": 1.3, "kb": 2.0}, {"t": 0.75, "arc": 100, "reach": 1.3, "kb": 2.0}],
		"lunge": [0.45, 0.85, 3.2], "windup": 0.45,
	}
	# tirs des monstres (voir EnemyData.ranged_move) : longue préparation, puis le projectile part tout droit
	_moves["enemy_shoot"] = {  # bras armé tiré en arrière, puis lancé vers l'avant (flèche, plume)
		"duration": 1.0, "cancel": 0.95,
		"keys": [
			_k(0.0, GUARD),
			_k(0.5, {"ArmL": Vector3(-100, 0, 40), "HandL": H, "ArmR": Vector3(-90, 0, -10), "Torso": Vector3(-6, 35, 0), "Head": Vector3(0, -20, 0)}, Vector3(0, 0, -0.08)),
			_k(0.62, {"ArmL": Vector3(-88, 0, -10), "HandL": H, "ArmR": Vector3(-40, 0, -20), "Torso": Vector3(8, -15, 0)}, Vector3(0, 0, 0.1)),
			_k(0.8, {"ArmL": Vector3(-70, 0, -10), "HandL": H, "Torso": Vector3(6, -10, 0)}, Vector3(0, 0, 0.08)),
		],
		"hits": [{"t": 0.6, "cast": true}], "windup": 0.5,
	}
	_moves["enemy_spell"] = {  # les deux bras levés pour concentrer le sort, puis poussés vers l'avant
		"duration": 1.05, "cancel": 1.0,
		"keys": [
			_k(0.0, GUARD),
			_k(0.52, {"ArmL": Vector3(-165, 0, 25), "HandL": H, "ArmR": Vector3(-165, 0, -25), "Torso": Vector3(-12, 0, 0), "Head": Vector3(-15, 0, 0)}, Vector3(0, 0.08, -0.06)),
			_k(0.64, {"ArmL": Vector3(-90, 0, 8), "HandL": H, "ArmR": Vector3(-90, 0, -8), "Torso": Vector3(12, 0, 0), "Head": Vector3(5, 0, 0)}, Vector3(0, 0, 0.12)),
			_k(0.85, {"ArmL": Vector3(-75, 0, 8), "HandL": H, "ArmR": Vector3(-75, 0, -8), "Torso": Vector3(8, 0, 0)}, Vector3(0, 0, 0.1)),
		],
		"hits": [{"t": 0.62, "cast": true}], "windup": 0.52,
	}
	_moves["spit"] = {  # créatures : tête rejetée en arrière, puis crachat
		"duration": 0.95, "cancel": 0.9,
		"keys": [
			_k(0.0, {}),
			_k(0.48, {"Head": Vector3(-40, 0, 0), "ArmL": Vector3(15, 0, 0), "ArmR": Vector3(15, 0, 0), "LegL": Vector3(-15, 0, 0), "LegR": Vector3(-15, 0, 0)}, Vector3(0, 0.12, -0.2)),
			_k(0.58, {"Head": Vector3(35, 0, 0), "ArmL": Vector3(-20, 0, 0), "ArmR": Vector3(-20, 0, 0)}, Vector3(0, -0.05, 0.15)),
			_k(0.78, {"Head": Vector3(10, 0, 0)}, Vector3(0, 0, 0.05)),
		],
		"hits": [{"t": 0.56, "cast": true}], "windup": 0.48,
	}
