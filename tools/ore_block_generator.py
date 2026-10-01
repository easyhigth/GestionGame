#!/usr/bin/env python3
"""Blocs des grottes de montagne : roche profonde et minerais (fer, or, cristal, mithril), dessinés
à partir de la pierre brute avec des éclats de couleur. Pillow requis.

    python3 tools/ore_block_generator.py   -> assets/blocks/bloc_*.png"""
import os
import random
from PIL import Image

HERE = os.path.dirname(__file__)
BLOCKS = os.path.join(HERE, "..", "assets", "blocks")

ORES = {
    "bloc_roche_profonde": None,
    "bloc_minerai_fer": [(196, 120, 72), (226, 156, 100), (150, 86, 52)],
    "bloc_minerai_or": [(242, 200, 80), (255, 232, 130), (190, 140, 40)],
    "bloc_minerai_cristal": [(110, 220, 240), (190, 250, 255), (60, 150, 200)],
    "bloc_minerai_mithril": [(170, 200, 230), (230, 240, 255), (110, 140, 180)],
}


def main():
    base = Image.open(os.path.join(BLOCKS, "bloc_pierre_brute.png")).convert("RGBA")
    w, h = base.size
    for name, pal in ORES.items():
        rnd = random.Random(hash(name) & 0xFFFF)
        img = base.copy()
        px = img.load()
        if pal is None:
            # roche profonde : plus sombre et bleutée
            for y in range(h):
                for x in range(w):
                    r, g, b, a = px[x, y]
                    px[x, y] = (int(r * 0.55), int(g * 0.58), int(b * 0.7), a)
        else:
            for y in range(h):
                for x in range(w):
                    r, g, b, a = px[x, y]
                    px[x, y] = (int(r * 0.8), int(g * 0.8), int(b * 0.82), a)
            # éclats de minerai : petites grappes
            s = max(1, w // 16)
            for _ in range(7):
                cx, cy = rnd.randrange(w // s), rnd.randrange(h // s)
                for _ in range(rnd.randint(3, 6)):
                    dx, dy = rnd.randint(-1, 1), rnd.randint(-1, 1)
                    gx, gy = (cx + dx) % (w // s), (cy + dy) % (h // s)
                    c = pal[rnd.randrange(3)]
                    for yy in range(gy * s, gy * s + s):
                        for xx in range(gx * s, gx * s + s):
                            px[xx, yy] = c + (255,)
        img.save(os.path.join(BLOCKS, name + ".png"))
        print("  ", name)


if __name__ == "__main__":
    main()
