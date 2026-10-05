#!/usr/bin/env python3
"""
Donne une scène Godot (scenes/decor/<nom>.tscn) à chaque décor voxel de assets/environment/models/.

Chaque scène est un Node3D avec le modèle en enfant (« Model ») : on peut la retoucher dans l'éditeur
(échelle, décalage, rotation du modèle) et le jeu en tient compte, y compris pour les décors
du monde ouvert dessinés en MultiMesh (world_generator.gd, _mesh_of).

Les décors qui ont déjà une scène dans scenes/props/ (cabane, feu de camp, caisse...) sont laissés de côté.
Une scène qui existe déjà n'est jamais réécrite (les retouches faites à la main sont gardées).

Usage :
    python decor_scenes.py
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
MODELS = 'assets/environment/models'
OUT = 'scenes/decor'
PROPS = 'scenes/props'

TEMPLATE = '''[gd_scene format=3]

[ext_resource type="PackedScene" path="res://%s/%s.glb" id="1"]

[node name="%s" type="Node3D"]

[node name="Model" parent="." instance=ExtResource("1")]
'''


def node_name(stem):
    return ''.join(p.capitalize() for p in stem.split('_'))


def main():
    os.makedirs(os.path.join(ROOT, OUT), exist_ok=True)
    props = {f[:-5] for f in os.listdir(os.path.join(ROOT, PROPS)) if f.endswith('.tscn')}
    made = 0
    for f in sorted(os.listdir(os.path.join(ROOT, MODELS))):
        if not f.endswith('.glb'):
            continue
        stem = f[:-4]
        if stem in props:
            continue
        path = os.path.join(ROOT, OUT, stem + '.tscn')
        if os.path.exists(path):
            continue
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(TEMPLATE % (MODELS, stem, node_name(stem)))
        made += 1
    print('%d scène(s) de décor écrite(s) dans %s' % (made, OUT))


if __name__ == '__main__':
    main()
