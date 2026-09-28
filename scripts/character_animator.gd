class_name CharacterAnimator
extends RefCounted
## Choisit l'animation (idle / walk) et la direction (down / up / side) d'un personnage.


static func update(sprite: AnimatedSprite2D, facing: Vector2, velocity: Vector2) -> void:
	var dir_name: String
	if absf(facing.x) > absf(facing.y):
		dir_name = "side"
		# la vue de profil des planches regarde vers la gauche
		sprite.flip_h = facing.x > 0.0
	else:
		dir_name = "down" if facing.y > 0.0 else "up"
		sprite.flip_h = false
	var anim := ("walk_" if velocity.length() > 5.0 else "idle_") + dir_name
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
