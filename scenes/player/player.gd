class_name Player
extends Combatant
## Personnage joueur. Combat en temps réel à la Zelda :
## - combo de 3 coups (le 3e est un coup final puissant), estoc en sortie de roulade ;
## - attaque chargée : garder le bouton appuyé, puis relâcher (attaque tournoyante) ;
## - roulade invulnérable ; esquiver au dernier moment = ESQUIVE PARFAITE (ralenti + rafale de coups) ;
## - garde (bouclier) ; lever la garde juste avant le coup = PARADE, puis CONTRE dévastateur ;
## - verrouillage de cible : la caméra et le personnage restent tournés vers l'ennemi.
## Change la race dans l'Inspecteur (propriété « race ») pour jouer n'importe quelle race.

signal dashed
## Un message à afficher (objet ramassé, équipé, fabriqué...).
signal notify(text: String)
## Le joueur veut ouvrir l'inventaire d'un personnage (lui-même ou un habitant proche).
signal open_inventory(target: Node)
## E près d'un voyageur : ouvre le dialogue de recrutement.
signal talk(stranger: Node)
## Grand message au centre de l'écran (« Parade ! », « Esquive parfaite ! »).
signal feat(text: String, color: Color)
## La cible verrouillée a changé (null = aucune).
signal lock_changed(target: Combatant)
## L'expérience a changé.
signal xp_changed(xp: int, needed: int, level: int)
## La compétence unique a changé (nouvelle compétence ou évolution).
signal skill_changed(skill: HeroSkill)
## L'arbre de talents a changé (talent débloqué, emplacements modifiés).
signal talents_changed
## La faim a changé (0 à 100).
signal hunger_changed(value: float)
## Le héros a mangé (identifiant de l'objet).
signal ate(item_id: String)
## Parler à un habitant qui a une quête.
signal quest_talk(villager: Node)
## Un décor a été récolté à la main (« arbre », « rocher », « buisson », « plante »).
signal harvested(kind: String)
## Un objet a été fabriqué (identifiant de l'objet).
signal crafted(item_id: String)
## Agriculture : case labourée, graine semée, culture récoltée (pour le guide).
signal tilled
signal planted(crop: String)
signal crop_harvested(crop: String)

@export var stats: PlayerStats
@export var race: RaceData
## Position de la caméra par rapport au joueur (en mètres).
@export var camera_offset: Vector3 = Vector3(0, 10, 10)
@export var camera_smoothing: float = 8.0
## Caméra plus proche pendant un verrouillage.
@export var lock_camera_offset: Vector3 = Vector3(0, 8, 8.5)

## Distance max pour parler à un habitant ou utiliser l'établi.
@export var interact_distance: float = 2.4
## Équipe automatiquement un objet ramassé si l'emplacement est vide.
@export var auto_equip: bool = true
## Kit du fondateur : blocs et meubles donnés au début d'une partie (paires objet / quantité).
@export var founder_kit: Array[ItemData] = []
@export var founder_counts: PackedInt32Array = PackedInt32Array()
## Temps avant de se relever au village après avoir été vaincu (secondes).
@export var respawn_delay: float = 4.0

@export_group("Combat")
## Distance max pour verrouiller une cible.
@export var lock_range: float = 14.0
## Temps à garder le bouton d'attaque appuyé pour charger l'attaque tournoyante (secondes).
@export var charge_time: float = 0.75
## Début de roulade pendant lequel une esquive est « parfaite » (secondes).
@export var perfect_dodge_window: float = 0.26
## Durée (temps réel) du ralenti après une esquive parfaite.
@export var perfect_dodge_slowmo: float = 1.4
## Temps pour déclencher le contre après une parade (secondes).
@export var counter_window: float = 1.2

@onready var camera: Camera3D = $Camera

## Le sac du joueur.
var inventory := Inventory.new()
## Vrai quand une fenêtre est ouverte (le joueur ne bouge plus).
## Un menu est ouvert (inventaire, carte, journal, royaume...) : l'interface de jeu s'efface (voir Hud).
var ui_open := false:
	set(v):
		if v != ui_open:
			ui_open = v
			ui_changed.emit(v)
signal ui_changed(open: bool)
## Cible verrouillée.
var lock_target: Combatant
## Le héros (race, apparence, classe, métier).
var profile: HeroProfile
## Arbre de talents : talents débloqués (id -> true), emplacements des talents actifs (touches 1-4).
var talents := {}
## Métiers (voir Crafts) : { métier: expérience }.
var crafts := {}
## Recettes favorites (identifiants des objets fabriqués).
var craft_favs: Array = []
## Carnet de découvertes : objets déjà eus en main (une recette est connue quand on a vu tous ses ingrédients).
var seen_items := {}
## Objets épinglés (3 au plus) : leur liste de courses s'affiche à l'écran.
var pinned: Array = []
signal pins_changed
## E devant un atelier (établi, enclume, four...) : son menu d'artisanat.
signal open_workshop(station: String)
const MAX_PINS := 3
## Évolution du héros (0 à 3), donnée par l'histoire principale (voir Evolution).
var hero_evo := 0
var _evo_fx := 0.0
var ability_slots: Array = ["", "", "", "", "", "", "", "", "", ""]
var abilities := {}      # id -> HeroSkill (talents actifs)
var selected_slot := 0
var _double_used := false
## Faim : 100 = rassasié, 0 = affamé. Elle baisse en ~15 min, plus vite en courant et en se battant.
const HUNGER_MAX := 100.0
const HUNGER_PER_SECOND := 100.0 / 900.0
## Au-dessus : « rassasié » (régénération bonus) ; en dessous : « affamé » (pas de régénération).
const WELL_FED := 70.0
const HUNGRY := 25.0
var hunger := HUNGER_MAX
var _starve_timer := 0.0
var _hunger_state := 1
## Faim, nourriture et potions (voir PlayerNeeds).
var _needs := PlayerNeeds.new(self)
## Bruits de pas : temps avant le prochain.
var _step_left := 0.0
## Récolte à la main : délai entre deux coups de pelle.
const DIG_TIME := 0.5
var _dig_timer := 0.0
## Clic droit maintenu avec un objet en main : on pose en continu.
var _place_repeat := 0.0
## Outil sorti du sac et tenu en main pour récolter (« » = l'arme est en main).
var tool_in_hand := ""
## Pose de blocs et de meubles à la main (molette / Ctrl + chiffre : choisir, clic droit ou V : poser, C : ranger).
var hand: HandBuild
var _tool_hold := 0.0
## Temps pendant lequel l'outil reste en main après le dernier coup de récolte.
const TOOL_HOLD := 3.0
## Distance de la caméra (option du joueur : 1 = normale ; molette pour zoomer).
var camera_zoom := 1.0
## Point de vue (F5) : 3e personne (par défaut), vue de dessus (l'ancienne caméra), 1re personne.
enum CamMode { THIRD, TOP, FIRST }
## 3e personne : distance de la caméra derrière le héros (avant le zoom) et champ de vision.
## La caméra passe au travers des obstacles (voir _update_camera_third).
const THIRD_DISTANCE := 6.2
const THIRD_FOV := 55.0
## Vitesse à laquelle la caméra 3e personne rattrape le héros : à l'horizontale, et en hauteur (plus lente,
## pour que les marches, les sauts et les atterrissages ne secouent pas l'image).
const CAM_FOLLOW := 9.0
const CAM_FOLLOW_Y := 3.5
## Vitesse de rattrapage de la rotation (assez vive pour viser, assez douce pour ne pas saccader).
const CAM_TURN := 22.0
const CAM_NAMES := ["3e personne", "Vue de dessus", "1re personne"]
var cam_mode := CamMode.THIRD
var _crosshair: CanvasLayer
## Rotation de la caméra autour du héros (clic molette maintenu + glisser, ou joystick droit).
var cam_yaw := 0.0
## Hauteur de la caméra (angle au-dessus de l'horizon, en radians).
var cam_pitch := deg_to_rad(45.0)
## Plancher de la caméra 3e personne (hauteur du sol sous elle, lissée).
var _cam_floor := -INF
## Point regardé par la caméra 3e personne (suit le héros en douceur) et recul actuel (suit le zoom).
var _cam_focus := Vector3.INF
var _cam_dist := 6.2
## Rotation affichée de la caméra 3e personne (suit cam_yaw / cam_pitch en douceur).
var _view_yaw := 0.0
var _view_pitch := deg_to_rad(45.0)
var _orbiting := false
var _orbit_moved := 0.0
var _orbit_pressed_at := 0
var level := 1
var xp := 0
## Terminal de commandes : vitesse multipliée (/vitesse) et invincibilité (/dieu).
var cheat_speed := 1.0
var cheat_god := false
## /vol : on vole au-dessus du monde (Saut : monter, Creuser : descendre), à travers tout.
var cheat_fly := false
## En mode construction (les clics servent à construire, pas à frapper).
var building := false
## Compétence unique (peut être null).
var skill: HeroSkill
var _base_parry_window := 0.22

var _dash_time := 0.0
var _dash_elapsed := 99.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.ZERO
var _respawn_left := 0.0
var _shake := 0.0
var _combo := 0
var _combo_reset := 0.0
var _queued := false
var _held := 0.0
var _charging := false
var _counter_ready := 0.0
var _flurry_until := 0
var _flurry_target: Combatant
var _perfect_cd := 0.0
var _ghost_timer := 0.0
var _reticle: Node3D


func _ready() -> void:
	poise_max = 999.0
	super()
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()
	camera.top_level = true
	# l'équipement changé remet l'arme en main
	equipment.changed.connect(func():
		_update_viewmodel()
		tool_in_hand = ""
		_apply_talents())
	# carnet : ce qu'on ramasse fait découvrir de nouvelles recettes
	inventory.changed.connect(_on_inventory_changed)
	hand = HandBuild.new()
	hand.name = "HandBuild"
	hand.player = self
	add_child(hand)
	# le héros créé dans l'écran de création, sinon un héros par défaut de la race choisie
	var hero: HeroProfile = GameState.hero
	if hero == null:
		hero = HeroProfile.new()
		hero.race = race
		hero.reset_colors()
		hero.hero_class = load("res://data/classes/guerrier.tres")
		hero.skill = load("res://data/skills/vorace.tres")
	# nouvelle partie : équipement de départ ; partie chargée : tout vient de la sauvegarde
	var loading: bool = not SaveGame.pending.is_empty()
	apply_profile(hero, GameState.hero != null and not loading)
	Crafts.init_for(self)
	camera_zoom = float(SaveGame.options.camera_distance)
	parried.connect(_on_parried)
	_make_reticle()
	_make_crosshair()
	# GG_CAMERA (tests) : impose un point de vue
	var forced := OS.get_environment("GG_CAMERA")
	set_camera_mode(int(forced) if forced != "" else int(SaveGame.options.get("camera_mode", 0)), false)
	# la souris est gérée même quand le jeu est en pause (menu pause)
	get_tree().process_frame.connect(_update_mouse_mode)
	snap_camera()


## Applique le héros : modèle, couleurs, taille, caractéristiques ; `new_game` donne l'équipement de départ.
func apply_profile(hero: HeroProfile, new_game := true) -> void:
	profile = hero
	race = hero.race
	visual.set_equipment_library(race.equipment if race else null)
	visual.set_colors(hero.skin_color, hero.hair_color, hero.eye_color)
	visual.set_model(hero.model(hero_evo))
	_apply_evo_scale()
	if hero.skill and (skill == null or skill.data != hero.skill):
		skill = HeroSkill.new(hero.skill, self)
		skill.set_level(level)
		skill.evolved.connect(_on_skill_evolved)
		skill_changed.emit(skill)
	if new_game:
		_give_class_talent()
		if GameState.bare_start:
			inventory.add(Items.get_item(WorldGenerator.FLAG_ID), 1)
	if new_game and not GameState.bare_start:
		if hero.hero_class:
			for it in hero.hero_class.starting_equipment:
				for old in equipment.equip(it):
					inventory.add(old)
		for i in founder_kit.size():
			inventory.add(founder_kit[i], founder_counts[i] if i < founder_counts.size() else 1)
		if hero.job:
			for i in hero.job.starting_items.size():
				var n := hero.job.starting_counts[i] if i < hero.job.starting_counts.size() else 1
				inventory.add(hero.job.starting_items[i], n)
	_update_max_health(true)


## Change de race en gardant le reste du héros (touche R, pour tester).
func apply_race(new_race: RaceData) -> void:
	if profile == null:
		race = new_race
		return
	profile.race = new_race
	profile.reset_colors()
	apply_profile(profile, false)


func _update_max_health(refill := false) -> void:
	var hp := (race.max_health if race else stats.max_health)
	if profile:
		if profile.hero_class:
			hp += profile.hero_class.bonus_health + profile.hero_class.health_per_level * (power_level() - 1)
		if profile.job:
			hp += profile.job.bonus_health
	if skill:
		hp = roundi(hp * skill.hp_mult()) + skill.absorbed["health"]
	health.set_max(hp, refill)
	var regen := 2.0 + (profile.job.bonus_regen if profile and profile.job else 0.0)
	if skill:
		regen += skill.p("regen")
		parry_window = _base_parry_window + skill.p("parry")
	regen += hunger_regen_bonus()
	# au camp (dans la zone du drapeau) : on récupère plus vite
	if in_camp:
		regen += CAMP_REGEN
	health.regen_per_second = regen + _kingdom_bonus("regen") if is_inside_tree() else regen
	if hunger < HUNGRY:
		health.regen_per_second = 0.0


## Recalcule les caractéristiques (après une absorption, un renforcement...).
func refresh_stats() -> void:
	_update_max_health(false)
	# la traînée de l'arme prend la couleur de sa rareté (blanche pour une arme commune)
	var w := weapon()
	var tc := Color(0.85, 0.95, 1.0)
	if w and w.rarity > ItemData.Rarity.COMMON:
		tc = w.rarity_color()
	if visual:
		visual.set_trail_color(tc)
	xp_changed.emit(xp, xp_to_next(), level)


# ---------------------------------------------------------------- compétence unique

func attack_power() -> int:
	var v := super()
	if skill:
		v = roundi(v * skill.atk_mult()) + skill.absorbed["attack"]
	return v + roundi(_kingdom_bonus("attack"))


func defense_power() -> int:
	return super() + (skill.def_bonus() if skill else 0) + roundi(_kingdom_bonus("defense"))


func magic_power() -> int:
	var v := super()
	if skill:
		v = roundi(v * skill.mag_mult()) + skill.absorbed["magic"]
	return roundi(v * (1.0 + _kingdom_bonus("magic")))


func outgoing_multiplier(target: Combatant) -> float:
	return skill.outgoing_multiplier(target) if skill else 1.0


func roll_crit() -> bool:
	return skill != null and randf() < skill.crit_chance()


func crit_multiplier() -> float:
	return 1.5 + (skill.p("crit_mult") if skill else 0.0)


func incoming_multiplier() -> float:
	return skill.incoming_multiplier() if skill else 1.0


func poise_multiplier() -> float:
	return 1.0 + (skill.p("poise") if skill else 0.0)


func _on_damage_dealt(target: Combatant, dmg: int) -> void:
	if skill:
		skill.on_damage_dealt(target, dmg)


## Appelé par un monstre quand il est vaincu.
func on_enemy_killed(enemy: Combatant) -> void:
	if skill:
		skill.on_kill(enemy)


# ---------------------------------------------------------------- arbre de talents

## Talent offert par la classe (gratuit).
func class_talent() -> String:
	if profile == null or profile.hero_class == null:
		return ""
	return TalentTree.CLASS_START.get(profile.hero_class.resource_path.get_file().get_basename(), "")


func _give_class_talent() -> void:
	var id := class_talent()
	if id != "" and not talents.has(id):
		talents[id] = true
		_apply_talents()
	grant_class_skills(false)


## Spécialisation choisie (voie) : sa compétence ultime est offerte et rangée dans la barre.
func _choose_spec(id: String) -> void:
	var n := TalentTree.node(id)
	var ult := id + "_ult"
	talents[ult] = true
	if not ability_slots.has(ult):
		for i in range(ability_slots.size() - 1, -1, -1):
			if ability_slots[i] == "":
				ability_slots[i] = ult
				break
	_apply_talents()
	var col: Color = n.get("color", Color("ffd27a"))
	Sound.ui("levelup")
	feat.emit("Spécialisation : %s !" % n.name, col.lightened(0.2))
	notify.emit("Tu deviens %s. Compétence ultime : %s (barre de compétences)." % [n.name, TalentTree.node(ult).name])
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), col, 80, 5.0, 0.12, 1.4, "up", -1.5)
	SkillFX.ring(self, global_position, 5.0, col, 0.8)


## Titre du héros : sa spécialisation si elle est choisie, sinon sa classe.
func class_title() -> String:
	var sp := TalentTree.chosen_spec(class_id(), talents)
	if sp != "":
		return TalentTree.node(sp).name
	return profile.hero_class.display_name if profile and profile.hero_class else ""


## Identifiant de la classe du héros (« guerrier »...), ou "".
func class_id() -> String:
	if profile == null or profile.hero_class == null:
		return ""
	return profile.hero_class.resource_path.get_file().get_basename()


## Offre les compétences de classe atteintes (niveaux TalentTree.CLASS_LEVELS) ; elles se rangent dans la
## barre en partant de la droite (touches 0, 9, 8) si la place est libre. `announce` : message et effets.
func grant_class_skills(announce := true) -> void:
	var cid := class_id()
	var got := false
	for n in TalentTree.class_skills(cid):
		if talents.has(n.id) or level < int(n.level):
			continue
		talents[n.id] = true
		got = true
		if not ability_slots.has(n.id):
			for i in range(ability_slots.size() - 1, -1, -1):
				if ability_slots[i] == "":
					ability_slots[i] = n.id
					break
		if announce:
			var col: Color = n.get("color", Color("ffd27a"))
			Sound.ui("talent")
			feat.emit("Compétence de classe : %s !" % n.name, col.lightened(0.2))
			notify.emit("%s : %s (barre de compétences, {talents} : arbre, onglet Classe)." % [n.name, n.desc])
			VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), col, 40, 3.5, 0.1, 1.0, "up", -1.5)
	if got:
		_apply_talents()


## Points gagnés : 2 par niveau jusqu'au niveau 50, puis 1 (voir TalentTree.points_until) + 1 par âme de boss.
func talent_points_total() -> int:
	return TalentTree.points_until(level) + souls.size()


func talent_points_spent() -> int:
	var n := 0
	var free := class_talent()
	for id in talents:
		if id != free:
			n += TalentTree.cost(id)
	return n


func talent_points() -> int:
	return talent_points_total() - talent_points_spent()


## Pourquoi ce talent ne peut pas être débloqué ("" s'il peut l'être).
func talent_block_reason(id: String) -> String:
	var n := TalentTree.node(id)
	if n.is_empty():
		return "?"
	if talents.has(id):
		return "Déjà appris"
	if n.has("cls"):
		if n.cls != class_id():
			return "Compétence d'une autre classe"
		if n.has("spec"):
			if n.kind == "active":
				return "Choisis d'abord la voie %s" % TalentTree.node(n.requires[0]).name
			if level < TalentTree.SPEC_LEVEL:
				return "Spécialisation : niveau %d requis" % TalentTree.SPEC_LEVEL
			var chosen := TalentTree.chosen_spec(class_id(), talents)
			if chosen != "":
				return "Tu as déjà choisi la voie %s (« Tout oublier » pour changer)" % TalentTree.node(chosen).name
			return ""
		return "Offerte par ta classe au niveau %d" % int(n.level)
	if n.get("story", false):
		return "Se débloque en avançant dans l'histoire principale"
	var need := TalentTree.level_of(id)
	if level < need:
		return "Niveau %d requis" % need
	var req: Array = n.get("requires", [])
	if not req.is_empty() and not req.any(func(r): return talents.has(r)):
		return "Apprends d'abord un nœud relié (plus près du centre)"
	if talent_points() < TalentTree.cost(id):
		return "Pas assez de points"
	return ""


func _apply_evo_scale() -> void:
	if profile:
		visual.scale = Vector3(profile.build, profile.height, profile.build) * (1.0 + 0.04 * hero_evo)


## Modèle de l'évolution (cornes, marques, auréole... selon la race) et taille.
func _apply_evo_look() -> void:
	if profile:
		visual.set_model(profile.model(hero_evo))
	_apply_evo_scale()


## Titre de l'évolution (« Seigneur-bête »...), vide avant la première.
func evo_title() -> String:
	return Evolution.hero_title(race, hero_evo)


## Le héros évolue (histoire principale) : plus fort, un peu plus grand, un nouveau titre.
func evolve_hero() -> void:
	if hero_evo >= 3:
		return
	hero_evo += 1
	_apply_evo_look()
	_apply_talents()
	health.heal(health.max_health)
	var col: Color = Evolution.HERO_COLOR[hero_evo - 1]
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), col, 90, 6.0, 0.13, 1.6, "up", -1.0)
	SkillFX.ring(self, global_position, 6.0, col, 0.9)
	shake(0.6)
	Sound.ui("levelup")
	feat.emit("Évolution ! Tu deviens : %s" % evo_title(), col)
	notify.emit("Ton âme s'éveille : tu deviens %s. Vie, attaque et magie augmentent (évolution %d / 3)." % [evo_title(), hero_evo])


## Compétence unique offerte par l'histoire (sans point, sans condition).
func grant_story_talent(id: String) -> void:
	var n := TalentTree.node(id)
	if n.is_empty() or talents.has(id):
		return
	talents[id] = true
	if n.kind == "active":
		var free := ability_slots.find("")
		if free >= 0:
			ability_slots[free] = id
	_apply_talents()
	Sound.ui("levelup")
	feat.emit("Compétence unique : %s !" % n.name, Color("d8c0ff"))
	notify.emit("Nouvelle compétence unique : %s. %s ({talents} : arbre de talents%s)" % [n.name, n.desc,
		", touches 1-4" if n.kind == "active" else ""])
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), Color("c8a8ff"), 60, 4.5, 0.12, 1.3, "up", -1.5)
	SkillFX.ring(self, global_position, 4.0, Color("c8a8ff"), 0.7)


func unlock_talent(id: String) -> bool:
	if talent_block_reason(id) != "":
		return false
	talents[id] = true
	var n := TalentTree.node(id)
	if n.has("spec"):
		_choose_spec(id)
		return true
	if n.kind == "active":
		var free := ability_slots.find("")
		if free >= 0:
			ability_slots[free] = id
	_apply_talents()
	var rar := TalentTree.rarity(id)
	var big: bool = n.get("rarity", "") in ["legendaire", "mystique"]
	Sound.ui("levelup" if big else "talent")
	feat.emit("%s : %s" % [rar.name if n.kind == "active" or big else "Talent", n.name], (rar.color as Color).lightened(0.2))
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), rar.color, 90 if big else 40, 5.0 if big else 3.5, 0.1, 1.4 if big else 1.0, "up", -1.5)
	if big:
		SkillFX.ring(self, global_position, 6.0, rar.color, 0.8)
	return true


## Oublie tous les talents (sauf celui de la classe) et rend les points.
func reset_talents() -> void:
	# les compétences de l'histoire restent
	var keep := talents.keys().filter(func(id): return TalentTree.is_story(id))
	talents.clear()
	for id in keep:
		talents[id] = true
	ability_slots = ["", "", "", "", "", "", "", "", "", ""]
	_give_class_talent()
	_apply_talents()


func set_ability_slot(slot: int, id: String) -> void:
	for i in ability_slots.size():
		if ability_slots[i] == id:
			ability_slots[i] = ""
	ability_slots[slot] = id
	talents_changed.emit()


## Applique les passifs et prépare les talents actifs.
func _apply_talents() -> void:
	var bonus := TalentTree.passive_bonus(talents)
	# les gemmes serties de l'équipement porté
	var gb := Forge.equipment_bonus(self)
	for k in gb:
		bonus[k] = float(bonus.get(k, 0.0)) + float(gb[k])
	# les évolutions du héros s'ajoutent aux talents
	var eb := Evolution.hero_bonus(hero_evo)
	for k in eb:
		bonus[k] = float(bonus.get(k, 0.0)) + float(eb[k])
	if skill:
		skill.talent_bonus = bonus
	for id in abilities.keys():
		if not talents.has(id):
			abilities.erase(id)
	for id in talents:
		if TalentTree.node(id).get("kind") == "active" and not abilities.has(id):
			var hs := HeroSkill.new(TalentTree.make_skill(id), self)
			abilities[id] = hs
	for id in abilities:
		abilities[id].talent_bonus = bonus
		abilities[id].set_level(level)
	for i in ability_slots.size():
		if ability_slots[i] != "" and not talents.has(ability_slots[i]):
			ability_slots[i] = ""
	refresh_stats()
	talents_changed.emit()


func talent_bonus(key: String) -> float:
	return float(skill.talent_bonus.get(key, 0.0)) if skill else 0.0


## Lance le talent actif de l'emplacement `slot` (0 à 3).
## Le héros n'avance pas tout seul en frappant (seuls les coups reçus le font reculer).
func lunge_velocity() -> Vector3:
	return Vector3.ZERO


func cast_ability(slot: int) -> bool:
	var id: String = ability_slots[slot] if slot < ability_slots.size() else ""
	if id == "" or not abilities.has(id) or not can_act() or ui_open or building:
		return false
	var hs: HeroSkill = abilities[id]
	_aim_with_camera()
	if not hs.activate():
		return false
	# les renforcements et barrières passent sur le héros (sa compétence principale)
	if skill and hs != skill:
		for k in hs.buffs:
			skill.buffs[k] = hs.buffs[k]
		hs.buffs.clear()
		if hs._barrier_left > 0.0:
			skill._barrier_left = hs._barrier_left
			skill._barrier_reduce = hs._barrier_reduce
			hs._barrier_left = 0.0
		refresh_stats()
	return true


func use_skill() -> void:
	if skill and can_act() and not ui_open:
		skill.activate()


func _on_skill_evolved(old_name: String, new_name: String, tier: int) -> void:
	feat.emit("Évolution ! %s → %s" % [old_name, new_name], skill.data.color.lightened(0.3))
	notify.emit("%s évolue en %s (%s)." % [old_name, new_name, SkillData.TIER_LABELS[tier]])
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.2, 0), skill.data.color, 60, 5.0, 0.13, 1.4, "up", -1.0)
	SkillFX.ring(self, global_position, 5.0, skill.data.color, 0.8)
	TimeFX.slow_motion(0.4, 0.8)
	_update_max_health(true)
	skill_changed.emit(skill)


func _class_bonus(field: String, per_level: String) -> float:
	if profile == null or profile.hero_class == null:
		return 0.0
	return float(profile.hero_class.get(field)) + float(profile.hero_class.get(per_level)) * (power_level() - 1)


func _job_bonus(field: String) -> float:
	return float(profile.job.get(field)) if profile and profile.job else 0.0


func base_attack() -> int:
	return roundi((race.strength if race else 10) + _class_bonus("bonus_attack", "attack_per_level") + _job_bonus("bonus_attack"))


func base_defense() -> int:
	return roundi(_class_bonus("bonus_defense", "defense_per_level") + _job_bonus("bonus_defense"))


func base_magic() -> int:
	return roundi((race.magic if race else 10) + _class_bonus("bonus_magic", "magic_per_level") + _job_bonus("bonus_magic"))


## L'agilité de la race accélère les coups (+1,5 % par point au-dessus de 10).
func attack_speed() -> float:
	return super() * (1.0 + ((race.agility if race else 10) - 10) * 0.015) * (skill.aspd_mult() if skill else 1.0)


## Multiplicateur de butin (métier).
func loot_multiplier() -> float:
	return (profile.job.loot_multiplier if profile and profile.job else 1.0) * (1.0 + (skill.p("loot") if skill else 0.0))


# ---------------------------------------------------------------- niveaux

## Niveau maximum du héros.
const MAX_LEVEL := 1000


## Expérience nécessaire pour passer au niveau suivant : la même courbe qu'avant jusqu'au niveau 100,
## puis +10 par niveau (12 505 au niveau 1000).
func xp_to_next() -> int:
	if level <= 100:
		return 40 + (level - 1) * 35
	return 3505 + (level - 100) * 10


## Niveau de puissance : il suit le niveau jusqu'à 100, puis monte 4 fois moins vite (325 au niveau 1000).
## Il fixe les statistiques de base du héros et le niveau des ennemis qui s'adaptent à lui :
## au-delà de 100, c'est l'arbre de compétences qui fait la différence.
func power_level() -> int:
	return power_level_of(level)


static func power_level_of(lv: int) -> int:
	return lv if lv <= 100 else 100 + (lv - 100) / 4


## Au-delà du niveau 100, chaque ennemi vaincu rapporte plus (x4 au niveau 1000).
func xp_level_mult() -> float:
	return 1.0 if level <= 100 else 1.0 + (level - 100) / 300.0


## Gagne de l'expérience (monstre vaincu...).
func gain_xp(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	if level >= MAX_LEVEL:
		return
	amount = roundi(amount * (1.0 + (skill.p("xp") if skill else 0.0) + _kingdom_bonus("xp")) * xp_level_mult())
	xp += amount
	Combat.popup(self, global_position + Vector3(0, 2.3 * visual.height_scale(), 0), "+%d XP" % amount, Color("9fe0ff"))
	while xp >= xp_to_next() and level < MAX_LEVEL:
		xp -= xp_to_next()
		level += 1
		if level >= MAX_LEVEL:
			xp = 0
		_update_max_health(true)
		if skill:
			skill.set_level(level)
		for id in abilities:
			abilities[id].set_level(level)
		feat.emit("Niveau %d !" % level, Color("ffd24a"))
		grant_class_skills()
		if level == TalentTree.SPEC_LEVEL and TalentTree.chosen_spec(class_id(), talents) == "" and not TalentTree.spec_nodes(class_id()).is_empty():
			var sn := TalentTree.spec_nodes(class_id())
			notify.emit("Niveau %d : choisis ta spécialisation, %s ou %s ({talents} : arbre, onglet Classe et Pacte)." % [TalentTree.SPEC_LEVEL, sn[0].name, sn[2].name])
		Sound.ui("levelup")
		notify.emit("+%d point%s de compétence ({talents} : arbre de compétences)." % [TalentTree.points_for_level(level), "s" if TalentTree.points_for_level(level) > 1 else ""])
		talents_changed.emit()
		notify.emit("Niveau %d : vie, attaque et magie augmentent." % level)
		VoxelBurst.spawn(self, global_position + Vector3(0, 0.2, 0), Color(1.0, 0.85, 0.3), 40, 3.5, 0.1, 1.2, "up", -1.5)
		VoxelBurst.spawn(self, global_position + Vector3(0, 0.1, 0), Color(1.0, 0.95, 0.6), 30, 5.0, 0.08, 0.6, "ring", 0.0)
	xp_changed.emit(xp, xp_to_next(), level)


## Passe directement à un niveau (terminal de commandes), sans les effets de chaque niveau gagné.
func set_level_to(n: int) -> void:
	level = clampi(n, 1, MAX_LEVEL)
	xp = 0
	_update_max_health(true)
	if skill:
		skill.set_level(level)
	for id in abilities:
		abilities[id].set_level(level)
	grant_class_skills(false)
	feat.emit("Niveau %d !" % level, Color("ffd24a"))
	talents_changed.emit()
	xp_changed.emit(xp, xp_to_next(), level)


## Secoue la caméra (coup reçu, coup porté).
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength * Access.shake_scale())


## Place la caméra directement sur le joueur (sans glissement).
func snap_camera() -> void:
	if cam_mode != CamMode.TOP:
		_update_camera(1000.0)
		return
	camera.global_position = global_position + camera_vector(camera_offset)
	camera.look_at(global_position + Vector3(0, 0.8, 0))


## Change de point de vue (`announce` : petit message à l'écran).
func set_camera_mode(m: int, announce := true) -> void:
	cam_mode = posmod(m, 3) as CamMode
	cam_pitch = clamp_pitch(cam_pitch if cam_mode == CamMode.TOP else (deg_to_rad(20.0) if cam_mode == CamMode.THIRD else 0.0))
	if cam_mode == CamMode.TOP:
		cam_pitch = deg_to_rad(45.0)
	if visual:
		visual.visible = cam_mode != CamMode.FIRST
	_update_viewmodel()
	Villager.label_scale = [0.45, 1.0, 0.32][cam_mode]
	camera.fov = THIRD_FOV if cam_mode == CamMode.THIRD else 40.0
	_apply_view_range()
	if is_inside_tree():
		snap_camera()
	if announce:
		SaveGame.options.camera_mode = int(cam_mode)
		SaveGame.save_options()
		notify.emit("Vue : %s (F5 pour changer)" % CAM_NAMES[cam_mode])


## Vue rapprochée : la caméra ne dessine que la zone chargée, que la brume efface au loin (deux fois moins
## d'appels de dessin qu'en regardant jusqu'à 250 m) ; vue de dessus : comme avant.
func _apply_view_range() -> void:
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator if is_inside_tree() else null
	if w == null:
		(func(): if is_inside_tree() and get_tree().get_first_node_in_group("world"): _apply_view_range()).call_deferred()
		return
	var close := cam_mode != CamMode.TOP
	w.set_close_view(close)
	camera.far = w.close_view_far() if close else 250.0


func clamp_pitch(v: float) -> float:
	match cam_mode:
		CamMode.THIRD:
			return clampf(v, deg_to_rad(-35.0), deg_to_rad(70.0))
		CamMode.FIRST:
			return clampf(v, deg_to_rad(-80.0), deg_to_rad(80.0))
	return clampf(v, deg_to_rad(18.0), deg_to_rad(80.0))


## 1re personne : le bras et l'arme du héros, accrochés à la caméra (balancement en marchant, coup qui part).
var _viewmodel: Node3D
var _vm_arm: MeshInstance3D
var _vm_weapon: Node3D
var _vm_t := 0.0
var _vm_swing := 0.0
const VM_BASE := Vector3(0.3, -0.24, -0.58)


func _update_viewmodel() -> void:
	if camera == null:
		return
	if _viewmodel == null:
		_viewmodel = Node3D.new()
		_viewmodel.name = "Viewmodel"
		camera.add_child(_viewmodel)
		_vm_arm = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.14, 0.5)
		_vm_arm.mesh = box
		_vm_arm.position = Vector3(0, -0.02, 0.18)
		_vm_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_viewmodel.add_child(_vm_arm)
		_vm_weapon = Node3D.new()
		# l'arme pointe vers l'avant et un peu vers le haut, comme tenue en main
		_vm_weapon.rotation_degrees = Vector3(-62, 8, 0)
		_vm_weapon.position = Vector3(0, 0.02, -0.08)
		_viewmodel.add_child(_vm_weapon)
	_viewmodel.visible = cam_mode == CamMode.FIRST
	_viewmodel.position = VM_BASE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = profile.skin_color if profile else Color("d8a070")
	# bras couvert si une armure est portée sur le torse
	var chest := equipment.get_item(ItemData.Slot.CHEST)
	if chest:
		mat.albedo_color = chest.tint if chest.tint.a > 0.0 else Color("8a8a90")
	_vm_arm.material_override = mat
	for c in _vm_weapon.get_children():
		c.queue_free()
	var w := weapon()
	if w == null:
		return
	var meshes := []
	if Arsenal.is_arsenal(w.model_id()):
		meshes.append(Arsenal.mesh_for(w.model_id()))
	elif race and race.equipment:
		for part in VoxelCharacter.parts_for(race.equipment, w.model_id()):
			meshes.append(part[1])
	for m in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# les modèles sont à l'échelle du personnage : on les ramène à environ 0,7 m
		var h: float = maxf(0.1, (m as Mesh).get_aabb().size.length())
		mi.scale = Vector3.ONE * (0.75 / h)
		_vm_weapon.add_child(mi)


func _animate_viewmodel(delta: float) -> void:
	if _viewmodel == null or not _viewmodel.visible:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and not airborne
	_vm_t += delta * (9.0 if moving else 2.0)
	var bob := Vector3(cos(_vm_t * 0.5) * 0.012, absf(sin(_vm_t)) * (0.02 if moving else 0.006), 0)
	_vm_swing = maxf(0.0, _vm_swing - delta * 4.0)
	var s := sin(_vm_swing * PI)
	_viewmodel.position = VM_BASE + bob + Vector3(-0.12 * s, 0.05 * s, -0.12 * s)
	_viewmodel.rotation_degrees = Vector3(-35.0 * s, 25.0 * s, 0)


## Devant la caméra, à plat.
func camera_forward() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))


# ---------------------------------------------------------------- visée à la souris

## Ce que vise la souris (voir Aim) : {kind, point, normal, dist, key / cell / node}. Vide sans souris.
var aim := {}
## Vrai dès que la souris a bougé une fois : à partir de là, c'est elle qui vise (sinon, à la manette ou
## sans souris, le héros frappe et pose devant lui comme avant).
var _mouse_seen := false
var _aim_box: MeshInstance3D
var _aim_label: Label


func aim_active() -> bool:
	return _mouse_seen and bool(SaveGame.options.get("mouse_aim", true)) and camera != null and camera.current and not building and not ui_open and is_alive() \
		and not (cam_mode == CamMode.TOP and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE))


## Lance le rayon de visée : par le viseur (centre de l'écran) en 3e et 1re personne, par le curseur en
## vue de dessus.
func _update_aim() -> void:
	if not aim_active():
		aim = {}
		_show_aim()
		return
	var vp := get_viewport()
	var mp := vp.get_mouse_position() if cam_mode == CamMode.TOP else vp.get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	aim = Aim.cast(self, origin, dir, camera.global_position.distance_to(global_position) + 16.0)
	# aide légère (3e et 1re personne) : un ennemi à portée, à moins de 4° du viseur, est visé
	if str(aim.get("kind")) != "enemy" and cam_mode != CamMode.TOP:
		var best: Combatant = null
		var best_a := deg_to_rad(4.0)
		for n in get_tree().get_nodes_in_group(hostile_group()):
			var c := n as Combatant
			if c == null or not c.is_alive() or c.global_position.distance_to(global_position) > attack_reach() + 2.5:
				continue
			var a := dir.angle_to(c.global_position + Vector3(0, 0.9, 0) - origin)
			if a < best_a:
				best_a = a
				best = c
		if best:
			var at := best.global_position + Vector3(0, 0.9, 0)
			aim = {"kind": "enemy", "node": best, "point": at, "normal": -dir, "t": origin.distance_to(at),
				"dist": at.distance_to(global_position + Vector3(0, 1.0, 0)), "assist": true}
	_show_aim()


## Ce qu'un coup toucherait d'après la visée (pour la récolte) : {"block"}, {"furniture"}, {"cell"},
## {"prop"}, {"crop"} ou {} si rien n'est visé à portée.
func aim_target() -> Dictionary:
	if aim.is_empty() or float(aim.get("dist", INF)) > Aim.REACH_HIT:
		return {}
	match str(aim.kind):
		"block":
			return {"block": aim.key}
		"furniture":
			return {"furniture": aim.key}
		"decor":
			return {"cell": aim.cell}
		"prop":
			return {"prop": aim.node}
		"crop":
			return {"crop": aim.cell}
	return {}


## Contour de ce qui est visé (bloc, meuble, arbre, rocher, décor du village, culture) et couleur du viseur :
## rouge sur un ennemi à portée, doré sur ce qui se récolte ou se casse, blanc sinon.
func _show_aim() -> void:
	var col := Color(1, 1, 1, 0.8)
	var box := AABB()
	var show := false
	if not aim.is_empty():
		var k := str(aim.kind)
		var d := float(aim.get("dist", INF))
		if k in ["enemy", "animal"] and d <= attack_reach() + 1.6:
			col = Color(1.0, 0.35, 0.3, 0.95)
		elif k in ["block", "furniture", "decor", "prop", "crop"] and d <= Aim.REACH_HIT and not holding_item():
			col = Color(1.0, 0.85, 0.35, 0.95)
			box = Aim.target_box(get_tree().get_first_node_in_group("world") as WorldGenerator, aim)
			show = box.size != Vector3.ZERO
	if _aim_label:
		_aim_label.add_theme_color_override("font_color", col)
	if show and _aim_box == null:
		_aim_box = MeshInstance3D.new()
		_aim_box.mesh = Aim.wire_box()
		_aim_box.top_level = true
		_aim_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.04, 0.04, 0.04, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_aim_box.material_override = m
		add_child(_aim_box)
	if _aim_box:
		_aim_box.visible = show
		if show:
			_aim_box.global_transform = Transform3D(Basis().scaled(box.size + Vector3.ONE * 0.03), box.get_center())


## En 3e et 1re personne (et en vue de dessus avec la souris), on frappe et on lance ses sorts là où
## l'on vise : le héros se tourne vers le point visé (l'ennemi visé s'il y en a un).
func _aim_with_camera() -> void:
	if lock_target and is_instance_valid(lock_target):
		return
	if aim_active() and not aim.is_empty():
		var pt: Vector3 = aim.point
		if str(aim.kind) == "enemy" and is_instance_valid(aim.node):
			pt = (aim.node as Node3D).global_position
		var flat := pt - global_position
		flat.y = 0.0
		if flat.length() > 0.15:
			facing = flat.normalized()
			visual.rotation.y = atan2(facing.x, facing.z)
		return
	if cam_mode == CamMode.TOP:
		return
	facing = camera_forward()
	# aide à la visée : l'ennemi le plus proche du viseur (moins de 10°), à portée de tir
	var look := -camera.global_transform.basis.z
	var best: Node3D = null
	var best_a := deg_to_rad(10.0)
	for e in get_tree().get_nodes_in_group("enemy_units"):
		if not (e is Combatant) or not e.is_alive():
			continue
		var to: Vector3 = (e as Node3D).global_position + Vector3(0, 0.9, 0) - camera.global_position
		if to.length() > 26.0 or (e as Node3D).global_position.distance_to(global_position) > 22.0:
			continue
		var a := look.angle_to(to)
		if a < best_a:
			best_a = a
			best = e
	if best:
		var flat := best.global_position - global_position
		flat.y = 0.0
		if flat.length() > 0.2:
			facing = flat.normalized()


## Souris capturée (elle tourne la caméra) en 3e et 1re personne, sauf quand un menu est ouvert,
## en construction, ou en maintenant Alt.
func _update_mouse_mode() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var want := cam_mode != CamMode.TOP and not ui_open and not building and is_alive() and not get_tree().paused \
		and not Input.is_key_pressed(KEY_ALT) and camera.current
	var mode := Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	if _crosshair:
		_crosshair.visible = want


func _make_crosshair() -> void:
	_crosshair = CanvasLayer.new()
	_crosshair.layer = 1
	var l := Label.new()
	l.text = "+"
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.add_child(l)
	_aim_label = l
	_crosshair.visible = false
	add_child(_crosshair)


# ---------------------------------------------------------------- boucle

## Le héros est dans la zone de son camp (autour du drapeau) : il y récupère plus vite.
var in_camp := false
var _camp_check := 0.0
const CAMP_REGEN := 3.0
signal camp_changed(inside: bool)


func _physics_process(delta: float) -> void:
	_update_aim()
	_combat_step(delta)
	_footsteps(delta)
	_update_hunger(delta)
	_camp_check -= delta
	if _camp_check <= 0.0:
		_camp_check = 0.5
		var wd := _world if _world else get_tree().get_first_node_in_group("world") as WorldGenerator
		var inside := wd != null and wd.in_home_zone(global_position)
		if inside != in_camp:
			in_camp = inside
			_update_max_health()
			camp_changed.emit(in_camp)
	_update_tool(delta)
	# aura des évolutions supérieures
	if hero_evo >= 2 and is_alive():
		_evo_fx -= delta
		if _evo_fx <= 0.0:
			_evo_fx = 1.1
			var off := Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4))
			VoxelBurst.spawn(self, global_position + off, Evolution.HERO_COLOR[hero_evo - 1], 4, 1.4, 0.07, 0.8, "up", -3.0)
	if skill:
		skill.process(delta)
	for id in abilities:
		abilities[id].process(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_dash_elapsed += delta
	_counter_ready = maxf(_counter_ready - delta, 0.0)
	_perfect_cd = maxf(_perfect_cd - delta, 0.0)
	_combo_reset -= delta
	if _combo_reset <= 0.0 and not in_move():
		_combo = 0
	if not is_alive():
		_respawn_left -= delta
		velocity = Vector3.ZERO
		_move_on_ground(delta)
		visual.animate(delta, Vector3.ZERO, facing)
		_update_camera(delta)
		if _respawn_left <= 0.0:
			_respawn()
		return
	_update_lock()

	var can_input := not ui_open
	# en mode construction, le héros reste sur place (c'est la caméra libre qui bouge)
	var input2 := Input.get_vector("move_left", "move_right", "move_up", "move_down") if can_input and not building else Vector2.ZERO
	# les touches suivent la caméra : « haut » = vers là où regarde la caméra
	var input := Vector3(input2.x, 0, input2.y).rotated(Vector3.UP, cam_yaw)
	if can_input and not building:
		_update_orbit_stick(delta)
		if Input.is_action_just_pressed("jump") and can_act() and not in_move() and not is_dashing():
			# double saut (talent Ombre)
			if airborne and not _double_used and talent_bonus("double_jump") > 0.0:
				_double_used = true
				air_vy = 7.2
				VoxelBurst.spawn(self, global_position + Vector3(0, 0.1, 0), Color(0.6, 1.0, 0.7), 12, 2.5, 0.07, 0.35, "ring", 0.0, false)
			elif jump():
				_double_used = false
				VoxelBurst.spawn(self, global_position + Vector3(0, 0.05, 0), Color(0.8, 0.75, 0.65), 8, 2.0, 0.07, 0.3, "ring", 0.0, false)
		# creuser le sol devant soi (maintenir G / gâchette droite) : terre, sable, cailloux
		_dig_timer = maxf(0.0, _dig_timer - delta)
		# blocs seulement (pas la canne, la barque...), et on s'arrête au premier échec
		if holding_item() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and can_act() and hand.selected_item() \
				and hand.selected_item().is_block():
			_place_repeat -= delta
			if _place_repeat <= 0.0:
				_place_repeat = 0.25 if _place_in_hand() else INF
		if Input.is_action_pressed("dig") and can_act() and not in_move() and not is_dashing() and not airborne and _dig_timer <= 0.0:
			_dig_timer = DIG_TIME
			_aim_with_camera()
			visual.play_move("heavy_1", 1.4)
			dig()
	if input.length() > 1.0:
		input = input.normalized()
	var speed: float = cheat_speed * stats.move_speed * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier() * (1.0 + _job_bonus("bonus_speed")) * (skill.speed_mult() if skill else 1.0) * (0.85 if hunger <= 0.0 else 1.0) * _weather_speed() * (_mounts_node().speed_mult() if _mounts_node() else 1.0)

	if can_input and can_act() and not building:
		_handle_combat_input(input, delta)

	if is_dashing():
		_dash_time -= delta
		velocity = _dash_dir * stats.dash_speed
		if TimeFX.is_slowed():
			_spawn_ghosts(delta)
		if not is_dashing():
			visual.set_trail(false)
	elif not can_act():
		velocity = velocity.move_toward(Vector3.ZERO, stats.friction * delta)
	elif in_move():
		# comme dans Minecraft : frapper ne déplace pas le héros (pas d'élan) ; il peut marcher en frappant, plus lentement
		velocity = input * speed * 0.55 if input != Vector3.ZERO else Vector3.ZERO
	else:
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		var max_speed := speed
		if blocking:
			max_speed *= 0.35
		elif _charging:
			max_speed *= 0.5
		elif lock_target:
			max_speed *= 0.8
		if input != Vector3.ZERO:
			if not lock_target and not blocking:
				facing = input
			horizontal = horizontal.move_toward(input * max_speed, stats.acceleration * delta)
		else:
			horizontal = horizontal.move_toward(Vector3.ZERO, stats.friction * delta)
		velocity = horizontal
	# 1re personne : le héros regarde toujours devant la caméra (on marche de côté)
	if cam_mode == CamMode.FIRST and not lock_target and not is_dashing():
		facing = camera_forward()
	if lock_target and not is_dashing() and (not in_move() or move_t < 0.05):
		var to := lock_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			facing = to.normalized()

	if TimeFX.is_slowed() and in_move() and move_name == "flurry":
		_spawn_ghosts(delta)
	_move_on_ground(delta)
	# à cheval ou en barque, le héros est assis : pas de pas
	visual.animate(delta, velocity if not is_mounted() else Vector3.ZERO, facing)
	_update_camera(delta)
	_update_reticle(delta)


func _handle_combat_input(input: Vector3, delta: float) -> void:
	# roulade (annule un coup en fin d'animation)
	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and not is_dashing() and can_cancel():
		_stop_charge()
		set_blocking(false)
		cancel_move()
		_start_dash(input if input != Vector3.ZERO else facing)
		return
	# garde / parade
	# un objet en main : le clic droit pose (voir _input), pas de garde
	var guard := Input.is_action_pressed("block") and not (holding_item() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	if guard and not in_move() and not is_dashing():
		if Input.is_action_just_pressed("block") or not blocking:
			set_blocking(true)
			if not Input.is_action_just_pressed("block"):
				_block_time = 1.0  # garde tenue : pas de parade sans nouvel appui
	elif blocking:
		set_blocking(false)
	# attaque
	var pressed := Input.is_action_just_pressed("attack")
	var held := Input.is_action_pressed("attack")
	if pressed:
		_attack_pressed()
	if _charging:
		_held += delta
		visual.set_weapon_glow(clampf(_held / charge_time, 0.0, 1.0))
		if not held:
			if _held >= charge_time:
				_stop_charge()
				_threaten(true)
				_do_move("spin", 1.0, 1.0)
				feat.emit("Attaque tournoyante !", Color("ffd86a"))
			else:
				_stop_charge()
	elif held and not in_move() and not blocking and not is_dashing() and weapon_style() != ItemData.WeaponStyle.STAFF:
		_held += delta
		if _held > 0.22:
			_charging = true
			visual.play_move("charge")
	elif not held:
		_held = 0.0
	# enchaînement mémorisé
	if _queued and can_chain():
		_queued = false
		_next_combo()


## Le monstre le plus proche devant le héros voit venir le coup : il peut esquiver ou lever sa garde
## (une attaque chargée brise toute garde).
func _threaten(heavy: bool) -> void:
	var best: Node = null
	var best_d := attack_reach() + 1.3
	for n in get_tree().get_nodes_in_group(hostile_group()):
		if not n.has_method("on_threatened"):
			continue
		var to: Vector3 = (n as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if heavy and d < attack_reach() + 1.0 and n.has_method("break_guard"):
			n.break_guard()
		if d < best_d and (d < 0.5 or facing.dot(to / d) > 0.35):
			best_d = d
			best = n
	if best:
		best.on_threatened(self, heavy)


func _attack_pressed() -> void:
	_held = 0.0
	_aim_with_camera()
	_threaten(false)
	_vm_swing = 1.0
	if blocking:
		set_blocking(false)
	# riposte après une esquive parfaite
	if Time.get_ticks_msec() < _flurry_until and _flurry_target and _flurry_target.is_alive():
		_flurry_until = 0
		_do_flurry()
		return
	# contre après une parade
	if _counter_ready > 0.0:
		_counter_ready = 0.0
		cancel_move()
		_do_move("counter", 1.1, 1.0)
		feat.emit("Contre !", Color("ffb040"))
		return
	# estoc en sortie de roulade
	if (is_dashing() or _dash_elapsed < 0.18) and weapon_style() != ItemData.WeaponStyle.STAFF:
		_dash_time = 0.0
		visual.set_trail(false)
		_do_move("dash_thrust", 1.0, 1.0)
		return
	if in_move():
		if can_chain():
			_next_combo()
		elif move_t > float(_move.get("combo", 0.0)) - 0.3:
			_queued = true
		return
	_combo = 0
	_next_combo()


func _next_combo() -> void:
	var list := MoveLibrary.combo_for(weapon_style())
	var name: String = list[_combo % list.size()]
	_combo += 1
	_combo_reset = 0.7
	_aim_assist()
	_ready_tool_for_swing()
	spend_hunger(0.2)
	# on vise un arbre, un rocher, un bloc... (et pas d'ennemi tout près) : un vrai geste d'outil
	if _aiming_at_harvest():
		name = "harvest_chop"
	_do_move(name, attack_speed(), 1.0)


## Réception d'un saut : un petit nuage de poussière sous les pieds.
func _on_landed() -> void:
	VoxelBurst.emit(self, global_position + Vector3(0, 0.08, 0), {"color": Color(0.72, 0.65, 0.52), "count": 8, "speed": 1.6,
		"size": 0.1, "life": 0.45, "glow": false, "grow": true, "alpha": 0.55, "mode": "ring", "gravity": -0.3})


func _aiming_at_harvest() -> bool:
	if not aim_active() or _enemy_close(4.0):
		return false
	return str(aim.get("kind", "")) in ["decor", "block", "prop", "furniture", "crop", "terrain"] and float(aim.get("dist", INF)) <= Aim.REACH_HIT


func _do_move(name: String, speed: float, dmg: float) -> void:
	if in_move():
		cancel_move()
	perform(name, speed, dmg)


func _stop_charge() -> void:
	if _charging:
		_charging = false
		visual.stop_move()
	visual.set_weapon_glow(0.0)
	_held = 0.0


## Se tourne vers l'ennemi le plus proche s'il est presque en face (aide à viser).
func _aim_assist() -> void:
	if lock_target:
		return
	var reach := minf(attack_reach(), 8.0) + 1.5
	var enemy := nearest_hostile(reach)
	if enemy == null:
		return
	var to := enemy.global_position - global_position
	to.y = 0.0
	if to.length() > 0.01 and absf(Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z))) < deg_to_rad(75.0):
		facing = to.normalized()
		visual.rotation.y = atan2(facing.x, facing.z)


## Les coups portent aussi sur les animaux (poules, moutons, vaches) devant le héros : on peut chasser.
func _hit_animals(hit: Dictionary) -> int:
	var reach := clampf(attack_reach() * float(hit.get("reach", 1.0)), 1.6, 3.0)
	var arc := deg_to_rad(float(hit.get("arc", 120.0)) * 0.5)
	var fwd := Vector2(facing.x, facing.z).normalized()
	var dmg := maxi(1, roundi(attack_power() * float(hit.get("dmg", 1.0)) * _move_damage * 0.5))
	var n := 0
	for a in get_tree().get_nodes_in_group("farm_animals"):
		var an := a as FarmAnimal
		if an == null or not an.is_alive():
			continue
		var off := Vector2(an.global_position.x - global_position.x, an.global_position.z - global_position.z)
		if off.length() > reach + 0.4 or absf(an.global_position.y - global_position.y) > 1.6:
			continue
		if off.length() > 0.3 and absf(fwd.angle_to(off.normalized())) > arc:
			continue
		if an.take_hit(dmg, self):
			n += 1
	return n


func _on_attack_landed(hits: int, hit: Dictionary) -> void:
	hits += _hit_animals(hit)
	var harvested := _harvest_swing(hit)
	if hits <= 0:
		if harvested:
			TimeFX.hit_stop(0.03)
			shake(0.3)
		return
	var heavy := float(hit.get("dmg", 1.0)) >= 1.5
	TimeFX.hit_stop(0.09 if heavy else 0.045)
	shake(1.0 if heavy else 0.5)


## Les sorts du bâton récoltent aussi ce qui est tout près.
func _do_hit(h: Dictionary) -> void:
	super(h)
	if h.get("cast", false):
		_harvest_swing(h)


## Chaque coup frappe aussi le décor devant le héros (arbre, rocher, cabane...), façon Minecraft.
## Le héros donne un coup d'outil (bâtir un plan) : geste, et le bras bouge en 1re personne.
func work_gesture(at: Vector3) -> void:
	var to := at - global_position
	to.y = 0.0
	if to.length() > 0.2 and not in_move():
		facing = to.normalized()
	_vm_swing = 0.8
	if visual and not in_move() and Vector2(velocity.x, velocity.z).length() < 0.5:
		visual.play_move("heavy_1", 1.6)


func _harvest_swing(h: Dictionary) -> bool:
	if building or ui_open:
		return false
	var reach := clampf(attack_reach() * float(h.get("reach", 1.0)), 1.6, 2.6)
	var power := 2.0 if float(h.get("dmg", 1.0)) * _move_damage >= 1.8 else 1.0
	# les blocs posés ne se cassent que s'il n'y a pas d'ennemi tout près (pas de mur cassé en combat)
	return Harvest.strike(self, reach, power, not _enemy_close(4.5))


## Un coup de pelle dans la case devant le héros (renvoie ce qui a été obtenu, ou null).
func dig() -> ItemData:
	var pick := Harvest.best_tool(self, "pioche")
	if pick != "":
		_show_tool(pick)
	return Harvest.dig(self)


# ---------------------------------------------------------------- faim

func spend_hunger(amount: float) -> void:
	hunger = maxf(0.0, hunger - amount)


func hunger_regen_bonus() -> float:
	return 1.5 if hunger >= WELL_FED else 0.0


## 2 : rassasié, 1 : normal, 0 : affamé, -1 : meurt de faim.
func hunger_state() -> int:
	if hunger <= 0.0:
		return -1
	if hunger < HUNGRY:
		return 0
	return 2 if hunger >= WELL_FED else 1


var _weather: Node


## Froid (neige) : on avance moins vite.
func _weather_speed() -> float:
	if _weather == null or not is_instance_valid(_weather):
		_weather = get_tree().get_first_node_in_group("weather")
	return _weather.speed_mult() if _weather else 1.0


func _update_hunger(delta: float) -> void:
	_needs.update(delta)


func _on_hunger_state() -> void:
	_needs.on_state_changed()


## Potions bues depuis le début (pour le guide).
var potions_drunk := 0


## Boit une potion (touche R) : voir PlayerNeeds.drink_potion.
func drink_potion() -> ItemData:
	return _needs.drink_potion()


## Mange la nourriture du sac la mieux adaptée à sa faim (ou `item`). Voir PlayerNeeds.eat.
func eat(item: ItemData = null) -> ItemData:
	return _needs.eat(item)


# ---------------------------------------------------------------- bruits de pas

## Un bruit de pas selon le sol : herbe, pierre, bois (plancher posé), sable.
func _footsteps(delta: float) -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	if airborne or v < 1.2 or is_dashing() or building:
		_step_left = minf(_step_left, 0.1)
		return
	_step_left -= delta
	if _step_left > 0.0:
		return
	_step_left = clampf(1.6 / v, 0.24, 0.45)
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	var surf := "grass"
	if world:
		var cell := world.cell_at(global_position)
		var under := world.build.block_at(Vector3i(cell.x, floori(global_position.y - 0.2), cell.y)) if global_position.y > WorldGenerator.UNDERGROUND else null
		if under:
			surf = "stone" if under.block_tier >= 1 else "wood"
		elif global_position.y < WorldGenerator.UNDERGROUND:
			surf = "stone"
		else:
			match world.terrain_type(cell):
				WorldGenerator.STONE, WorldGenerator.PLAZA:
					surf = "stone"
				WorldGenerator.SAND:
					surf = "sand"
	Sound.play("step_" + surf, global_position, -14.0, 0.12)


# ---------------------------------------------------------------- outil en main

## Avant un coup : la hache pour un arbre, la pioche pour un rocher ; l'arme s'il y a un ennemi tout près.
func _ready_tool_for_swing() -> void:
	if _enemy_close(4.5):
		_put_tool_away()
		return
	var id := Harvest.tool_for_target(self, clampf(attack_reach(), 1.6, 2.6), true)
	if id != "":
		_show_tool(id)
	else:
		_put_tool_away()


func _show_tool(id: String) -> void:
	_tool_hold = TOOL_HOLD
	if id == tool_in_hand:
		return
	tool_in_hand = id
	visual.show_equipment(ItemData.Slot.MAIN_HAND, id)


## Range l'outil et reprend l'arme équipée.
func _put_tool_away() -> void:
	if tool_in_hand == "":
		return
	tool_in_hand = ""
	var w := weapon()
	visual.show_equipment(ItemData.Slot.MAIN_HAND, w.model_id() if w else "")


func _update_tool(delta: float) -> void:
	if tool_in_hand == "":
		return
	_tool_hold -= delta
	if _tool_hold <= 0.0 or _enemy_close(6.0) or building:
		_put_tool_away()


func _enemy_close(radius: float) -> bool:
	for e in get_tree().get_nodes_in_group("enemy_units"):
		if e is Combatant and (e as Combatant).is_alive() and (e as Node3D).global_position.distance_to(global_position) < radius:
			return true
	return false


# ---------------------------------------------------------------- défense

func _on_hurt(amount: int, source: Node) -> void:
	if skill:
		skill.on_hurt(amount, source)
	shake(0.8 + amount * 0.04)
	_stop_charge()
	cancel_move()


## Un coup vient d'être esquivé pendant la roulade : si c'est au dernier moment, esquive parfaite.
func _on_evaded(attacker: Combatant) -> void:
	if not is_dashing() or _dash_elapsed > perfect_dodge_window + (skill.p("dodge") if skill else 0.0) or _perfect_cd > 0.0 or attacker == null:
		return
	_perfect_cd = 2.0
	_flurry_target = attacker
	_flurry_until = Time.get_ticks_msec() + roundi(perfect_dodge_slowmo * 1000.0)
	TimeFX.slow_motion(0.25, perfect_dodge_slowmo)
	visual.set_trail(true, Color(0.45, 0.85, 1.0))
	feat.emit("Esquive parfaite !", Color("7fd8ff"))
	VoxelBurst.spawn(self, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.85, 1.0), 24, 4.0, 0.08, 0.5, "ring", 0.0)


func _on_parried(attacker: Combatant) -> void:
	_counter_ready = counter_window
	TimeFX.hit_stop(0.14)
	TimeFX.slow_motion(0.45, 0.5)
	shake(1.2)
	feat.emit("Parade !", Color("ffe27a"))
	if attacker and lock_target == null:
		_set_lock(attacker)


## Riposte après une esquive parfaite : on se précipite sur l'ennemi et on enchaîne les coups.
func _do_flurry() -> void:
	var t := _flurry_target
	var to := t.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else facing
	visual.spawn_afterimage(Color(0.4, 0.8, 1.0, 0.6), 0.5)
	global_position = t.global_position - dir * (t.body_radius + 1.0)
	facing = dir
	visual.rotation.y = atan2(dir.x, dir.z)
	_do_move("flurry", 1.2, 1.0)
	TimeFX.slow_motion(0.35, 0.9)
	feat.emit("Riposte !", Color("7fd8ff"))


func _spawn_ghosts(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.03
		visual.spawn_afterimage(Color(0.4, 0.8, 1.0, 0.45), 0.35)


func _on_died() -> void:
	# certaines compétences sauvent d'un coup mortel
	if skill and skill.try_last_stand():
		health.revive(0.3)
		_invulnerable_left = 2.0
		feat.emit("%s : vous refusez de tomber !" % skill.current_name(), skill.data.color.lightened(0.3))
		VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), skill.data.color, 50, 5.0, 0.12, 1.0, "up", -1.0)
		SkillFX.shell(self, skill.data.color, 2.0, 1.2)
		return
	super()
	_respawn_left = respawn_delay
	_dash_time = 0.0
	_set_lock(null)
	_stop_charge()
	TimeFX.cancel()
	notify.emit("Vous êtes tombé au combat…")


## Se relève au village, avec toute sa vie.
# ---------------------------------------------------------------- nage

## Souffle (secondes sous l'eau) ; à zéro, on se noie petit à petit.
const BREATH_MAX := 15.0
const SWIM_SPEED := 0.62
## Profondeur d'eau à partir de laquelle on nage (sinon on marche dans l'eau).
const SWIM_DEPTH := 1.2
## Hauteur des yeux au-dessus des pieds, et des pieds sous la surface quand on nage en surface.
const EYES := 1.72
const FLOAT_DEPTH := 1.45
signal breath_changed(value: float)
var swimming := false
var breath := BREATH_MAX
var _drown_timer := 0.0
var _caves: Node


func _can_swim() -> bool:
	# à cheval, on ne va pas dans l'eau
	return not _riding()


var _mounts: Node


func _mounts_node() -> Node:
	if _mounts == null or not is_instance_valid(_mounts):
		_mounts = get_tree().get_first_node_in_group("mounts")
	return _mounts


func _riding() -> bool:
	var m := _mounts_node()
	return m != null and m.is_riding()


## À cheval ou en barque.
func is_mounted() -> bool:
	var m := _mounts_node()
	return m != null and m.mount != null and is_instance_valid(m.mount)


## Surface de l'eau au-dessus de cette position (-INF s'il n'y a pas d'eau) : lacs et mers, grottes inondées.
func water_top(pos := Vector3.INF) -> float:
	if pos == Vector3.INF:
		pos = global_position
	if _world == null:
		return -INF
	if pos.y < WorldGenerator.UNDERGROUND:
		if _caves == null or not is_instance_valid(_caves):
			_caves = get_tree().get_first_node_in_group("caves")
		return _caves.water_top(pos) if _caves else -INF
	var t := _world.terrain_type(_world.cell_at(pos))
	if t == WorldGenerator.WATER or t == WorldGenerator.DEEP:
		if _world.build and _world.build.support(_world.cell_at(pos), 1000.0) > _world.water_surface:
			return -INF
		return _world.water_surface
	return -INF


## Fond sous l'eau (terrain, ou sol de la grotte).
func _water_floor(pos: Vector3) -> float:
	if pos.y < WorldGenerator.UNDERGROUND:
		var g := _world.dungeon_grid.support(_world.cell_at(pos), pos.y + 0.6) if _world.dungeon_grid else -INF
		return g if g > -INF else pos.y
	return _world.terrain_height(_world.cell_at(pos))


## La tête est sous l'eau.
func is_underwater() -> bool:
	var top := water_top()
	return top > -INF and global_position.y + EYES < top - 0.05


## Dans l'eau (qu'on nage ou qu'on y marche).
func in_water() -> bool:
	var top := water_top()
	return top > -INF and global_position.y < top


func _move_on_ground(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
	var mo := _mounts_node()
	if (cheat_fly or (mo and mo.is_flying())) and _world:
		_fly_move(delta)
		return
	# en barque : on glisse sur l'eau
	if mo and mo.sail_move(delta):
		swimming = false
		breath = BREATH_MAX
		return
	var top := water_top()
	var floor_h := _water_floor(global_position) if top > -INF else -INF
	if top > -INF and top - floor_h >= SWIM_DEPTH:
		_swim_move(delta, top, floor_h)
	else:
		if swimming:
			swimming = false
		super(delta)
		# on marche dans l'eau peu profonde : on avance moins vite (le sol est sous l'eau)
		if top > -INF and not airborne:
			global_position.y = floor_h
	_update_breath(delta, top)


## /vol : on traverse tout, à 2,5 fois la vitesse de marche ; jamais sous le sol.
func _fly_move(delta: float) -> void:
	swimming = false
	airborne = false
	air_vy = 0.0
	breath = BREATH_MAX
	var vy := 0.0
	if not ui_open:
		if Input.is_action_pressed("jump"):
			vy = 9.0
		elif Input.is_action_pressed("dig"):
			vy = -9.0
	var to := global_position + Vector3(velocity.x, 0, velocity.z) * 2.5 * delta
	to.y += vy * delta
	var cell := _world.cell_at(to)
	to.x = clampf(to.x, 1.0, _world.world_size.x - 1.0)
	to.z = clampf(to.z, 1.0, _world.world_size.y - 1.0)
	if to.y > WorldGenerator.UNDERGROUND:
		to.y = maxf(to.y, _world.terrain_height(cell))
	global_position = to
	velocity = Vector3(velocity.x, 0, velocity.z)
	if visual:
		visual.airborne = vy != 0.0


func _swim_move(delta: float, top: float, floor_h: float) -> void:
	if not swimming:
		swimming = true
		airborne = false
		air_vy = 0.0
		visual.airborne = false
		Sound.play("dig", global_position)
		VoxelBurst.spawn(self, Vector3(global_position.x, top, global_position.z), Color(0.75, 0.9, 1.0), 16, 3.0, 0.08, 0.5, "up", 8.0, false)
	var base := velocity * SWIM_SPEED
	var from := global_position
	var to := from + (base + _knockback) * delta
	to = _swim_constrain(from, to, top)
	# monter (saut) / plonger (creuser) ; sinon on reste à la même profondeur
	var vy := 0.0
	if not ui_open and not building:
		if Input.is_action_pressed("jump"):
			vy = 2.8
		elif Input.is_action_pressed("dig"):
			vy = -2.8
	var cave := from.y < WorldGenerator.UNDERGROUND
	var ceiling := top - (FLOAT_DEPTH if not cave else EYES + 0.3)
	to.y = clampf(from.y + vy * delta, floor_h, maxf(floor_h, ceiling))
	global_position = to
	velocity = Vector3(velocity.x, 0, velocity.z)
	# sortie de l'eau sur la berge
	var ground := _world.ground_height_at(Vector3(to.x, top + 1.0, to.z)) if not cave else floor_h
	if water_top(to) == -INF and ground > -INF:
		global_position.y = ground
		swimming = false


## Peut-on nager jusque-là ? L'eau, ou une berge pas plus haute que la surface + 0,7 m.
func _swim_constrain(from: Vector3, to: Vector3, top: float) -> Vector3:
	for cand in [to, Vector3(to.x, to.y, from.z), Vector3(from.x, to.y, to.z)]:
		var cell := _world.cell_at(cand)
		if from.y < WorldGenerator.UNDERGROUND:
			var g := _world.dungeon_grid.support(cell, from.y + 0.6) if _world.dungeon_grid else -INF
			if g > -INF and not _world.dungeon_grid.body_blocked(cell, maxf(g, from.y)):
				return cand
			continue
		if water_top(cand) > -INF:
			if not _world.build.body_blocked(cell, from.y):
				return cand
			continue
		var land := _world.support_height(cand, top + 1.0)
		if land - top <= 0.7 and not _world.build.body_blocked(cell, land):
			return cand
	return Vector3(from.x, to.y, from.z)


func _update_breath(delta: float, top: float) -> void:
	var before := breath
	var under := top > -INF and global_position.y + EYES < top - 0.05
	if under and _caves and is_instance_valid(_caves) and _caves.in_air_pocket(global_position):
		under = false
	if under and is_alive():
		breath = maxf(0.0, breath - delta)
		if breath <= 0.0:
			_drown_timer -= delta
			if _drown_timer <= 0.0:
				_drown_timer = 1.0
				health.take_damage(maxi(1, roundi(health.max_health * 0.08)))
				notify.emit("Tu te noies ! Remonte respirer.")
	else:
		breath = minf(BREATH_MAX, breath + delta * 5.0)
		_drown_timer = 0.0
	if int(before * 4.0) != int(breath * 4.0):
		breath_changed.emit(breath)


func _respawn() -> void:
	swimming = false
	breath = BREATH_MAX
	if _world:
		var home := _world.home_center() + Vector3(0, 0, 3)
		_world.load_area(home)
		global_position = home
	health.revive(1.0)
	# on se réveille au village avec un peu à manger dans le ventre
	hunger = maxf(hunger, 50.0)
	_on_hunger_state()
	visual.set_downed(false)
	_knockback = Vector3.ZERO
	_invulnerable_left = 2.0
	snap_camera()
	notify.emit("Vous vous réveillez au village.")
	Villager.bring_companions(get_tree(), global_position)


func is_dashing() -> bool:
	return _dash_time > 0.0


## Invulnérable pendant la roulade : c'est l'esquive.
func is_invulnerable() -> bool:
	return is_dashing() or super()


func _start_dash(direction: Vector3) -> void:
	_dash_dir = direction.normalized()
	facing = _dash_dir
	_dash_time = stats.dash_duration
	_dash_elapsed = 0.0
	_dash_cooldown_left = stats.dash_cooldown * (1.0 - clampf(talent_bonus("dash_cd"), 0.0, 0.7))
	visual.play_roll(stats.dash_duration)
	spend_hunger(0.5)
	Sound.play("dash", global_position, -4.0)
	dashed.emit()


# ---------------------------------------------------------------- verrouillage de cible

## Manette : LB (garde) maintenu + croix gauche / droite = objet précédent / suivant à poser.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true
	if ui_open or building or not is_alive():
		return
	# Ctrl + chiffre : barre de construction (le chiffre seul reste aux compétences)
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).ctrl_pressed:
		var kc := (event as InputEventKey).physical_keycode
		if kc >= KEY_0 and kc <= KEY_9 and hand:
			hand.select_slot(9 if kc == KEY_0 else kc - KEY_1)
			get_viewport().set_input_as_handled()
			return
	# clic droit avec un objet en main : le poser (comme Minecraft) ; mains nues : la garde
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed and holding_item():
		_place_in_hand()
		_place_repeat = 0.3
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and Input.is_action_pressed("block") \
			and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		hand.cycle(1 if event.button_index == JOY_BUTTON_DPAD_RIGHT else -1)
		get_viewport().set_input_as_handled()
	# LB + croix haut : manger
	elif event is InputEventJoypadButton and event.pressed and Input.is_action_pressed("block") and event.button_index == JOY_BUTTON_DPAD_UP:
		eat()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if ui_open or not is_alive():
		return
	# en construction, seule la touche inventaire reste active côté héros
	if building and not event.is_action_pressed("inventory"):
		return
	for i in TalentTree.SLOTS:
		if event.is_action_pressed("ability_%d" % (i + 1)):
			cast_ability(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("eat"):
		eat()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("potion"):
		drink_potion()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("place_block"):
		_place_in_hand()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hand_toggle"):
		hand.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hotbar_next") or event.is_action_pressed("hotbar_prev"):
		hand.cycle(1 if event.is_action_pressed("hotbar_next") else -1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ability_cast"):
		cast_ability(selected_slot)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ability_next"):
		selected_slot = (selected_slot + 1) % TalentTree.SLOTS
		talents_changed.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		# Pacte : apprivoiser un monstre affaibli
		var fam := get_tree().get_first_node_in_group("familiars_mgr")
		if fam and fam.try_interact(self):
			get_viewport().set_input_as_handled()
			return
		# monter, descendre, embarquer, apprivoiser un cheval, coffre d'île
		var mo := _mounts_node()
		if mo and mo.try_interact(self):
			get_viewport().set_input_as_handled()
			return
		var dm := get_tree().get_first_node_in_group("dungeons")
		if dm and dm.try_interact(self):
			get_viewport().set_input_as_handled()
			return
		var cv := get_tree().get_first_node_in_group("caves")
		if cv and cv.try_interact(self):
			get_viewport().set_input_as_handled()
			return
		var bg := get_tree().get_first_node_in_group("build_grid") as BuildGrid
		if bg and bg.toggle_gate_near(global_position):
			Sound.play("door", global_position)
			get_viewport().set_input_as_handled()
			return
		var eg := get_tree().get_first_node_in_group("endgame")
		if eg and eg.try_interact(self):
			get_viewport().set_input_as_handled()
			return
		var mcv := get_tree().get_first_node_in_group("mountain_caves")
		if mcv and mcv.try_interact(self):
			get_viewport().set_input_as_handled()
			return
		# un coffre du monde (château, épave), un habitant d'une ville ou d'un château
		var wch := WorldChest.nearest(self)
		if wch:
			wch.open(self)
			get_viewport().set_input_as_handled()
			return
		var tf := Townsfolk.nearest(self)
		if tf:
			tf.talk(self)
			get_viewport().set_input_as_handled()
			return
		var s := nearest_stranger()
		if s:
			talk.emit(s)
			get_viewport().set_input_as_handled()
			return
		# un personnage de l'histoire qui a quelque chose à dire
		var sv := nearest_villager()
		var st := get_tree().get_first_node_in_group("story")
		if sv and st and sv.has_meta("story") and st.try_talk(sv):
			get_viewport().set_input_as_handled()
			return
		# un habitant qui a une quête à proposer ou à rendre
		var qv := nearest_villager()
		var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
		if qv and qb and not qb.quest_of(qv).is_empty():
			quest_talk.emit(qv)
			get_viewport().set_input_as_handled()
			return
		# près d'un lit, la nuit : dormir jusqu'au matin
		var grid := get_tree().get_first_node_in_group("build_grid") as BuildGrid
		var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
		if grid and dc and dc.is_night() and grid.furniture_near(global_position, 2.2).has("lit"):
			notify.emit(dc.sleep())
			get_viewport().set_input_as_handled()
			return
		var v := nearest_villager()
		# un atelier (établi, enclume, four...) : son menu d'artisanat
		if v == null:
			var ws := Workshops.station_near(self)
			if ws != "":
				open_workshop.emit(ws)
				get_viewport().set_input_as_handled()
				return
		# F ne sert qu'à agir : l'équipement s'ouvre avec sa propre touche (E)
		if v:
			open_inventory.emit(v)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		open_inventory.emit(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("crafts"):
		var inv := get_tree().get_first_node_in_group("inventory_ui")
		if inv:
			inv.open_tab(self, "Métiers")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill") and not building:
		use_skill()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_view") and not building:
		set_camera_mode(int(cam_mode) + 1)
		get_viewport().set_input_as_handled()
	elif not building and _camera_input(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lock_on"):
		_toggle_lock()
		get_viewport().set_input_as_handled()


func _toggle_lock() -> void:
	if building:
		return
	if lock_target:
		# un nouvel appui passe à la cible suivante, ou relâche s'il n'y en a pas d'autre
		_set_lock(_find_lock_target(lock_target))
	else:
		_set_lock(_find_lock_target(null))


func _find_lock_target(exclude: Combatant) -> Combatant:
	var best: Combatant = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(hostile_group()):
		var c := n as Combatant
		if c == null or c == exclude or not c.is_alive():
			continue
		var to := c.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > lock_range:
			continue
		var ang := absf(Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z)))
		var score := d + ang * 3.0
		if score < best_score:
			best_score = score
			best = c
	return best


func _set_lock(t: Combatant) -> void:
	lock_target = t
	lock_changed.emit(t)


func _update_lock() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.is_alive() \
			or lock_target.global_position.distance_to(global_position) > lock_range * 1.4:
		_set_lock(_find_lock_target(null) if is_instance_valid(lock_target) else null)


func _make_reticle() -> void:
	# cercle de crochets au sol + flèche au-dessus de la cible
	_reticle = Node3D.new()
	_reticle.top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.25)
	mat.no_depth_test = true
	mat.render_priority = 8
	var ring := Node3D.new()
	ring.name = "Ring"
	_reticle.add_child(ring)
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.y = TAU * i / 4.0 + PI / 4.0
		for j in 3:
			var c := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.07, 0.03, 0.07)
			c.mesh = b
			c.material_override = mat
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.position = Vector3(1.0, 0, (j - 1) * 0.1)
			arm.add_child(c)
		ring.add_child(arm)
	var arrow := Node3D.new()
	arrow.name = "Arrow"
	for j in 3:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		var w := 0.2 - j * 0.07
		b.size = Vector3(w, 0.06, w)
		c.mesh = b
		c.material_override = mat
		c.position = Vector3(0, -j * 0.06, 0)
		arrow.add_child(c)
	_reticle.add_child(arrow)
	add_child(_reticle)
	_reticle.visible = false


func _update_reticle(delta: float) -> void:
	_reticle.visible = lock_target != null
	if lock_target == null:
		return
	var s := lock_target.visual.height_scale()
	_reticle.global_position = lock_target.global_position
	var ring := _reticle.get_node("Ring") as Node3D
	ring.position.y = 0.06
	ring.rotation.y += delta * 1.5
	ring.scale = Vector3.ONE * (lock_target.body_radius + 0.35) * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008))
	var arrow := _reticle.get_node("Arrow") as Node3D
	var top := 2.55 * s if not lock_target.visual.is_quadruped() else 1.9 * s
	arrow.position.y = top + 0.08 * sin(Time.get_ticks_msec() * 0.006)


## Décalage de la caméra selon la rotation (yaw), la hauteur (pitch) et le zoom.
func camera_vector(base: Vector3) -> Vector3:
	var dist := base.length() * camera_zoom
	return Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * dist


func _update_orbit_stick(delta: float) -> void:
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rx) > 0.2:
		cam_yaw -= rx * delta * 2.4
	if absf(ry) > 0.2:
		cam_pitch = clamp_pitch(cam_pitch + ry * delta * 1.4)


## Molette : zoom (un objet en main : changer d'objet) ; clic molette maintenu : tourner la caméra (un simple clic : viser la cible).
func _camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_orbiting = true
				_orbit_moved = 0.0
				_orbit_pressed_at = Time.get_ticks_msec()
			else:
				_orbiting = false
				if _orbit_moved < 8.0 and Time.get_ticks_msec() - _orbit_pressed_at < 350:
					_toggle_lock()
			return true
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
				and holding_item() and not mb.ctrl_pressed:
			# un objet en main : la molette change d'objet (Ctrl + molette : zoom)
			hand.cycle(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			return true
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			camera_zoom = clampf(camera_zoom * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.45, 1.8)
			return true
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and cam_mode != CamMode.TOP:
		# 3e et 1re personne : la souris tourne la caméra
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.0032
		cam_pitch = clamp_pitch(cam_pitch + mm.relative.y * 0.0028)
		return true
	elif event is InputEventMouseMotion and _orbiting:
		var mm := event as InputEventMouseMotion
		_orbit_moved += mm.relative.length()
		cam_yaw -= mm.relative.x * 0.008
		cam_pitch = clamp_pitch(cam_pitch + mm.relative.y * 0.006)
		return true
	return false


func _update_camera(delta: float) -> void:
	if cam_mode == CamMode.THIRD:
		_update_camera_third(delta)
		return
	if cam_mode == CamMode.FIRST:
		_animate_viewmodel(delta)
		var eye := global_position + Vector3(0, 1.5 * visual.height_scale(), 0)
		camera.global_position = eye
		var look := -Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
		camera.look_at(eye + look)
		_apply_shake(delta)
		return
	var offset := camera_vector(camera_offset)
	var focus := global_position
	if lock_target and is_instance_valid(lock_target):
		offset = camera_vector(lock_camera_offset)
		focus = global_position.lerp(lock_target.global_position, 0.35)
	var target := focus + offset
	camera.global_position = camera.global_position.lerp(target, clampf(camera_smoothing * delta, 0.0, 1.0))
	camera.look_at(camera.global_position - offset + Vector3(0, 0.8, 0))
	_apply_shake(delta)


## 3e personne : derrière l'épaule du héros, avec du recul. La caméra garde toujours la même distance et
## passe au travers des obstacles (murs, blocs, arbres, relief) au lieu de sauter devant eux : plus d'à-coups.
## Ce qui la sépare du héros s'efface (blocs, décors et relief, voir `see_from` / `see_to`). Elle reste au-dessus
## du sol sous elle, en glissant doucement, pour ne jamais filmer le dessous du monde.
## Souplesse : le point regardé suit le héros avec un peu de retard, surtout en hauteur (marches, sauts,
## atterrissages) ; la caméra est ensuite posée exactement sur son orbite, sans balancement.
func _update_camera_third(delta: float) -> void:
	var head := global_position + Vector3(0, 1.45 * visual.height_scale(), 0)
	var aim_at := head
	if lock_target and is_instance_valid(lock_target):
		aim_at = aim_at.lerp(lock_target.global_position + Vector3(0, 1.0, 0), 0.3)
	if delta >= 1.0 or _cam_focus == Vector3.INF or _cam_focus.distance_to(aim_at) > 8.0:
		_cam_focus = aim_at
	else:
		var flat := Vector2(_cam_focus.x, _cam_focus.z).lerp(Vector2(aim_at.x, aim_at.z), clampf(CAM_FOLLOW * delta, 0.0, 1.0))
		_cam_focus = Vector3(flat.x, lerpf(_cam_focus.y, aim_at.y, clampf(CAM_FOLLOW_Y * delta, 0.0, 1.0)), flat.y)
	var want := THIRD_DISTANCE * camera_zoom
	_cam_dist = want if delta >= 1.0 else lerpf(_cam_dist, want, clampf(6.0 * delta, 0.0, 1.0))
	# la rotation (souris, stick) est lissée un tout petit peu : les à-coups de la souris ne font plus sauter l'image
	if delta >= 1.0:
		_view_yaw = cam_yaw
		_view_pitch = cam_pitch
	else:
		_view_yaw = lerp_angle(_view_yaw, cam_yaw, clampf(CAM_TURN * delta, 0.0, 1.0))
		_view_pitch = lerpf(_view_pitch, cam_pitch, clampf(CAM_TURN * delta, 0.0, 1.0))
	# au-dessus de l'épaule droite : le viseur au centre ne cache pas le héros
	var focus := _cam_focus + Vector3(cos(_view_yaw), 0.0, -sin(_view_yaw)) * 0.75
	var target := focus + Vector3(sin(_view_yaw) * cos(_view_pitch), sin(_view_pitch), cos(_view_yaw) * cos(_view_pitch)) * _cam_dist
	# jamais sous le sol (dehors) : un plancher qui suit le relief en douceur
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator
	if w and global_position.y > WorldGenerator.UNDERGROUND:
		var floor_y := w.terrain_height(w.cell_at(target)) + 0.6
		_cam_floor = floor_y if delta >= 1.0 or _cam_floor == -INF else lerpf(_cam_floor, floor_y, clampf(3.0 * delta, 0.0, 1.0))
		target.y = maxf(target.y, _cam_floor)
	visual.visible = true
	camera.global_position = target
	camera.look_at(focus)
	_apply_shake(delta)


## Direction du héros vers la caméra en 3e personne, pour une hauteur d'angle donnée.
func _third_dir(pitch: float) -> Vector3:
	return Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch))


func _apply_shake(delta: float) -> void:
	if _shake > 0.0:
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.06
		_shake = maxf(_shake - delta * 4.0, 0.0)


# ---------------------------------------------------------------- village, objets

## L'habitant le plus proche à portée (ou null).
## Ce que ferait la touche Parler / utiliser ici (pour l'invite à l'écran) ; "" s'il n'y a rien de particulier.
## Suit l'ordre de l'appui sur E (voir _unhandled_input), en plus léger.
func _on_inventory_changed() -> void:
	var found := Workshops.note_seen(self)
	if not found.is_empty() and is_inside_tree() and get_tree().current_scene != null and Engine.get_process_frames() > 30:
		notify.emit(Workshops.discovery_text(found))
	if not pinned.is_empty():
		pins_changed.emit()


## Épingle (ou désépingle) un objet à fabriquer : sa liste de courses s'affiche à l'écran.
func toggle_pin(item_id: String) -> void:
	if pinned.has(item_id):
		pinned.erase(item_id)
	else:
		pinned.append(item_id)
		while pinned.size() > MAX_PINS:
			pinned.pop_front()
	pins_changed.emit()


func interact_hint() -> String:
	var mo := _mounts_node()
	if mo and mo.is_riding():
		return "Descendre"
	var wch := WorldChest.nearest(self)
	if wch:
		return "Ouvrir le coffre"
	var tf := Townsfolk.nearest(self)
	if tf:
		return "Parler à %s" % tf.display_name if tf.display_name != "" else "Parler"
	var s := nearest_stranger()
	if s:
		return "Parler au voyageur"
	var v := nearest_villager()
	if v:
		var vn: String = str(v.get("villager_name")) if v.get("villager_name") != null else ""
		var st := get_tree().get_first_node_in_group("story")
		if v.has_meta("story") and st:
			return "Parler à %s" % vn
		var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
		if qb and not qb.quest_of(v).is_empty():
			return "Quête de %s" % vn
		return "Fiche de %s (poste, équipement)" % vn
	var grid := get_tree().get_first_node_in_group("build_grid") as BuildGrid
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if grid and dc and dc.is_night() and grid.furniture_near(global_position, 2.2).has("lit"):
		return "Dormir jusqu'au matin"
	var ws := Workshops.station_near(self)
	if ws != "":
		return "Utiliser : " + Workshops.station_name(ws)
	return ""


func holding_item() -> bool:
	return hand != null and hand.selected != ""


func _place_in_hand() -> bool:
	_aim_with_camera()
	if hand.place():
		_vm_swing = 0.7
		return true
	return false


func nearest_villager() -> Node3D:
	var best: Node3D = null
	var best_d := interact_distance
	for v in get_tree().get_nodes_in_group("villagers"):
		var d := (v as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


## Le voyageur le plus proche à portée (ou null).
func nearest_stranger() -> Node3D:
	var best: Node3D = null
	var best_d := interact_distance + 0.6
	for v in get_tree().get_nodes_in_group("strangers"):
		var d := (v as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


func is_near_workbench() -> bool:
	for w in get_tree().get_nodes_in_group("workbench"):
		if (w as Node3D).global_position.distance_to(global_position) < interact_distance + 1.2:
			return true
	return nearby_stations().has("etabli")


## Meubles à proximité (pour l'artisanat : enclume, four, meule...).
func nearby_stations() -> Array:
	var grid := get_tree().get_first_node_in_group("build_grid") as BuildGrid
	var out: Array = grid.furniture_near(global_position, 4.0) if grid else []
	for w in get_tree().get_nodes_in_group("workbench"):
		if (w as Node3D).global_position.distance_to(global_position) < interact_distance + 1.2 and not out.has("etabli"):
			out.append("etabli")
	# « feu » pour cuisiner : le feu de camp du village, ou un four / une forge posés
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if out.has("four") or out.has("four_pain") or out.has("foyer_forge") or out.has("feu_de_camp") \
			or (world and not GameState.bare_start and global_position.distance_to(world.cell_center(world.spawn_cell)) < 4.5):
		out.append("feu")
	return out


func _kingdom_bonus(key: String) -> float:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var total := float(soul_bonus.get(key, 0.0))
	return total + (k.hero_bonus(key) if k else 0.0)


## Âmes de boss absorbées (région -> bonus). Chaque âme ne compte qu'une fois.
var souls := {}
## Somme des bonus des âmes absorbées (attack, defense, magic, regen, xp).
var soul_bonus := {}


## Absorbe l'âme d'un boss vaincu : bonus permanent.
func absorb_soul(id: String, bonus: Dictionary) -> void:
	if souls.has(id):
		return
	souls[id] = bonus
	for k in bonus:
		soul_bonus[k] = float(soul_bonus.get(k, 0.0)) + float(bonus[k])
	VoxelBurst.spawn(self, global_position + Vector3(0, 1.0, 0), Color(0.6, 0.9, 1.0), 60, 5.0, 0.1, 1.2, "sphere", -2.0)
	refresh_stats()
	talents_changed.emit()


## Appelé par un objet au sol quand le joueur marche dessus.
func try_pickup(pickup: ItemPickup) -> void:
	if pickup.item == null or pickup.is_taken():
		return
	var item := pickup.item
	pickup.take()
	if auto_equip and item.is_equipment() and equipment.get_item(item.slot) == null \
			and not (item.slot == ItemData.Slot.OFF_HAND and equipment.get_item(ItemData.Slot.MAIN_HAND) \
			and equipment.get_item(ItemData.Slot.MAIN_HAND).two_handed):
		for old in equipment.equip(item):
			inventory.add(old)
		notify.emit("%s équipé(e) !" % item.display_name)
	else:
		inventory.add(item, pickup.count)
		notify.emit("+%d %s" % [pickup.count, item.display_name])
	Sound.play("pickup", Vector3.INF, -8.0, 0.05)


## Attaque, défense et magie totales (race + équipement).
func total_stats() -> Dictionary:
	var r := race if race else RaceData.new()
	return {
		"health": health.current,
		"max_health": health.max_health,
		"attack": attack_power(),
		"defense": defense_power(),
		"magic": magic_power(),
		"speed": r.speed_multiplier * equipment.speed_multiplier(),
	}


func display_title() -> String:
	var n := profile.hero_name if profile else "Vous"
	return "%s (%s, niv. %d)" % [n, race.display_name if race else "?", level]
