#!/usr/bin/env python3
"""
Base des compétences uniques du héros -> un fichier .tres par compétence dans data/skills/.

Chaque compétence a 3 rangs (noms différents) : Rang I dès le début, Rang II au niveau 6,
Rang III « ultime » au niveau 12. Elle combine :
  - des effets PASSIFS (bonus permanents et déclencheurs), multipliés à chaque rang ;
  - un effet ACTIF (touche Q / RB) avec un temps de recharge.

Effets passifs (valeur au rang I) :
  atk_pct, mag_pct, hp_pct, spd_pct, aspd_pct, cdr_pct (recharge plus rapide) : pourcentages (0.1 = +10 %)
  def_flat, regen (PV/s), crit (chance 0-1), crit_mult (+ dégâts critiques), lifesteal (part des dégâts rendue en vie)
  loot, xp (bonus de butin / d'expérience), thorns (part des dégâts renvoyée), kill_heal (PV par ennemi vaincu)
  absorb (chance par ennemi vaincu de gagner +1 attaque, magie ou 3 PV max pour toujours)
  burn (chance de brûler à chaque coup), stun (chance d'étourdir), slow (chance de ralentir)
  berserk (bonus de dégâts sous 35 % de vie), last_stand (survit à un coup mortel, 1 fois / 60 s)
  execute (bonus de dégâts contre les ennemis sous 30 % de vie), poise (dégâts d'équilibre en plus)
  dodge (esquive parfaite plus facile, secondes), parry (parade plus facile, secondes)
Effets actifs : nova, volley, dash, heal, buff, barrier, stun, vortex, cone, drain, meteor, dot, fear,
  execute, blink, aura, slow_field (voir scripts/hero/hero_skill.gd).

Usage :
    python skills_database.py --out ../data/skills
"""
import argparse, os

SKILLS = []


def S(sid, names, cat, color, desc, passive, active, params, cd):
    SKILLS.append(dict(id=sid, names=names, cat=cat, color=color, desc=desc, passive=passive,
                       active=active, params=params, cd=cd))


# ---------------------------------------------------------------- Péchés (inspirés des grands péchés)
S('vorace', ['Vorace', 'Dévoreur', 'Seigneur de la Faim'], 'Péché', 'b04aff',
  "Tout ce qui tombe devant toi nourrit ton âme : chaque ennemi vaincu peut te rendre plus fort pour toujours.",
  {'absorb': 0.25, 'kill_heal': 4}, 'vortex', {'radius': 4.5, 'dmg': 1.3}, 14)
S('colere', ['Colère', 'Fureur', 'Courroux Divin'], 'Péché', 'ff3a2a',
  "Plus tu es blessé, plus tu frappes fort. Libère ta rage en une explosion de flammes.",
  {'berserk': 0.35, 'atk_pct': 0.05}, 'nova', {'radius': 3.5, 'dmg': 1.8, 'burn': 0.3}, 12)
S('envie', ['Envie', 'Convoitise', 'Usurpateur'], 'Péché', '3aff8a',
  "Tu voles la force de ceux que tu frappes.",
  {'lifesteal': 0.08, 'absorb': 0.08}, 'drain', {'radius': 4.0, 'dmg': 1.0, 'ratio': 0.6}, 12)
S('avarice', ['Avarice', 'Cupidité', 'Roi des Trésors'], 'Péché', 'ffd23a',
  "Rien ne t'échappe : les monstres lâchent bien plus de butin.",
  {'loot': 0.5, 'xp': 0.1}, 'buff', {'crit': 0.3, 'dur': 8}, 20)
S('paresse', ['Paresse', 'Torpeur', 'Sommeil Éternel'], 'Péché', '8a8aff',
  "Pourquoi se presser ? Tu ralentis tout ce qui t'entoure.",
  {'regen': 2.0, 'slow': 0.2}, 'slow_field', {'radius': 5.0, 'factor': 0.35, 'dur': 5, 'dps': 0.2}, 16)
S('orgueil', ['Orgueil', 'Arrogance', 'Souverain Absolu'], 'Péché', 'f0e0ff',
  "Ta seule présence écrase les faibles : ils perdent l'équilibre et tremblent.",
  {'poise': 0.4, 'crit_mult': 0.3}, 'fear', {'radius': 6.0, 'dur': 4}, 18)
S('luxure', ['Charme', 'Envoûtement', 'Reine des Cœurs'], 'Péché', 'ff6ac8',
  "Ton charme trouble l'esprit des ennemis, qui s'arrêtent, fascinés.",
  {'stun': 0.06, 'mag_pct': 0.1}, 'stun', {'radius': 4.5, 'dur': 2.5}, 15)

# ---------------------------------------------------------------- Vertus
S('justice', ['Justice', 'Jugement', 'Arbitre Céleste'], 'Vertu', 'fff08a',
  "Une lumière frappe les ennemis affaiblis et les achève.",
  {'execute': 0.4, 'def_flat': 2}, 'execute', {'range': 8.0, 'dmg': 2.5, 'threshold': 0.35}, 10)
S('patience', ['Patience', 'Sérénité', 'Éternité'], 'Vertu', 'a0e0ff',
  "Rien ne te presse. Tes parades deviennent presque parfaites.",
  {'parry': 0.12, 'def_flat': 3}, 'barrier', {'dur': 3, 'reduce': 0.7}, 16)
S('charite', ['Charité', 'Bienveillance', 'Grâce Infinie'], 'Vertu', 'ffe0a0',
  "Tu soignes tes blessures et celles des habitants proches.",
  {'regen': 1.5, 'hp_pct': 0.05}, 'heal', {'pct': 0.35, 'allies': 1}, 18)
S('temperance', ['Tempérance', 'Équilibre', 'Harmonie Parfaite'], 'Vertu', 'c0ffc0',
  "Tout est mesuré : tes compétences reviennent plus vite.",
  {'cdr_pct': 0.15, 'regen': 1.0}, 'buff', {'def': 6, 'atk': 0.15, 'dur': 8}, 16)
S('diligence', ['Diligence', 'Zèle', 'Infatigable'], 'Vertu', 'ffc070',
  "Tu ne t'arrêtes jamais : coups et déplacements plus rapides.",
  {'aspd_pct': 0.1, 'spd_pct': 0.05}, 'buff', {'aspd': 0.35, 'spd': 0.2, 'dur': 6}, 14)
S('humilite', ['Humilité', 'Modestie', 'Cœur Pur'], 'Vertu', 'e0e0e0',
  "Tu apprends de chaque combat : bien plus d'expérience.",
  {'xp': 0.3, 'hp_pct': 0.05}, 'heal', {'pct': 0.25}, 20)
S('bravoure', ['Bravoure', 'Héroïsme', 'Légende Vivante'], 'Vertu', 'ff9a4a',
  "Face au danger, tu te dépasses. Un cri de guerre te galvanise.",
  {'last_stand': 1, 'atk_pct': 0.05}, 'buff', {'atk': 0.3, 'def': 5, 'dur': 7}, 18)

# ---------------------------------------------------------------- Sagesse
S('erudit', ['Érudit', 'Grand Érudit', 'Oracle Absolu'], 'Sagesse', '7ad0ff',
  "Une voix intérieure analyse tout : tu repères les failles et tes esquives deviennent parfaites.",
  {'crit': 0.08, 'dodge': 0.1, 'xp': 0.1}, 'stun', {'radius': 5.0, 'dur': 1.8}, 14)
S('calcul', ['Calcul', 'Pensée Parallèle', 'Esprit Infini'], 'Sagesse', '9ae0ff',
  "Ton esprit pense à plusieurs choses à la fois : recharges accélérées.",
  {'cdr_pct': 0.25, 'mag_pct': 0.05}, 'volley', {'count': 5, 'dmg': 0.7, 'spread': 0.9}, 8)
S('savant', ['Savant', 'Archimage', 'Grimoire Vivant'], 'Sagesse', '6a8aff',
  "Ta magie est plus puissante que celle de n'importe qui.",
  {'mag_pct': 0.2}, 'volley', {'count': 3, 'dmg': 1.2, 'spread': 0.4}, 7)
S('clairvoyance', ['Clairvoyance', 'Seconde Vue', 'Œil de Dieu'], 'Sagesse', 'd0f0ff',
  "Tu vois les coups arriver avant qu'ils ne partent.",
  {'dodge': 0.15, 'parry': 0.08}, 'blink', {'dist': 5.0, 'dmg': 0.8}, 7)
S('stratege', ['Stratège', 'Tacticien', 'Maître de Guerre'], 'Sagesse', 'c0c8ff',
  "Chaque ennemi a son point faible : tes coups critiques sont dévastateurs.",
  {'crit': 0.1, 'crit_mult': 0.4}, 'buff', {'crit': 0.4, 'dur': 6}, 16)
S('memoire', ['Mémoire', 'Archives', 'Bibliothèque Infinie'], 'Sagesse', 'b0b0ff',
  "Tu retiens tout : expérience accrue et magie renforcée.",
  {'xp': 0.25, 'mag_pct': 0.1}, 'nova', {'radius': 3.0, 'dmg': 1.2}, 10)

# ---------------------------------------------------------------- Éléments
def element(eid, base, cat, col, desc, passive, lines):
    for i, (names, active, params, cd, extra) in enumerate(lines):
        p = dict(passive)
        p.update(extra)
        S('%s_%d' % (eid, i + 1), names, cat, col, desc[i], p, active, params, cd)


element('feu', 'Feu', 'Feu', 'ff6a2a',
        ["Une explosion de flammes jaillit autour de toi, et tes coups brûlent.",
         "Des boules de feu jaillissent de tes mains.",
         "Tu fais pleuvoir le feu du ciel.",
         "Une aura de flammes brûle tout ce qui t'approche."],
        {'burn': 0.15},
        [(['Étincelle', 'Brasier', 'Seigneur des Flammes'], 'nova', {'radius': 3.2, 'dmg': 1.4, 'burn': 0.4}, 10, {}),
         (['Boule de feu', 'Salve ardente', 'Tempête de feu'], 'volley', {'count': 3, 'dmg': 1.1, 'spread': 0.5, 'burn': 0.3}, 7, {'mag_pct': 0.05}),
         (['Pluie de braises', 'Météore', 'Apocalypse'], 'meteor', {'radius': 3.0, 'dmg': 2.2, 'count': 1, 'burn': 0.4}, 14, {}),
         (['Peau ardente', 'Manteau de feu', 'Corps de lave'], 'aura', {'radius': 2.4, 'dps': 0.35, 'dur': 6}, 16, {'thorns': 0.1})])
element('eau', 'Eau', 'Eau', '3aa0ff',
        ["L'eau te soigne et emporte tes ennemis.",
         "Une vague repousse tout devant toi.",
         "Des lames d'eau tranchantes filent vers l'ennemi.",
         "Un tourbillon aspire les ennemis."],
        {'regen': 1.0},
        [(['Source', 'Fontaine', 'Océan de Vie'], 'heal', {'pct': 0.3}, 16, {'hp_pct': 0.05}),
         (['Vague', 'Raz-de-marée', 'Déluge'], 'cone', {'range': 5.0, 'dmg': 1.2, 'kb': 12, 'angle': 100}, 9, {}),
         (['Lame d\'eau', 'Jet tranchant', 'Coupe-Mers'], 'volley', {'count': 2, 'dmg': 1.4, 'spread': 0.2}, 6, {'crit': 0.05}),
         (['Remous', 'Maelström', 'Abysse'], 'vortex', {'radius': 5.0, 'dmg': 1.0}, 12, {})])
element('glace', 'Glace', 'Glace', 'a0f0ff',
        ["Le froid te suit : tes coups ralentissent.",
         "Une explosion de givre fige les ennemis.",
         "Des pics de glace transpercent l'ennemi.",
         "Une armure de glace te protège."],
        {'slow': 0.2},
        [(['Givre', 'Blizzard', 'Hiver Éternel'], 'slow_field', {'radius': 5.0, 'factor': 0.3, 'dur': 5, 'dps': 0.3}, 14, {}),
         (['Gel', 'Prison de glace', 'Zéro Absolu'], 'stun', {'radius': 4.0, 'dur': 2.5, 'dmg': 0.8}, 14, {}),
         (['Pic de glace', 'Lances de givre', 'Forêt de cristal'], 'volley', {'count': 4, 'dmg': 0.9, 'spread': 0.6}, 7, {}),
         (['Armure de givre', 'Carapace polaire', 'Glacier Vivant'], 'barrier', {'dur': 4, 'reduce': 0.6}, 16, {'def_flat': 3})])
element('vent', 'Vent', 'Vent', 'b0ffd0',
        ["Une bourrasque repousse tout devant toi, et le vent te porte.",
         "Tu te déplaces comme une rafale.",
         "Une tornade t'entoure et tranche tout.",
         "Des lames de vent filent en éventail."],
        {'spd_pct': 0.08},
        [(['Brise', 'Bourrasque', 'Ouragan'], 'cone', {'range': 6.0, 'dmg': 0.9, 'kb': 16, 'angle': 120}, 8, {}),
         (['Rafale', 'Pas du vent', 'Vitesse du Ciel'], 'dash', {'dist': 7.0, 'dmg': 1.3}, 6, {'dodge': 0.05}),
         (['Tourbillon', 'Tornade', 'Œil du Cyclone'], 'aura', {'radius': 2.8, 'dps': 0.45, 'dur': 5}, 14, {}),
         (['Lame de vent', 'Croissants d\'air', 'Tempête de lames'], 'volley', {'count': 5, 'dmg': 0.8, 'spread': 1.1}, 7, {'aspd_pct': 0.05})])
element('foudre', 'Foudre', 'Foudre', 'ffe84a',
        ["La foudre tombe autour de toi et étourdit tes ennemis.",
         "Tu deviens l'éclair et traverses tes ennemis.",
         "Des arcs électriques frappent en chaîne.",
         "Des colonnes de foudre s'abattent du ciel."],
        {'stun': 0.08},
        [(['Décharge', 'Orage', 'Jugement du Tonnerre'], 'nova', {'radius': 4.0, 'dmg': 1.5, 'stun': 1.0}, 12, {}),
         (['Éclair', 'Foudre vivante', 'Dieu du Tonnerre'], 'dash', {'dist': 8.0, 'dmg': 1.6, 'stun': 1.0}, 7, {'spd_pct': 0.05}),
         (['Étincelles', 'Chaîne d\'éclairs', 'Tempête électrique'], 'volley', {'count': 6, 'dmg': 0.6, 'spread': 1.4, 'stun': 0.3}, 8, {}),
         (['Frappe du ciel', 'Colonne de foudre', 'Colère des Cieux'], 'meteor', {'radius': 2.6, 'dmg': 1.8, 'count': 3}, 15, {})])
element('terre', 'Terre', 'Terre', 'b08a5a',
        ["Tu frappes le sol : la terre tremble autour de toi.",
         "Une faille s'ouvre devant toi et projette tes ennemis.",
         "Une peau de pierre te rend presque invincible.",
         "Des rochers tombent sur tes ennemis."],
        {'def_flat': 3, 'hp_pct': 0.05},
        [(['Séisme', 'Tremblement', 'Fracture du Monde'], 'nova', {'radius': 4.5, 'dmg': 1.3, 'stun': 0.6}, 12, {}),
         (['Onde tellurique', 'Faille', 'Cœur de la Terre'], 'cone', {'range': 6.0, 'dmg': 1.5, 'kb': 8, 'angle': 60}, 9, {}),
         (['Peau de pierre', 'Corps de granit', 'Colosse'], 'barrier', {'dur': 5, 'reduce': 0.5}, 18, {'poise': 0.3}),
         (['Chute de pierres', 'Avalanche', 'Pluie de Montagnes'], 'meteor', {'radius': 2.8, 'dmg': 1.6, 'count': 2}, 14, {})])
element('lumiere', 'Lumière', 'Lumière', 'fff6c0',
        ["La lumière te guérit et purifie.",
         "Un éclat aveuglant étourdit tes ennemis.",
         "Des rayons sacrés frappent le mal.",
         "Un bouclier de lumière te protège."],
        {'regen': 1.0, 'mag_pct': 0.05},
        [(['Lueur', 'Rayonnement', 'Soleil Intérieur'], 'heal', {'pct': 0.3, 'allies': 1}, 16, {}),
         (['Éclat', 'Aveuglement', 'Aurore'], 'stun', {'radius': 5.0, 'dur': 2.0}, 14, {}),
         (['Rayon', 'Lances sacrées', 'Jugement Céleste'], 'volley', {'count': 3, 'dmg': 1.3, 'spread': 0.3}, 8, {}),
         (['Halo', 'Égide', 'Sanctuaire'], 'barrier', {'dur': 4, 'reduce': 0.8}, 18, {})])
element('tenebres', 'Ténèbres', 'Ténèbres', '7a3aff',
        ["Les ombres dévorent la vie de tes ennemis.",
         "Tu disparais dans l'ombre et réapparais derrière l'ennemi.",
         "Une sphère d'ombre aspire tout.",
         "Les ténèbres terrorisent ceux qui les voient."],
        {'lifesteal': 0.05},
        [(['Ombre vorace', 'Nuit dévorante', 'Néant'], 'drain', {'radius': 4.0, 'dmg': 1.2, 'ratio': 0.5}, 12, {}),
         (['Pas de l\'ombre', 'Voile noir', 'Marcheur du Vide'], 'blink', {'dist': 6.0, 'dmg': 1.4}, 6, {'crit': 0.05}),
         (['Sphère d\'ombre', 'Trou noir', 'Singularité'], 'vortex', {'radius': 5.5, 'dmg': 1.4}, 14, {}),
         (['Terreur', 'Cauchemar', 'Roi de la Nuit'], 'fear', {'radius': 6.5, 'dur': 4, 'dmg': 0.6}, 16, {})])
element('poison', 'Poison', 'Poison', '8aff3a',
        ["Tes coups empoisonnent.",
         "Un nuage toxique empoisonne tout autour de toi.",
         "Des dards venimeux filent vers l'ennemi."],
        {'burn': 0.12},
        [(['Venin', 'Toxine', 'Peste'], 'buff', {'burn': 0.6, 'dur': 8}, 16, {}),
         (['Miasme', 'Nuée toxique', 'Fléau'], 'dot', {'radius': 4.5, 'dps': 0.35, 'dur': 6}, 12, {}),
         (['Dard', 'Aiguillons', 'Essaim de dards'], 'volley', {'count': 5, 'dmg': 0.6, 'spread': 0.8, 'burn': 0.6}, 7, {})])
element('sang', 'Sang', 'Sang', 'd0203a',
        ["Le sang des ennemis nourrit le tien.",
         "Tu sacrifies de ta vie pour frapper plus fort.",
         "Une explosion de sang draine tout autour de toi."],
        {'lifesteal': 0.1},
        [(['Soif', 'Soif de sang', 'Seigneur Vampire'], 'drain', {'radius': 3.5, 'dmg': 1.0, 'ratio': 0.8}, 12, {}),
         (['Sacrifice', 'Pacte de sang', 'Rituel Écarlate'], 'buff', {'atk': 0.5, 'lifesteal': 0.2, 'dur': 6, 'cost': 0.15}, 14, {}),
         (['Hémorragie', 'Fleur de sang', 'Marée Rouge'], 'nova', {'radius': 3.5, 'dmg': 1.6, 'burn': 0.5}, 11, {})])
element('espace', 'Espace', 'Espace', 'c08aff',
        ["Tu plies l'espace : tu te téléportes.",
         "L'espace se déchire et broie tes ennemis.",
         "Une porte dimensionnelle aspire tout."],
        {'dodge': 0.08},
        [(['Pas spatial', 'Distorsion', 'Maître de l\'Espace'], 'blink', {'dist': 8.0, 'dmg': 1.0}, 5, {'spd_pct': 0.05}),
         (['Fracture', 'Déchirure', 'Effondrement du Vide'], 'nova', {'radius': 4.0, 'dmg': 1.7}, 12, {}),
         (['Portail', 'Faille dimensionnelle', 'Horizon des Événements'], 'vortex', {'radius': 6.0, 'dmg': 1.2}, 14, {})])
element('temps', 'Temps', 'Temps', 'f0d0a0',
        ["Le temps ralentit autour de toi.",
         "Tu accélères ton propre temps.",
         "Tu figes le temps un instant."],
        {'cdr_pct': 0.1},
        [(['Lenteur', 'Temps figé', 'Horloge Brisée'], 'slow_field', {'radius': 6.0, 'factor': 0.25, 'dur': 5}, 16, {}),
         (['Hâte', 'Accélération', 'Instant Éternel'], 'buff', {'aspd': 0.5, 'spd': 0.3, 'dur': 6}, 16, {}),
         (['Arrêt', 'Stase', 'Fin du Temps'], 'stun', {'radius': 7.0, 'dur': 3.0}, 20, {})])
element('son', 'Son', 'Son', 'ffd0f0',
        ["Ta voix devient une arme.",
         "Un hurlement terrifiant fait fuir tes ennemis.",
         "Une onde sonore repousse tes ennemis."],
        {'stun': 0.05},
        [(['Écho', 'Résonance', 'Voix du Monde'], 'nova', {'radius': 4.0, 'dmg': 1.1, 'stun': 0.8}, 10, {}),
         (['Cri', 'Hurlement', 'Rugissement Primordial'], 'fear', {'radius': 6.0, 'dur': 3.5}, 14, {}),
         (['Onde de choc', 'Mur de son', 'Fracas'], 'cone', {'range': 6.0, 'dmg': 1.2, 'kb': 14, 'angle': 90}, 8, {})])
element('metal', 'Métal', 'Métal', 'c8ced6',
        ["Ta peau devient métal.",
         "Des lames d'acier jaillissent autour de toi.",
         "Une pluie de lames tombe sur tes ennemis."],
        {'def_flat': 4},
        [(['Peau d\'acier', 'Corps de fer', 'Titan d\'Adamant'], 'barrier', {'dur': 4, 'reduce': 0.6}, 16, {'thorns': 0.15}),
         (['Lames tournoyantes', 'Tourbillon d\'acier', 'Mille Lames'], 'aura', {'radius': 2.5, 'dps': 0.5, 'dur': 5}, 14, {}),
         (['Pluie de lames', 'Averse d\'acier', 'Arsenal Infini'], 'meteor', {'radius': 2.2, 'dmg': 1.2, 'count': 4}, 14, {})])
element('nature', 'Nature', 'Nature', '5ad04a',
        ["La nature te soigne.",
         "Des racines immobilisent tes ennemis.",
         "Des épines punissent ceux qui te frappent."],
        {'regen': 1.5},
        [(['Bourgeon', 'Floraison', 'Arbre-Monde'], 'heal', {'pct': 0.4}, 18, {'hp_pct': 0.05}),
         (['Racines', 'Lianes', 'Étreinte de la Forêt'], 'stun', {'radius': 4.5, 'dur': 2.5, 'dmg': 0.5}, 13, {}),
         (['Ronces', 'Épines', 'Mur de Ronces'], 'aura', {'radius': 2.2, 'dps': 0.3, 'dur': 7}, 15, {'thorns': 0.2})])
element('cristal', 'Cristal', 'Cristal', '8af0ff',
        ["Des éclats de cristal jaillissent de ton corps.",
         "Un cristal géant éclate au milieu des ennemis."],
        {'crit': 0.05},
        [(['Éclats', 'Averse de cristal', 'Prisme Infini'], 'volley', {'count': 7, 'dmg': 0.55, 'spread': 1.6}, 8, {}),
         (['Cristal', 'Géode', 'Cœur de Diamant'], 'meteor', {'radius': 3.2, 'dmg': 2.0, 'count': 1}, 12, {'def_flat': 2})])

# ---------------------------------------------------------------- Martiale
S('lame', ['Lame', 'Maître d\'armes', 'Saint de l\'Épée'], 'Martiale', 'e0e8ff',
  "Ton arme devient le prolongement de ton âme.",
  {'atk_pct': 0.12, 'crit': 0.05}, 'dash', {'dist': 6.0, 'dmg': 1.8}, 7)
S('mille_coups', ['Mille coups', 'Tempête d\'acier', 'Danse des Mille Lames'], 'Martiale', 'c0d0ff',
  "Tes coups s'enchaînent à une vitesse folle.",
  {'aspd_pct': 0.15}, 'aura', {'radius': 2.2, 'dps': 0.7, 'dur': 3}, 12)
S('forteresse', ['Rempart', 'Forteresse', 'Muraille Éternelle'], 'Martiale', 'a0a8b8',
  "Tu es un mur que rien ne traverse.",
  {'def_flat': 5, 'poise': 0.2, 'parry': 0.05}, 'barrier', {'dur': 5, 'reduce': 0.7}, 18)
S('titan', ['Force brute', 'Titan', 'Briseur de Montagnes'], 'Martiale', 'ff8a4a',
  "Tes coups écrasent tout et brisent l'équilibre des ennemis.",
  {'atk_pct': 0.1, 'poise': 0.5}, 'cone', {'range': 4.0, 'dmg': 2.0, 'kb': 10, 'angle': 80, 'stun': 0.5}, 10)
S('duelliste', ['Duelliste', 'Fine lame', 'Maître Duelliste'], 'Martiale', 'ffe0c0',
  "Face à un seul adversaire, tu es imbattable.",
  {'crit': 0.12, 'parry': 0.06}, 'execute', {'range': 5.0, 'dmg': 2.0, 'threshold': 0.5}, 9)
S('lancier', ['Estoc', 'Percée', 'Lance du Destin'], 'Martiale', 'd0e0ff',
  "Tu transperces plusieurs ennemis d'un seul élan.",
  {'atk_pct': 0.08}, 'dash', {'dist': 9.0, 'dmg': 1.5}, 8)
S('bouclier', ['Contre-attaque', 'Riposte', 'Bouclier Vengeur'], 'Martiale', 'a0c0ff',
  "Chaque coup reçu est rendu au centuple.",
  {'thorns': 0.25, 'parry': 0.05}, 'barrier', {'dur': 3, 'reduce': 0.9}, 14)
S('chasseur_primes', ['Chasseur', 'Traqueur', 'Fléau des Monstres'], 'Martiale', 'd0a060',
  "Tu achèves ceux qui fuient.",
  {'execute': 0.35, 'loot': 0.15}, 'execute', {'range': 9.0, 'dmg': 2.2, 'threshold': 0.3}, 9)
S('art_martial', ['Art martial', 'Poing de fer', 'Poing du Dragon'], 'Martiale', 'ffb070',
  "Tes poings et tes coups frappent comme des marteaux.",
  {'atk_pct': 0.08, 'stun': 0.05}, 'nova', {'radius': 2.8, 'dmg': 1.9, 'stun': 0.8}, 9)

# ---------------------------------------------------------------- Bête
S('instinct', ['Instinct', 'Sixième sens', 'Prédateur Alpha'], 'Bête', 'ffa04a',
  "Tes sens de bête t'avertissent de chaque attaque.",
  {'dodge': 0.12, 'spd_pct': 0.05}, 'dash', {'dist': 6.0, 'dmg': 1.2}, 6)
S('meute', ['Appel de la meute', 'Chef de meute', 'Roi des Loups'], 'Bête', 'b0b0b0',
  "Ton hurlement galvanise tes alliés et terrifie tes ennemis.",
  {'atk_pct': 0.06, 'regen': 0.5}, 'fear', {'radius': 7.0, 'dur': 3.0}, 15)
S('crocs', ['Crocs', 'Mâchoires', 'Dévoreur d\'Âmes'], 'Bête', 'ff5a5a',
  "Tu mords et déchires : chaque coup te soigne.",
  {'lifesteal': 0.1, 'crit': 0.04}, 'cone', {'range': 3.5, 'dmg': 1.7, 'kb': 4, 'angle': 90}, 7)
S('regeneration', ['Régénération', 'Régénération rapide', 'Immortalité'], 'Bête', '6aff8a',
  "Tes blessures se referment d'elles-mêmes.",
  {'regen': 4.0, 'hp_pct': 0.05}, 'heal', {'pct': 0.3}, 16)
S('carapace', ['Carapace', 'Écailles', 'Armure de Dragon'], 'Bête', '6aa06a',
  "Une carapace naturelle te protège.",
  {'def_flat': 6}, 'barrier', {'dur': 4, 'reduce': 0.5}, 15)
S('rage_bestiale', ['Rage bestiale', 'Frénésie', 'Berserker'], 'Bête', 'ff3a3a',
  "Tu entres dans une frénésie sanglante.",
  {'berserk': 0.3, 'lifesteal': 0.04}, 'buff', {'atk': 0.4, 'aspd': 0.3, 'lifesteal': 0.1, 'dur': 7}, 16)
S('souffle', ['Souffle', 'Souffle de dragon', 'Haleine du Dragon Primordial'], 'Bête', 'ff7a2a',
  "Tu craches un torrent de flammes.",
  {'burn': 0.1, 'hp_pct': 0.05}, 'cone', {'range': 6.0, 'dmg': 1.6, 'kb': 3, 'angle': 50, 'burn': 0.6}, 9)

# ---------------------------------------------------------------- Survie
S('survivant', ['Survivant', 'Increvable', 'Immortel'], 'Survie', 'ffc0a0',
  "Tu refuses de mourir : tu survis à un coup mortel.",
  {'last_stand': 1, 'hp_pct': 0.1}, 'heal', {'pct': 0.3}, 18)
S('endurance', ['Endurance', 'Ténacité', 'Corps Indestructible'], 'Survie', 'd0d0a0',
  "Tu encaisses plus que n'importe qui.",
  {'hp_pct': 0.2, 'def_flat': 2}, 'barrier', {'dur': 4, 'reduce': 0.4}, 15)
S('seconde_peau', ['Seconde peau', 'Mue', 'Renaissance'], 'Survie', 'a0ffc0',
  "Tu changes de peau et effaces tes blessures.",
  {'regen': 2.0}, 'heal', {'pct': 0.5}, 24)
S('nomade', ['Nomade', 'Voyageur', 'Marcheur des Mondes'], 'Survie', 'e0c090',
  "Toujours en mouvement, tu parcours le monde plus vite.",
  {'spd_pct': 0.15, 'xp': 0.1}, 'blink', {'dist': 7.0}, 6)
S('recolteur', ['Récolteur', 'Pillard', 'Roi du Butin'], 'Survie', 'ffd07a',
  "Tu trouves toujours de quoi faire.",
  {'loot': 0.4, 'kill_heal': 3}, 'buff', {'spd': 0.3, 'dur': 8}, 14)
S('medecin', ['Premiers soins', 'Médecin', 'Main du Guérisseur'], 'Survie', 'ffe0e0',
  "Tu soignes aussi les habitants autour de toi.",
  {'regen': 1.5}, 'heal', {'pct': 0.35, 'allies': 1}, 14)
S('vigilance', ['Vigilance', 'Garde éternelle', 'Sentinelle'], 'Survie', 'c0d8ff',
  "Rien ne te prend par surprise.",
  {'parry': 0.1, 'dodge': 0.06, 'def_flat': 2}, 'stun', {'radius': 3.5, 'dur': 2.0}, 12)

# ---------------------------------------------------------------- Ombre
S('assassin', ['Coup fatal', 'Assassinat', 'Faucheuse'], 'Ombre', '6a4a8a',
  "Tes coups critiques sont mortels.",
  {'crit': 0.15, 'crit_mult': 0.5}, 'execute', {'range': 6.0, 'dmg': 3.0, 'threshold': 0.4}, 10)
S('furtivite', ['Furtivité', 'Invisibilité', 'Fantôme'], 'Ombre', '8a8aaa',
  "Tu te fonds dans l'ombre et deviens intouchable un instant.",
  {'dodge': 0.1, 'spd_pct': 0.05}, 'barrier', {'dur': 2.5, 'reduce': 1.0}, 12)
S('dague_fantome', ['Dagues fantômes', 'Lames spectrales', 'Nuée de Lames'], 'Ombre', 'a08aff',
  "Des dagues d'ombre filent vers tes ennemis.",
  {'crit': 0.06}, 'volley', {'count': 6, 'dmg': 0.7, 'spread': 0.7}, 6)
S('poison_ombre', ['Lame empoisonnée', 'Venin noir', 'Mort Lente'], 'Ombre', '5a8a3a',
  "Tes lames enduites de poison tuent lentement.",
  {'burn': 0.25, 'crit': 0.03}, 'dot', {'radius': 3.0, 'dps': 0.4, 'dur': 5}, 10)
S('double', ['Double', 'Reflet', 'Légion d\'Ombres'], 'Ombre', '7a6aff',
  "Tu laisses derrière toi une image qui frappe à ta place.",
  {'dodge': 0.06, 'aspd_pct': 0.05}, 'blink', {'dist': 5.0, 'dmg': 1.8}, 7)
S('marque', ['Marque', 'Sceau de mort', 'Condamnation'], 'Ombre', 'aa3a6a',
  "Tu marques un ennemi : ses blessures s'aggravent.",
  {'execute': 0.25, 'crit': 0.04}, 'dot', {'radius': 2.5, 'dps': 0.6, 'dur': 4}, 9)

# ---------------------------------------------------------------- Esprit
S('esprit_ancien', ['Esprit ancien', 'Âme éveillée', 'Esprit Primordial'], 'Esprit', 'c0f0ff',
  "Les esprits anciens guident ta magie.",
  {'mag_pct': 0.15, 'regen': 0.5}, 'volley', {'count': 4, 'dmg': 0.9, 'spread': 0.8}, 7)
S('invocation', ['Feux follets', 'Esprits gardiens', 'Légion d\'Esprits'], 'Esprit', 'b0ffff',
  "Des esprits tournent autour de toi et frappent tes ennemis.",
  {'mag_pct': 0.08}, 'aura', {'radius': 2.6, 'dps': 0.5, 'dur': 8}, 16)
S('exorcisme', ['Purification', 'Exorcisme', 'Lumière Sacrée'], 'Esprit', 'fffae0',
  "Tu chasses le mal et les morts-vivants.",
  {'mag_pct': 0.08, 'execute': 0.2}, 'nova', {'radius': 4.0, 'dmg': 1.5}, 11)
S('telekinesie', ['Télékinésie', 'Emprise', 'Main Invisible'], 'Esprit', 'e0c0ff',
  "Tu soulèves et projettes tes ennemis par la pensée.",
  {'mag_pct': 0.1}, 'cone', {'range': 6.0, 'dmg': 1.0, 'kb': 18, 'angle': 70}, 8)
S('lien_ame', ['Lien d\'âme', 'Communion', 'Âme Partagée'], 'Esprit', 'ffd0ff',
  "Tu partages ta force vitale avec les habitants.",
  {'regen': 1.0, 'hp_pct': 0.08}, 'heal', {'pct': 0.25, 'allies': 1}, 12)
S('ame_errante', ['Âme errante', 'Spectre', 'Seigneur des Morts'], 'Esprit', '9affc8',
  "Tu aspires l'âme de tes ennemis vaincus.",
  {'kill_heal': 6, 'absorb': 0.1}, 'drain', {'radius': 5.0, 'dmg': 0.9, 'ratio': 0.5}, 12)

# ---------------------------------------------------------------- Chaos
S('chaos', ['Chaos', 'Désordre', 'Seigneur du Chaos'], 'Chaos', 'ff4aff',
  "Personne ne sait ce que tu vas faire, pas même toi : tout est possible.",
  {'crit': 0.08, 'burn': 0.05, 'stun': 0.05, 'slow': 0.05}, 'random', {}, 8)
S('fortune', ['Chance', 'Fortune', 'Bénédiction du Destin'], 'Chaos', 'ffe860',
  "La chance te sourit toujours.",
  {'crit': 0.1, 'loot': 0.25, 'dodge': 0.05}, 'buff', {'crit': 0.5, 'dur': 6}, 16)
S('instable', ['Magie instable', 'Surcharge', 'Explosion Primordiale'], 'Chaos', 'ff8aff',
  "Ta magie déborde et explose autour de toi.",
  {'mag_pct': 0.12}, 'nova', {'radius': 5.0, 'dmg': 2.0}, 14)
S('destruction', ['Destruction', 'Annihilation', 'Fin du Monde'], 'Chaos', 'ff2a2a',
  "Tu libères une puissance qui rase tout.",
  {'atk_pct': 0.08, 'mag_pct': 0.08}, 'meteor', {'radius': 3.5, 'dmg': 2.4, 'count': 2}, 18)
S('mimetisme', ['Mimétisme', 'Imitation', 'Copie Parfaite'], 'Chaos', 'd0a0ff',
  "Tu copies la force de tes ennemis.",
  {'absorb': 0.15, 'xp': 0.1}, 'drain', {'radius': 4.0, 'dmg': 0.8, 'ratio': 0.4}, 10)
S('pari', ['Pari', 'Quitte ou double', 'Main du Destin'], 'Chaos', 'ffc0ff',
  "Tu mises ta vie : dégâts énormes, mais tu t'affaiblis.",
  {'crit_mult': 0.6, 'berserk': 0.2}, 'buff', {'atk': 0.8, 'crit': 0.3, 'dur': 5, 'cost': 0.25}, 16)

# ---------------------------------------------------------------- Commandement
S('seigneur', ['Chef', 'Seigneur', 'Roi des Monstres'], 'Commandement', 'ffd060',
  "Ta présence inspire tes habitants et fait trembler tes ennemis.",
  {'def_flat': 2, 'atk_pct': 0.05, 'xp': 0.1}, 'fear', {'radius': 7.0, 'dur': 3.5}, 16)
S('nomination', ['Nommeur', 'Parrain', 'Créateur de Lignées'], 'Commandement', 'ffe0a0',
  "Tu donnes ta force à ceux qui te suivent.",
  {'regen': 1.0, 'hp_pct': 0.08}, 'heal', {'pct': 0.3, 'allies': 1}, 14)
S('general', ['Capitaine', 'Général', 'Empereur'], 'Commandement', 'e0b060',
  "Tu mènes au combat : tes coups et ceux de tes alliés redoublent.",
  {'atk_pct': 0.1, 'def_flat': 2}, 'buff', {'atk': 0.3, 'def': 4, 'dur': 8}, 16)
S('diplomate', ['Diplomate', 'Ambassadeur', 'Voix des Peuples'], 'Commandement', 'c0e0a0',
  "Tu obtiens toujours plus : butin et expérience.",
  {'loot': 0.3, 'xp': 0.2}, 'stun', {'radius': 5.0, 'dur': 2.0}, 14)
S('batisseur', ['Bâtisseur', 'Architecte', 'Fondateur d\'Empire'], 'Commandement', 'd0b080',
  "Tu es fait pour bâtir : solide et endurant.",
  {'hp_pct': 0.12, 'def_flat': 3}, 'barrier', {'dur': 5, 'reduce': 0.5}, 18)

# ---------------------------------------------------------------- Divers et uniques
S('gourmet', ['Gourmet', 'Gastronome', 'Festin Éternel'], 'Péché', 'ffa0c0',
  "Tu te nourris de tout : chaque ennemi vaincu te soigne beaucoup.",
  {'kill_heal': 10, 'hp_pct': 0.05}, 'drain', {'radius': 3.0, 'dmg': 1.1, 'ratio': 1.0}, 12)
S('miroir', ['Miroir', 'Réflexion', 'Miroir Absolu'], 'Sagesse', 'e8f0ff',
  "Tu renvoies les attaques à leur lanceur.",
  {'thorns': 0.3}, 'barrier', {'dur': 3, 'reduce': 0.8, 'reflect': 1}, 14)
S('gravite', ['Gravité', 'Pesanteur', 'Maître de la Gravité'], 'Espace', '9a6aff',
  "Tu écrases tes ennemis sous leur propre poids.",
  {'slow': 0.15, 'poise': 0.2}, 'vortex', {'radius': 5.0, 'dmg': 1.6}, 13)
S('etoile', ['Étoile filante', 'Comète', 'Pluie d\'Étoiles'], 'Lumière', 'fff0a0',
  "Des étoiles tombent sur tes ennemis.",
  {'mag_pct': 0.1, 'crit': 0.04}, 'meteor', {'radius': 2.4, 'dmg': 1.4, 'count': 4}, 14)
S('ours', ['Force de l\'ours', 'Colosse', 'Esprit de l\'Ours Ancien'], 'Bête', 'a0704a',
  "Force et robustesse de l'ours.",
  {'hp_pct': 0.15, 'atk_pct': 0.06}, 'nova', {'radius': 3.0, 'dmg': 1.5, 'stun': 0.5}, 10)
S('faucon', ['Œil de faucon', 'Vol du faucon', 'Roi du Ciel'], 'Bête', 'e0c080',
  "Rapide et précis comme un rapace.",
  {'crit': 0.1, 'spd_pct': 0.06}, 'dash', {'dist': 7.0, 'dmg': 1.4}, 6)
S('serpent', ['Serpent', 'Hydre', 'Ouroboros'], 'Bête', '6ac06a',
  "Souple et venimeux, tu te régénères comme l'hydre.",
  {'burn': 0.12, 'regen': 1.5}, 'dot', {'radius': 3.5, 'dps': 0.45, 'dur': 5}, 11)
S('phenix', ['Flamme renaissante', 'Phénix', 'Oiseau Immortel'], 'Feu', 'ffb040',
  "Tu renais de tes cendres.",
  {'last_stand': 1, 'burn': 0.08}, 'nova', {'radius': 4.0, 'dmg': 1.6, 'burn': 0.5, 'heal': 0.2}, 16)
S('ecorche', ['Écorcheur', 'Boucher', 'Carnage'], 'Martiale', 'c04a4a',
  "Chaque ennemi vaincu te pousse à frapper plus fort.",
  {'atk_pct': 0.06, 'kill_heal': 3}, 'aura', {'radius': 2.4, 'dps': 0.6, 'dur': 4}, 13)
S('marteau', ['Frappe sismique', 'Marteau des Dieux', 'Colère de la Forge'], 'Martiale', 'ffb060',
  "Tu frappes le sol si fort que tout vacille.",
  {'poise': 0.4, 'stun': 0.04}, 'nova', {'radius': 3.8, 'dmg': 1.7, 'stun': 1.0}, 11)
S('aurore', ['Aube', 'Aurore', 'Lumière Éternelle'], 'Lumière', 'ffd0a0',
  "Une lumière douce soigne et protège.",
  {'regen': 1.2, 'def_flat': 2}, 'barrier', {'dur': 4, 'reduce': 0.5, 'heal': 0.15}, 16)
S('abysse', ['Abysse', 'Profondeurs', 'Seigneur des Abysses'], 'Ténèbres', '3a4aaa',
  "Les profondeurs t'obéissent et engloutissent tes ennemis.",
  {'lifesteal': 0.04, 'slow': 0.1}, 'vortex', {'radius': 6.0, 'dmg': 1.3}, 14)
S('lune', ['Clair de lune', 'Lune sanglante', 'Éclipse'], 'Ténèbres', 'c0c0ff',
  "La lune renforce tes coups et ta magie.",
  {'atk_pct': 0.06, 'mag_pct': 0.06, 'crit': 0.04}, 'volley', {'count': 3, 'dmg': 1.2, 'spread': 0.5}, 8)
S('soleil', ['Rayon de soleil', 'Soleil de midi', 'Astre Brûlant'], 'Feu', 'ffe060',
  "La chaleur du soleil brûle tes ennemis.",
  {'burn': 0.1, 'regen': 0.8}, 'meteor', {'radius': 4.0, 'dmg': 2.0, 'count': 1, 'burn': 0.6}, 14)
S('vide', ['Vide', 'Néant', 'Absolu'], 'Espace', '4a2a6a',
  "Tu effaces ce qui se trouve devant toi.",
  {'crit_mult': 0.3, 'execute': 0.2}, 'execute', {'range': 7.0, 'dmg': 2.6, 'threshold': 0.45}, 11)
S('marees', ['Marée', 'Houle', 'Seigneur des Marées'], 'Eau', '4ab0e0',
  "Comme la marée, tu reviens toujours plus fort.",
  {'regen': 1.5, 'lifesteal': 0.03}, 'cone', {'range': 6.0, 'dmg': 1.3, 'kb': 10, 'angle': 140}, 9)
S('tempete', ['Tempête', 'Cyclone', 'Fureur des Éléments'], 'Foudre', 'c0e0ff',
  "Vent et foudre se déchaînent autour de toi.",
  {'stun': 0.05, 'spd_pct': 0.05}, 'aura', {'radius': 3.0, 'dps': 0.55, 'dur': 5}, 15)
S('volcan', ['Volcan', 'Éruption', 'Cœur du Monde'], 'Feu', 'ff4a1a',
  "La terre crache le feu autour de toi.",
  {'burn': 0.1, 'def_flat': 2}, 'meteor', {'radius': 2.6, 'dmg': 1.5, 'count': 3, 'burn': 0.5}, 16)
S('avalanche', ['Froid mordant', 'Avalanche', 'Ère Glaciaire'], 'Glace', 'd0f8ff',
  "Une vague de froid gèle tout sur son passage.",
  {'slow': 0.15, 'def_flat': 2}, 'cone', {'range': 7.0, 'dmg': 1.2, 'kb': 6, 'angle': 90, 'slow': 1.0}, 10)
S('eclipse', ['Éclipse', 'Nuit éternelle', 'Crépuscule des Dieux'], 'Ténèbres', '2a1a4a',
  "Les ténèbres étouffent la lumière et les ennemis.",
  {'lifesteal': 0.06, 'mag_pct': 0.08}, 'slow_field', {'radius': 6.0, 'factor': 0.4, 'dur': 5, 'dps': 0.35}, 16)
S('guetteur', ['Guetteur', 'Archer fantôme', 'Pluie de Flèches'], 'Martiale', 'd0c080',
  "Des traits magiques pleuvent sur l'ennemi.",
  {'crit': 0.06, 'aspd_pct': 0.05}, 'volley', {'count': 8, 'dmg': 0.5, 'spread': 1.0}, 7)
S('golem', ['Cœur de pierre', 'Golem', 'Titan de Pierre'], 'Terre', '8a8a7a',
  "Ton corps devient roche : lent mais indestructible.",
  {'def_flat': 8, 'hp_pct': 0.1, 'spd_pct': -0.05}, 'barrier', {'dur': 6, 'reduce': 0.6}, 18)
S('esprit_libre', ['Esprit libre', 'Âme vagabonde', 'Liberté Absolue'], 'Esprit', 'a0ffe0',
  "Rien ne t'entrave : tu vas plus vite, tu frappes plus vite.",
  {'spd_pct': 0.1, 'aspd_pct': 0.08, 'cdr_pct': 0.08}, 'blink', {'dist': 6.0, 'dmg': 0.8}, 5)
S('dompteur', ['Dompteur', 'Maître des bêtes', 'Seigneur Sauvage'], 'Bête', 'c0a070',
  "Les bêtes sauvages te craignent.",
  {'loot': 0.2, 'def_flat': 2}, 'fear', {'radius': 6.5, 'dur': 4.0}, 14)
S('necromancie', ['Nécromancie', 'Maître des morts', 'Roi Liche'], 'Ténèbres', '6aff9a',
  "Tu tires ta force de la mort qui t'entoure.",
  {'kill_heal': 5, 'mag_pct': 0.1}, 'drain', {'radius': 5.0, 'dmg': 1.1, 'ratio': 0.5}, 12)
S('alchimiste', ['Alchimie', 'Transmutation', 'Pierre Philosophale'], 'Sagesse', 'e0b0ff',
  "Tu transformes ce que tu touches.",
  {'loot': 0.25, 'regen': 1.0}, 'dot', {'radius': 4.0, 'dps': 0.4, 'dur': 5}, 11)
S('ange_gardien', ['Ange gardien', 'Bouclier céleste', 'Séraphin'], 'Lumière', 'ffffff',
  "Une présence céleste veille sur toi.",
  {'last_stand': 1, 'def_flat': 2, 'regen': 0.8}, 'barrier', {'dur': 3.5, 'reduce': 0.9}, 18)
S('demon_interieur', ['Démon intérieur', 'Possession', 'Seigneur Démon'], 'Chaos', 'aa1a3a',
  "Tu laisses sortir le démon qui dort en toi.",
  {'berserk': 0.25, 'atk_pct': 0.06}, 'buff', {'atk': 0.5, 'spd': 0.2, 'lifesteal': 0.1, 'dur': 7, 'cost': 0.1}, 16)
S('ecailles_dragon', ['Sang de dragon', 'Âme de dragon', 'Dragon Véritable'], 'Bête', 'd06a2a',
  "Le sang des dragons coule dans tes veines.",
  {'hp_pct': 0.1, 'atk_pct': 0.06, 'mag_pct': 0.06}, 'cone', {'range': 6.5, 'dmg': 1.8, 'kb': 5, 'angle': 60, 'burn': 0.5}, 10)
S('lien_elements', ['Élémentaliste', 'Maître des éléments', 'Seigneur Élémentaire'], 'Esprit', 'a0ffa0',
  "Tous les éléments répondent à ton appel.",
  {'mag_pct': 0.12, 'burn': 0.05, 'slow': 0.05, 'stun': 0.03}, 'random', {}, 7)


def tres(sk):
    def q(s):
        return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')
    def dict_str(d):
        items = []
        for k, v in d.items():
            items.append('%s: %s' % (q(k), repr(float(v)) if isinstance(v, (int, float)) else q(v)))
        return '{' + ', '.join(items) + '}'
    lines = ['[gd_resource type="Resource" script_class="SkillData" format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data/skill_data.gd" id="1"]', '',
             '[resource]', 'script = ExtResource("1")',
             'id = %s' % q(sk['id']),
             'tier_names = PackedStringArray(%s)' % ', '.join(q(n) for n in sk['names']),
             'category = %s' % q(sk['cat']),
             'color = Color(%.3f, %.3f, %.3f, 1)' % tuple(int(sk['color'][i:i + 2], 16) / 255.0 for i in (0, 2, 4)),
             'description = %s' % q(sk['desc']),
             'passive = %s' % dict_str(sk['passive']),
             'active = %s' % q(sk['active']),
             'active_params = %s' % dict_str(sk['params']),
             'cooldown = %s' % float(sk['cd'])]
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../data/skills')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    ids = set()
    for sk in SKILLS:
        assert sk['id'] not in ids, sk['id']
        ids.add(sk['id'])
        with open(os.path.join(a.out, sk['id'] + '.tres'), 'w') as f:
            f.write(tres(sk))
    cats = {}
    for sk in SKILLS:
        cats[sk['cat']] = cats.get(sk['cat'], 0) + 1
    print('%d compétences -> %s' % (len(SKILLS), a.out))
    print(cats)


if __name__ == '__main__':
    main()
