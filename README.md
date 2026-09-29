# Jeu de gestion

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer.

## Commandes
- ZQSD ou flèches : se déplacer
- Espace : roulade (esquive : invulnérable pendant la roulade)
- Clic gauche / J (maintenu) : frapper avec son arme, ou lancer un sort avec un bâton de mage
- I (ou Tab) : inventaire, équipement et artisanat
- E près d'un habitant : ouvrir son équipement pour lui donner des armes et armures
- R : changer de race (pour tester les 22 races)
- N : nouveau monde

## Ce que tu peux modifier sans code
- `data/races/*.tres` : les 22 races (nom, description, stats, modèle 3D nu du joueur, modèles des habitants, équipements de la race). Duplique un fichier pour créer une race.
- `data/items/*.tres` : les 28 objets (matériaux, armes, boucliers, casques, armures, brassards, jambières, capes) : nom, description, emplacement, rareté, bonus d'attaque / défense / magie / vitesse.
- `data/enemies/*.tres` : les 6 monstres (loup, loup alpha, sanglier, gobelin pillard, squelette, orc brutal) : modèle, équipement porté, vie, attaque, défense, vitesse, distance de repérage, portée et durée de leurs coups, butin et chances de le lâcher.
- `data/recipes/*.tres` : les 23 recettes d'artisanat (objet fabriqué, ingrédients et quantités, établi obligatoire ou non).
- `data/player/player_stats.tres` : vitesse (en m/s), roulade, vie du joueur.
- `scenes/player/player.tscn` > propriété **Race** : la race du joueur au démarrage. **Camera Offset** : position de la caméra par rapport au joueur.
- `scenes/main.tscn` > nœud **World** : taille du monde, niveaux d'eau/sable/roche, relief 3D (hauteur des marches), couleurs du sol, forêts et modèles des décors, village de départ (scènes des huttes, feu, habitants, liste des races des habitants, nombre d'habitants).
  - Bouton **Générer un aperçu** : voir le terrain dans l'éditeur. **Effacer l'aperçu** avant d'enregistrer.
- `scenes/main.tscn` > nœud **Ambiance** (WorldEnvironment) : couleur du ciel et de la lumière ambiante. Nœud **Soleil** : direction, couleur et puissance du soleil (plus sombre = plus nocturne).
- `scenes/props/campfire.tscn` : lumière du feu (couleur, puissance, vacillement).
- `scenes/npc/villager.tscn` : vitesse et rayon de promenade des habitants (en mètres), distance à laquelle ils repèrent un équipement au sol (**Loot Radius**).
- `scenes/main.tscn` > nœud **World** > groupe **Monstres** : nombre de camps, distance au village, monstres des forêts / plaines / roches et monstres dangereux (loin du village).
- `scenes/player/player.tscn` > nœud **Health** : régénération de la vie ; propriété **Respawn Delay** du joueur. `scenes/npc/villager.tscn` : distance d'alerte, rayon de défense et durée du K.O. des habitants.
- `scenes/main.tscn` > nœud **World** > groupe **Objets à ramasser** : objets posés autour du feu au départ, équipements rares dans la nature, fréquence des matériaux (bois, pierre, minerai de fer, cuir, fibre).

## Équipement et artisanat
- Les personnages sont **nus** au départ (modèles `models/base/`) ; l'équipement s'affiche par-dessus et suit les mouvements du corps.
- 7 emplacements : tête, torse, bras, jambes, arme, bouclier, dos. Une arme à deux mains retire le bouclier.
- **Ramasser** : marcher sur un objet au sol (anneau coloré = rareté). S'il reste un emplacement vide, l'objet est équipé tout de suite, sinon il va dans le sac.
- **Habitants** : ils commencent avec une partie de la tenue d'un métier (garde, mage, guerrier...), vont chercher les armes et armures meilleures que les leurs qui traînent près d'eux et reposent l'ancienne au sol. Touche E près d'un habitant pour l'équiper avec le contenu de ton sac.
- **Artisanat** (fenêtre I) : le bois, la pierre, le cuir et la fibre se ramassent dans la nature ; le minerai de fer se trouve sur la roche et se fond en lingots à l'**établi** du village. Les objets en fer demandent d'être près de l'établi.

## Combat
- **Dégâts** = attaque × 40 / (40 + défense), ±15 % de hasard. L'attaque vient de la force de la race et de l'arme, la défense des armures, la magie de la race et des objets de mage.
- **Armes** : chacune a sa portée et sa vitesse (dague rapide, lance longue, marteau lent qui repousse fort). Le **bâton de mage** lance un sort à distance dont les dégâts dépendent de la magie. Sans arme, on se bat à mains nues (faible).
- **Esquive** : la roulade rend invulnérable. Les monstres **clignotent de leur couleur** juste avant de frapper : c'est le moment de rouler.
- **Monstres** : ils vivent en camps éloignés du village (loups et sangliers en forêt, gobelins dans les plaines, squelettes dans la roche, orcs et loups alpha loin du village). Ils poursuivent ceux qui s'approchent, abandonnent s'ils s'éloignent trop de leur camp, et lâchent du butin (cuir, minerai, lingots, parfois une arme ou une armure). Un camp vidé se repeuple au bout de 2 minutes si le joueur est loin.
- **Habitants** : armés, ils défendent le village ; sans arme ils s'enfuient. À 0 PV ils tombent K.O. puis se relèvent 20 s plus tard.
- **Joueur** : la vie remonte doucement hors combat. À 0 PV, il se réveille au village au bout de quelques secondes.

## Graphismes (3D voxel)
- 1 case du monde = 1 mètre. Le sol est fait de colonnes de blocs en terrasses, avec le même grain que les personnages (`assets/environment/voxel_grain.png`).
- Personnages : `assets/characters/models/base/<race>_base.glb` (versions nues, `_v2`, `_v3` = autres palettes) ; les habitants tirent une palette au hasard. Les modèles avec métier (`models/<race>_<métier>.glb`) restent disponibles mais ne sont plus utilisés.
- Équipement : `assets/equipment/<race>_equipment.glb` contient les 22 pièces taillées aux mesures de chaque race ; `materials.glb` contient les matériaux posés au sol.
- Animation : `scripts/voxel_character.gd` balance bras et jambes en marchant, fait respirer au repos et gère la roulade.
- Décors : `assets/environment/models/*.glb` (chênes, sapins, buissons, rochers, fleurs, cabane, feu de camp, tonneau, caisse).
- Outils (Python 3, sans dépendance) dans `tools/` :
  - `voxel_character_generator.py` : régénère ou crée des personnages (voir `PROMPT_NOUVELLE_RACE.md`).
  - `voxel_props_generator.py` : régénère les décors (`python voxel_props_generator.py`).
  - `voxel_creature_generator.py` : régénère les créatures (loup, loup alpha, sanglier) dans `assets/characters/creatures/`.
  - `voxel_equipment_generator.py` : régénère les équipements de toutes les races (`python voxel_equipment_generator.py`). Pour ajouter une pièce : écris sa fonction, ajoute-la à `ITEMS`, relance le script, puis crée son fichier dans `data/items/` avec le même `id`.
