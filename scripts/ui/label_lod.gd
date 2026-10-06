extends Node
## Cache les étiquettes 3D (noms, bulles, panneaux...) dès qu'elles deviendraient trop petites à l'écran
## pour être lues : au lieu de minuscules noms qui flottent à mi-distance, rien. Chaque Label3D ajouté
## au jeu reçoit une distance d'affichage (visibility_range_end) calculée d'après la taille de son
## texte (font_size × pixel_size). Les PlaceLabel gèrent leur propre fondu avec la même règle.
## Toutes les étiquettes 3D vivent aussi sur leur propre couche de rendu, que la caméra du jeu cesse
## d'afficher tant qu'un menu est ouvert (sac, royaume, carte, journal...) : plus de noms par-dessus.

## Couche de rendu (numéro de bit) des étiquettes 3D.
const LAYER_BIT := 19


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := get_tree().get_first_node_in_group("player")
		cam.set_cull_mask_value(LAYER_BIT + 1, not (p and p.get("ui_open")))


func _on_node_added(n: Node) -> void:
	if n is Label3D:
		(n as Label3D).layers = 1 << LAYER_BIT
	if n is Label3D and not n is PlaceLabel:
		# les réglages (pixel_size...) sont souvent posés juste après l'ajout : on attend la fin de l'image
		_fit.call_deferred(n)


func _fit(l: Label3D) -> void:
	if not is_instance_valid(l) or l.visibility_range_end > 0.0:
		return
	l.visibility_range_end = PlaceLabel.distance_for(l, PlaceLabel.MIN_PX)

