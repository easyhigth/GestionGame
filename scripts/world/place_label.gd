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
## Haut de l'écran réservé au HUD (part de la hauteur) : l'étiquette descend pour rester dessous.
const TOP_MARGIN := 0.12
## De combien (m) l'étiquette peut descendre au plus pour rester sous le haut de l'écran.
@export var max_drop := 3.0

var _faded := false


## Distance (m) à laquelle une ligne de l'étiquette `l` mesure `px` pixels de haut à l'écran.
static func distance_for(l: Label3D, px: float) -> float:
	var h := float(l.font_size) * l.pixel_size
	return h * REF_HEIGHT / (2.0 * tan(deg_to_rad(REF_FOV) * 0.5) * px)


## Distances (m) où le fondu commence (x) et où l'étiquette est cachée (y), selon sa taille à l'écran.
func fade_range() -> Vector2:
	return Vector2(minf(fade_start, distance_for(self, FULL_PX)), minf(fade_end, distance_for(self, MIN_PX)))


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	offset.y = 0.0
	var d := cam.global_position.distance_to(global_position)
	var r := fade_range()
	var a := clampf((r.y - d) / maxf(r.y - r.x, 0.01), 0.0, 1.0)
	if a > 0.0:
		a *= _keep_on_screen(cam)
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


## Descend l'étiquette (décalage `offset`, face à la caméra) pour que son texte reste sous la bande du HUD
## en haut de l'écran, au plus de `max_drop` mètres ; ce qui dépasse encore s'efface.
## Renvoie l'opacité à appliquer (1 : entièrement sous la bande).
func _keep_on_screen(cam: Camera3D) -> float:
	if cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return 1.0
	var vh := get_viewport().get_visible_rect().size.y
	var up := cam.global_basis.y
	var line := float(font_size) * pixel_size * 1.2
	var top := global_position + up * line * float(text.count("\n") + 1) * 0.5
	if cam.is_position_behind(top):
		return 1.0
	var limit := vh * TOP_MARGIN
	var over := limit - cam.unproject_position(top).y
	if over <= 0.0:
		return 1.0
	# taille d'un pixel (m) à la profondeur de l'étiquette
	var depth := -(cam.global_transform.affine_inverse() * global_position).z
	var px := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / vh
	var drop := minf(over * px, max_drop)
	offset.y = -drop / pixel_size
	var left := over - drop / px
	return clampf(1.0 - left / (line / px), 0.0, 1.0)
