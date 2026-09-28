# Jeu de gestion

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer.

## Commandes
- ZQSD ou flèches : se déplacer
- Espace : roulade
- R : changer de race (pour tester les 15 races)
- N : nouveau monde

## Ce que tu peux modifier sans code
- `data/races/*.tres` : les 15 races (nom, description, stats, animations). Duplique un fichier pour créer une race.
- `data/player/player_stats.tres` : vitesse, roulade, vie du joueur.
- `scenes/player/player.tscn` > propriété **Race** : la race du joueur au démarrage.
- `scenes/main.tscn` > nœud **World** : taille du monde, niveaux d'eau/sable/roche, forêts, village de départ (scènes des huttes, feu, habitants, liste des races des habitants, nombre d'habitants).
  - Bouton **Générer un aperçu** : voir le terrain dans l'éditeur. **Effacer l'aperçu** avant d'enregistrer.
- `scenes/main.tscn` > nœud **Ambiance** : couleur de l'éclairage global (plus sombre = plus nocturne).
- `scenes/props/campfire.tscn` : lumière du feu (couleur, puissance, vacillement).
- `scenes/npc/villager.tscn` : vitesse et rayon de promenade des habitants.

## Graphismes
- Décor : tuiles 32 px. `assets/tiles/terrain_dual.png` contient les transitions arrondies entre terrains (grille décalée d'une demi-tuile, calculée par le générateur).
- Personnages : `assets/characters/races/<race>_sheet.png` (lignes : face, dos, profil ; colonnes : repos + 4 images de marche), affichés en pixels x2.
