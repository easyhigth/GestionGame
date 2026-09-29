# Prompt à copier-coller pour créer une nouvelle race

1. Ouvre une nouvelle conversation avec Claude (avec l'exécution de code activée).
2. Joins le fichier `tools/voxel_character_generator.py`.
3. Colle le prompt ci-dessous en remplaçant seulement `[NOM DE LA RACE]`
   (tu peux ajouter une courte description après le tiret, c'est optionnel).

---

Je joins mon générateur Python `voxel_character_generator.py` (personnages voxel adultes pour Godot 4, export .glb).

Ajoute une NOUVELLE RACE : [NOM DE LA RACE]

Respecte exactement le style existant, sans le modifier :
- Voxel sculpté, proportions adultes (pas chibi), uniquement des boîtes (aucune sphère ni forme arrondie), pas de contours noirs, couleurs unies avec le grain de bruit existant.
- Échelle : 1 unité = 1 voxel = 5 cm. Hauteur entre 24 et 40 unités selon la race.
- Corps construit en étages (hanches, taille, poitrine, épaules) avec jambes et bras articulés (genou, coude, poignet). Tête avec crâne, mâchoire, arcades sourcilières, joues, nez et yeux en relief.
- Silhouette unique pour la race (proportions, posture, carrure) plus 8 à 15 détails en relief posés en blocs (oreilles, cornes, crocs, fourrure, écailles, pointes, bijoux, cicatrices, os...). Les détails doivent rester cohérents avec les autres races.
- Les 4 métiers (forgeron, marchand, garde, mage) sont habillés par la fonction `dress()` existante. Ne la modifie pas : ajuste seulement les dimensions et les détails propres à la race. Si un accessoire flotte ou traverse le corps, corrige le placement pour cette race.
- Palettes variées : ajoute les listes de couleurs de peau (SK), d'yeux (EYE) et de cheveux (HAIR, seulement si la race a des cheveux) propres à la race, avec 5 teintes de peau différentes.
- Noms de nœuds inchangés : Root, Torso, Head, ArmL, ArmR, HandL, HandR, LegL, LegR.

Livrables :
1. La fonction de la race complète et les entrées ajoutées aux tables, avec la race ajoutée à `RACES` et `RACE_ORDER`.
2. Génère les 4 fichiers .glb de la race (un par métier) et 3 variantes de palette par modèle.
3. Vérifie le résultat en le chargeant (dimensions, nombre de nœuds) et montre-moi un aperçu.
4. Donne-moi un zip prêt à glisser dans mon projet Godot, avec le générateur mis à jour.

Race : [NOM DE LA RACE] — description libre (optionnel) : [ex. petit, ventru, peau bleue, quatre bras]
