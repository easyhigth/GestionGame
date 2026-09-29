# Jeu de gestion

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer.

## Commandes
- ZQSD ou flèches : se déplacer
- Espace : roulade
- R : changer de race (pour tester les 22 races)
- N : nouveau monde

## Ce que tu peux modifier sans code
- `data/races/*.tres` : les 22 races (nom, description, stats, modèle 3D du joueur, modèles des habitants). Duplique un fichier pour créer une race.
- `data/player/player_stats.tres` : vitesse (en m/s), roulade, vie du joueur.
- `scenes/player/player.tscn` > propriété **Race** : la race du joueur au démarrage. **Camera Offset** : position de la caméra par rapport au joueur.
- `scenes/main.tscn` > nœud **World** : taille du monde, niveaux d'eau/sable/roche, relief 3D (hauteur des marches), couleurs du sol, forêts et modèles des décors, village de départ (scènes des huttes, feu, habitants, liste des races des habitants, nombre d'habitants).
  - Bouton **Générer un aperçu** : voir le terrain dans l'éditeur. **Effacer l'aperçu** avant d'enregistrer.
- `scenes/main.tscn` > nœud **Ambiance** (WorldEnvironment) : couleur du ciel et de la lumière ambiante. Nœud **Soleil** : direction, couleur et puissance du soleil (plus sombre = plus nocturne).
- `scenes/props/campfire.tscn` : lumière du feu (couleur, puissance, vacillement).
- `scenes/npc/villager.tscn` : vitesse et rayon de promenade des habitants (en mètres).

## Graphismes (3D voxel)
- 1 case du monde = 1 mètre. Le sol est fait de colonnes de blocs en terrasses, avec le même grain que les personnages (`assets/environment/voxel_grain.png`).
- Personnages : `assets/characters/models/<race>_<métier>.glb` (métiers : forgeron, marchand, garde, mage ; `_v2`, `_v3` = autres palettes) et `models/base/` (versions nues). Le joueur utilise le modèle « garde », les habitants un modèle au hasard parmi les autres.
- Animation : `scripts/voxel_character.gd` balance bras et jambes en marchant, fait respirer au repos et gère la roulade.
- Décors : `assets/environment/models/*.glb` (chênes, sapins, buissons, rochers, fleurs, cabane, feu de camp, tonneau, caisse).
- Outils (Python 3, sans dépendance) dans `tools/` :
  - `voxel_character_generator.py` : régénère ou crée des personnages (voir `PROMPT_NOUVELLE_RACE.md`).
  - `voxel_props_generator.py` : régénère les décors (`python voxel_props_generator.py`).
