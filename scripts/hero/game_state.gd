extends Node
## Autoload « GameState » : ce qui passe d'une scène à l'autre (le héros créé).

## Le héros créé dans l'écran de création (null = héros par défaut).
var hero: HeroProfile
## Graine du prochain monde (-1 : au hasard). Sert aux tests pour toujours générer le même monde.
var world_seed := -1
## Nouvelle partie lancée depuis la création du héros : l'introduction se joue une fois.
var play_intro := false

## Départ à mains nues, façon Minecraft : ni arme, ni armure, ni ressources, ni meubles au campement ;
## seulement le héros, le feu et ses habitants (sans équipement). Les tests gardent l'ancien départ
## (GG_CLASSIC_START=1), qui donne l'équipement de la classe, les blocs du fondateur et les meubles du camp.
var bare_start := OS.get_environment("GG_CLASSIC_START") == ""
