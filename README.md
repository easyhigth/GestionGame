# L'Éveil du Royaume

(Nom provisoire : il se change dans Projet > Paramètres du projet > Application > Nom, et dans `scenes/ui/title_screen.gd`.)

Un RPG d'action en monde ouvert en 3D voxel, avec la construction d'un royaume : on réincarne un héros (22 races, 13 classes, 14 métiers, 151 compétences uniques), on explore huit régions, on bâtit bloc par bloc, on recrute des habitants de toutes les races, on affronte des boss de donjons et on traverse une histoire de 16 actes. Moteur : Godot 4.7.

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer. Le jeu commence par l'écran titre (`scenes/ui/title_screen.tscn`) : Continuer, Nouvelle partie (création du héros), Charger, Options, Quitter. `scenes/main.tscn` se lance aussi seul (F6) avec un héros par défaut.

## La documentation
- **[Guide du joueur](docs/joueur.md)** : touches (clavier, souris, manette), création du héros, combat, récolte, construction, royaume, histoire, donjons, accessibilité, langues...
- **[Documentation développeur](docs/dev.md)** : ce qu'on peut modifier sans code (`data/*.tres`), outils de génération (`tools/`), optimisations, tests automatiques et feuille de route.

## Ce qu'il faut savoir tout de suite
- **Échap → Commandes** : le plan du clavier et toutes les touches (personnalisables). **F1** : aide-mémoire à l'écran.
- On commence **à mains nues et seul** : du bois, un établi, des outils, un abri, un feu de camp... puis les voyageurs arrivent.
- Options : difficulté, qualité graphique, **langue (français / anglais)**, **filtre pour daltoniens**, **mouvement réduit**, taille de l'interface.
- Tests : `GODOT=/chemin/vers/godot tests/run_tests.sh` (voir [docs/dev.md](docs/dev.md#tests-automatiques)). GitHub les lance à chaque pull request.
