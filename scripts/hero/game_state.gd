extends Node
## Autoload « GameState » : ce qui passe d'une scène à l'autre (le héros créé).

## Le héros créé dans l'écran de création (null = héros par défaut).
var hero: HeroProfile
## Graine du prochain monde (-1 : au hasard). Sert aux tests pour toujours générer le même monde.
var world_seed := -1
## Nouvelle partie lancée depuis la création du héros : l'introduction se joue une fois.
var play_intro := false
