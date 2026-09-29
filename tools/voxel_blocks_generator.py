#!/usr/bin/env python3
"""
Textures des blocs de construction (16x16 pixels, un texel = un voxel de 5 cm... étiré sur 1 m).
Chaque matériau a son motif : planches, rondins, chaume, pierre, briques, marbre...

Usage :
    python voxel_blocks_generator.py --out ../assets/blocks
"""
import argparse, math, os, struct, zlib


def hs(x, y, s):
    n = math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
    return n - math.floor(n)


def png(path, px, alpha=False):
    w = h = 16
    rows = []
    for y in range(h):
        row = bytearray(b'\x00')
        for x in range(w):
            c = px[y][x]
            row += bytes(c[:4] if alpha else c[:3])
        rows.append(bytes(row))
    raw = b''.join(rows)

    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    ct = 6 if alpha else 2
    data = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, ct, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(data)


def rgb(hexc, f=1.0, a=255):
    r, g, b = (hexc >> 16) & 255, (hexc >> 8) & 255, hexc & 255
    return (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)


def grid(fn):
    return [[fn(x, y) for x in range(16)] for y in range(16)]


def planks(base, seed):
    def f(x, y):
        board = y // 4
        off = (board * 7) % 16
        seam = y % 4 == 3 or (x + off) % 16 == 0
        v = 0.9 + hs(x // 3, y, seed + board) * 0.18
        if seam:
            v = 0.62
        return rgb(base, v)
    return grid(f)


def logs(base, seed):
    def f(x, y):
        v = 0.85 + 0.2 * hs(x, y // 5, seed)
        if x % 4 == 0:
            v = 0.7
        if hs(x, y, seed + 3) > 0.93:
            v = 0.6
        return rgb(base, v)
    return grid(f)


def thatch(base, seed):
    def f(x, y):
        v = 0.8 + 0.35 * hs(x, (y + x * 3) // 2, seed)
        if y % 5 == 4:
            v *= 0.75
        return rgb(base, v)
    return grid(f)


def noise(base, seed, amp=0.25):
    def f(x, y):
        return rgb(base, 1.0 - amp / 2 + amp * hs(x // 2, y // 2, seed) * 0.6 + amp * hs(x, y, seed + 1) * 0.4)
    return grid(f)


def cobble(base, seed):
    # pierres irrégulières : cellules de Voronoi grossières
    pts = [(hs(i, 0, seed) * 16, hs(i, 1, seed) * 16) for i in range(9)]

    def f(x, y):
        d = sorted(((x - px) % 16) ** 2 + ((y - py) % 16) ** 2 for px, py in pts)
        d2 = sorted(min((x - px) ** 2, (x - px - 16) ** 2, (x - px + 16) ** 2) + min((y - py) ** 2, (y - py - 16) ** 2, (y - py + 16) ** 2) for px, py in pts)
        edge = math.sqrt(d2[1]) - math.sqrt(d2[0]) < 1.1
        v = 0.55 if edge else 0.85 + 0.25 * hs(int(math.sqrt(d2[0])), 0, seed)
        return rgb(base, v)
    return grid(f)


def bricks(base, seed, bh=4, bw=8):
    def f(x, y):
        row = y // bh
        off = (bw // 2) * (row % 2)
        mortar = y % bh == bh - 1 or (x + off) % bw == 0
        v = 0.62 if mortar else 0.88 + 0.2 * hs((x + off) // bw, row, seed)
        return rgb(base, v)
    return grid(f)


def polished(base, seed):
    def f(x, y):
        border = x == 0 or y == 0 or x == 15 or y == 15
        inner = x == 1 or y == 1
        v = 0.78 if border else (1.08 if inner else 0.97 + 0.05 * hs(x, y, seed))
        return rgb(base, v)
    return grid(f)


def marble(base, vein, seed):
    def f(x, y):
        t = math.sin((x * 0.6 + y * 0.9) + 3.0 * math.sin(y * 0.35 + seed) + 2 * hs(x // 4, y // 4, seed))
        if abs(t) < 0.12:
            return rgb(vein, 1.0)
        return rgb(base, 0.95 + 0.07 * hs(x, y, seed))
    return grid(f)


def gilded(base, gold, seed):
    m = marble(base, 0xb8b0a0, seed)
    for i in range(16):
        for j in (0, 15):
            m[j][i] = rgb(gold, 1.0 + 0.1 * (i % 2))
            m[i][j] = rgb(gold, 1.0 + 0.1 * (i % 2))
    for i in range(5, 11):
        m[i][i] = rgb(gold, 1.1)
        m[i][15 - i] = rgb(gold, 1.1)
    return m


def glass(seed):
    def f(x, y):
        frame = x == 0 or y == 0 or x == 15 or y == 15
        if frame:
            return (200, 225, 235, 255)
        shine = (x - y) in (4, 5) or (x - y) in (9,)
        return (230, 245, 255, 140) if shine else (170, 215, 235, 70)
    return grid(f)


def tiles(base, seed):
    def f(x, y):
        row = y // 4
        off = 4 * (row % 2)
        shade = 0.7 if y % 4 == 3 else (1.05 if y % 4 == 0 else 0.92)
        if (x + off) % 8 == 0:
            shade = 0.7
        return rgb(base, shade + 0.08 * hs((x + off) // 8, row, seed))
    return grid(f)


BLOCKS = {
    'bloc_planches': lambda: planks(0xa8783c, 1),
    'bloc_rondins': lambda: logs(0x7a5530, 2),
    'bloc_chaume': lambda: thatch(0xd0a850, 3),
    'bloc_terre': lambda: noise(0x7a5a3c, 4),
    'bloc_sable': lambda: noise(0xe0cc8a, 5, 0.15),
    'bloc_pierre_brute': lambda: cobble(0x8e8c86, 6),
    'bloc_briques': lambda: bricks(0x9a9892, 7),
    'bloc_tuiles': lambda: tiles(0xb0503a, 8),
    'bloc_verre': lambda: glass(9),
    'bloc_pierre_polie': lambda: polished(0xb8b6b0, 10),
    'bloc_ardoise': lambda: bricks(0x4a5058, 11, 3, 5),
    'bloc_marbre': lambda: marble(0xf0ece4, 0xa8a4a0, 12),
    'bloc_marbre_noir': lambda: marble(0x2a2a30, 0xe8d8a0, 13),
    'bloc_marbre_dore': lambda: gilded(0xf4f0e8, 0xe0b040, 14),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/blocks')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name, fn in BLOCKS.items():
        png(os.path.join(a.out, name + '.png'), fn(), alpha=(name == 'bloc_verre'))
    print('%d textures de blocs -> %s' % (len(BLOCKS), a.out))


if __name__ == '__main__':
    main()
