class_name HeroProfile
extends Resource
## Le héros créé par le joueur : nom, race, apparence, classe et métier.

const HERO_DIR := "res://assets/characters/hero/"

@export var hero_name: String = "Héros"
@export var race: RaceData
## Style de la race (coiffure, cornes, espèce, élément... voir hero_palettes.json).
@export var style: int = 0
@export var beard: bool = false
@export var skin_color: Color = Color("f2c9a5")
@export var hair_color: Color = Color("6b4423")
@export var eye_color: Color = Color("2a5a8a")
## Taille (1 = normale) et carrure (largeur des épaules et du corps).
@export_range(0.85, 1.15, 0.01) var height: float = 1.0
@export_range(0.85, 1.2, 0.01) var build: float = 1.0
@export var hero_class: ClassData
@export var job: JobData


## Modèle 3D du héros (race + style + barbe).
func model() -> PackedScene:
	if race == null:
		return null
	var path := HERO_DIR + "%s_s%d%s.glb" % [race.model_id, style, "_beard" if beard else ""]
	if not ResourceLoader.exists(path):
		path = HERO_DIR + "%s_s0.glb" % race.model_id
	return load(path)


## Choisit les couleurs par défaut de la race (première couleur de chaque palette).
func reset_colors() -> void:
	var pal := HeroProfile.palette(race)
	if pal.is_empty():
		return
	skin_color = Color(pal["skin"][0])
	hair_color = Color(pal["hair"][0])
	eye_color = Color(pal["eye"][0])
	style = 0
	beard = false


static var _palettes := {}


## Couleurs proposées et noms des styles pour une race (voir hero_palettes.json).
static func palette(r: RaceData) -> Dictionary:
	if _palettes.is_empty():
		var f := FileAccess.open(HERO_DIR + "hero_palettes.json", FileAccess.READ)
		if f:
			_palettes = JSON.parse_string(f.get_as_text())
	return _palettes.get(r.model_id, {}) if r else {}
