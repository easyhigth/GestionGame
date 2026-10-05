class_name PlaceLabel
extends Label3D
## Étiquette flottante d'un lieu (obélisque, donjon, hameau, taverne...) qui s'efface au loin :
## pleinement lisible jusqu'à `fade_start` mètres de la caméra, puis fondu jusqu'à `fade_end`,
## au-delà de quoi elle est cachée. Évite les petits textes illisibles qui flottent à l'horizon.
## (Fondu fait à la main : le rendu Compatibility ne gère pas le fondu des visibility ranges.)

@export var fade_start := 28.0
@export var fade_end := 42.0

var _faded := false


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(global_position)
	var a := clampf((fade_end - d) / maxf(fade_end - fade_start, 0.01), 0.0, 1.0)
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
