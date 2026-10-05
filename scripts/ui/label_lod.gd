extends Node
## Cache les étiquettes 3D (noms, bulles, panneaux...) dès qu'elles deviendraient trop petites à l'écran
## pour être lues : au lieu de minuscules noms qui flottent à mi-distance, rien. Chaque Label3D ajouté
## au jeu reçoit une distance d'affichage (visibility_range_end) calculée d'après la taille de son
## texte (font_size × pixel_size). Les PlaceLabel gèrent leur propre fondu avec la même règle.


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Label3D and not n is PlaceLabel:
		# les réglages (pixel_size...) sont souvent posés juste après l'ajout : on attend la fin de l'image
		_fit.call_deferred(n)


func _fit(l: Label3D) -> void:
	if not is_instance_valid(l) or l.visibility_range_end > 0.0:
		return
	l.visibility_range_end = PlaceLabel.distance_for(l, PlaceLabel.MIN_PX)

