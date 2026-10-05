class_name PlaceLabel
extends Label3D
## Étiquette flottante d'un lieu (obélisque, donjon, hameau, taverne...) qui s'efface au loin :
## pleinement lisible tant que son texte mesure au moins FULL_PX pixels de haut à l'écran, puis fondu
## jusqu'à MIN_PX, en dessous de quoi elle est cachée (et jamais au-delà de `fade_end` mètres).
## Évite les petits textes illisibles qui flottent à mi-distance ou à l'horizon.
## (Fondu fait à la main : le rendu Compatibility ne gère pas le fondu des visibility ranges.)
## Les autres Label3D du jeu suivent la même règle, sans fondu (autoload LabelLod).

## Hauteur de ligne (en pixels, écran de 720 de haut) sous laquelle une étiquette est cachée.
const MIN_PX := 11.0
## Hauteur à partir de laquelle une étiquette de lieu est pleinement opaque.
const FULL_PX := 15.0
const REF_HEIGHT := 720.0
const REF_FOV := 55.0

@export var fade_start := 28.0
@export var fade_end := 42.0

var _faded := false


## Distance (m) à laquelle une ligne de l'étiquette `l` mesure `px` pixels de haut à l'écran.
static func distance_for(l: Label3D, px: float) -> float:
	var h := float(l.font_size) * l.pixel_size
	return h * REF_HEIGHT / (2.0 * tan(deg_to_rad(REF_FOV) * 0.5) * px)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(global_position)
	var end := minf(fade_end, distance_for(self, MIN_PX))
	var start := minf(fade_start, distance_for(self, FULL_PX))
	var a := clampf((end - d) / maxf(end - start, 0.01), 0.0, 1.0)
	if a <= 0.0:
		if visible:
			visible = false
			_faded = true
		return
	if _faded:
		visible = true
		_faded = false
	modulate.a = a
	outline_modulate.a = a
