#!/usr/bin/env python3
"""Textures de l'interface (style pixel, assorti aux modèles voxel) : cadres en bois
sombre et dorures, parchemin, boutons, onglets, ruban de titre, cases, barres,
séparateurs et petites icônes. Tout est dessiné pixel par pixel puis agrandi ×2.

    python3 tools/ui_texture_generator.py      -> assets/ui/*.png

Nécessite Pillow (pip install pillow)."""
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
SCALE = 2

# palette
OUTLINE = (18, 12, 9, 255)
WOOD = [(42, 33, 27), (45, 35, 29), (47, 37, 30), (40, 31, 26)]
WOOD_LIGHT = [(74, 58, 46), (82, 64, 50), (88, 69, 54), (70, 54, 43)]
GOLD_HI = (255, 226, 140, 255)
GOLD = (242, 200, 106, 255)
GOLD_MID = (201, 149, 63, 255)
GOLD_DARK = (138, 106, 58, 255)
GOLD_SHADOW = (90, 64, 36, 255)
RUBY = (196, 52, 52, 255)
RUBY_HI = (255, 140, 120, 255)
EMERALD = (60, 170, 110, 255)
IRON = (107, 111, 117, 255)
IRON_HI = (170, 176, 182, 255)
IRON_DARK = (58, 61, 66, 255)
PARCH = [(233, 217, 176), (228, 210, 166), (236, 222, 184), (224, 205, 160)]
CLOTH = (142, 42, 42, 255)
CLOTH_HI = (179, 58, 53, 255)
CLOTH_DARK = (94, 27, 28, 255)


def new(w, h, fill=(0, 0, 0, 0)):
	return Image.new("RGBA", (w, h), fill)


def px(img, x, y, c):
	if 0 <= x < img.width and 0 <= y < img.height:
		img.putpixel((x, y), c if len(c) == 4 else c + (255,))


def rect(img, x0, y0, x1, y1, c):
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			px(img, x, y, c)


def save(img, name):
	os.makedirs(OUT, exist_ok=True)
	img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
	img.save(os.path.join(OUT, name))
	print("  ", name, img.size)


def wood_fill(img, x0, y0, x1, y1, pal, alpha=255, seed=1):
	"""Planches de bois : veines horizontales et joints verticaux décalés."""
	rnd = random.Random(seed)
	for y in range(y0, y1 + 1):
		row = rnd.randrange(len(pal))
		for x in range(x0, x1 + 1):
			c = pal[row]
			r = rnd.random()
			if r < 0.10:
				c = pal[(row + 1) % len(pal)]
			elif r < 0.13:
				c = tuple(max(0, v - 5) for v in c)
			px(img, x, y, c + (alpha,))
	# joints entre planches
	for y in range(y0 + 3, y1 + 1, 8):
		for x in range(x0, x1 + 1):
			if rnd.random() < 0.7:
				c = tuple(max(0, v - 6) for v in pal[0])
				px(img, x, y, c + (alpha,))


def gold_border(img, x0, y0, x1, y1, thick=3):
	"""Bordure dorée en relief : clair en haut à gauche, sombre en bas à droite."""
	for i in range(thick):
		top = [GOLD_HI, GOLD, GOLD_MID][min(i, 2)]
		bot = [GOLD_MID, GOLD_DARK, GOLD_SHADOW][min(i, 2)]
		for x in range(x0 + i, x1 - i + 1):
			px(img, x, y0 + i, top)
			px(img, x, y1 - i, bot)
		for y in range(y0 + i, y1 - i + 1):
			px(img, x0 + i, y, top)
			px(img, x1 - i, y, bot)


def corner_ornament(img, cx, cy, gem=RUBY):
	"""Ornement d'angle : losange doré avec une pierre au centre."""
	shape = [
		"...o...",
		"..oGo..",
		".oGgMo.",
		"oGgRgMo",
		".oMgdo.",
		"..odo..",
		"...o...",
	]
	cols = {"o": OUTLINE, "G": GOLD_HI, "g": GOLD, "M": GOLD_MID, "d": GOLD_DARK, "R": gem}
	for j, line in enumerate(shape):
		for i, ch in enumerate(line):
			if ch in cols:
				px(img, cx - 3 + i, cy - 3 + j, cols[ch])
	px(img, cx - 1, cy - 1, RUBY_HI if gem == RUBY else (200, 255, 220, 255))


# ---------------------------------------------------------------- cadres

def panel_frame():
	"""Grand cadre des menus (9 tranches : 12 px de marge à l'échelle 1)."""
	w = h = 40
	img = new(w, h)
	wood_fill(img, 4, 4, w - 5, h - 5, WOOD, 246, seed=3)
	# ombre intérieure sous la dorure
	for x in range(4, w - 4):
		px(img, x, 4, (20, 14, 11, 246))
	for y in range(4, h - 4):
		px(img, 4, y, (24, 17, 13, 246))
	rect_outline(img, 0, 0, w - 1, h - 1, OUTLINE)
	gold_border(img, 1, 1, w - 2, h - 2, 3)
	rect_outline(img, 4, 4, w - 5, h - 5, (30, 20, 14, 255))
	for (cx, cy) in [(4, 4), (w - 5, 4), (4, h - 5), (w - 5, h - 5)]:
		corner_ornament(img, cx, cy)
	save(img, "panel_frame.png")


def small_frame():
	"""Cadre fin pour bulles, infobulles et encarts (marges 5)."""
	w = h = 16
	img = new(w, h)
	wood_fill(img, 2, 2, w - 3, h - 3, WOOD, 235, seed=5)
	rect_outline(img, 0, 0, w - 1, h - 1, OUTLINE)
	for x in range(1, w - 1):
		px(img, x, 1, GOLD_MID)
		px(img, x, h - 2, GOLD_SHADOW)
	for y in range(1, h - 1):
		px(img, 1, y, GOLD_MID)
		px(img, w - 2, y, GOLD_SHADOW)
	for (x, y) in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]:
		px(img, x, y, GOLD_HI)
	save(img, "small_frame.png")


def card():
	"""Carte d'une liste (succès, bestiaire, habitants) : bois plus clair, filet doré."""
	for name, edge, fill_pal in [("card.png", GOLD_DARK, WOOD_LIGHT), ("card_hover.png", GOLD, WOOD_LIGHT),
			("card_locked.png", (70, 58, 48, 255), WOOD)]:
		w = h = 16
		img = new(w, h)
		wood_fill(img, 1, 1, w - 2, h - 2, [tuple(max(0, v - 18) for v in c) for c in fill_pal], 235, seed=7)
		rect_outline(img, 0, 0, w - 1, h - 1, edge)
		for x in range(1, w - 1):
			px(img, x, 1, tuple(min(255, v + 14) for v in fill_pal[0]) + (235,))
		save(img, name)


def parchment():
	"""Parchemin aux bords brûlés (fiches du bestiaire, pages du journal)."""
	w = h = 40
	rnd = random.Random(11)
	img = new(w, h)
	for y in range(h):
		for x in range(w):
			d = min(x, y, w - 1 - x, h - 1 - y)
			# bord déchiré
			if d == 0 and rnd.random() < 0.45:
				continue
			c = PARCH[rnd.randrange(len(PARCH))]
			if rnd.random() < 0.05:
				c = (214, 192, 146)
			# brûlure vers les bords
			burn = max(0, 5 - d) / 5.0
			if d <= 1:
				burn = 1.0
			c = tuple(int(v * (1 - 0.45 * burn) + (122, 85, 48)[i] * 0.45 * burn) for i, v in enumerate(c))
			px(img, x, y, c)
	for (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (1, 0), (0, 1)]:
		px(img, x, y, (0, 0, 0, 0))
	save(img, "parchment.png")


def rect_outline(img, x0, y0, x1, y1, c):
	for x in range(x0, x1 + 1):
		px(img, x, y0, c)
		px(img, x, y1, c)
	for y in range(y0, y1 + 1):
		px(img, x0, y, c)
		px(img, x1, y, c)


# ---------------------------------------------------------------- boutons

def plank_button(name, pal, edge, cap, shift=0, alpha=255):
	"""Bouton en planche : bois, fermoirs de métal aux deux bouts."""
	w, h = 28, 14
	img = new(w, h)
	wood_fill(img, 1, 1, w - 2, h - 2, pal, alpha, seed=13)
	for x in range(1, w - 1):
		px(img, x, 1 + shift, tuple(min(255, v + 18) for v in pal[0]) + (alpha,))
		px(img, x, h - 2, tuple(max(0, v - 16) for v in pal[0]) + (alpha,))
	rect_outline(img, 0, 0, w - 1, h - 1, edge)
	# fermoirs
	for xx in [2, w - 4]:
		for y in range(2, h - 2):
			px(img, xx, y, cap[0])
			px(img, xx + 1, y, cap[1])
		px(img, xx, 3, cap[2])
		px(img, xx, h - 4, cap[2])
	px(img, 0, 0, (0, 0, 0, 0)); px(img, w - 1, 0, (0, 0, 0, 0))
	px(img, 0, h - 1, (0, 0, 0, 0)); px(img, w - 1, h - 1, (0, 0, 0, 0))
	save(img, name)


def buttons():
	iron = (IRON, IRON_DARK, IRON_HI)
	gold = (GOLD_MID, GOLD_DARK, GOLD_HI)
	plank_button("button.png", [(74, 58, 46), (80, 62, 49), (70, 55, 44), (77, 60, 47)], (106, 80, 48, 255), iron)
	plank_button("button_hover.png", [(98, 76, 58), (104, 81, 62), (94, 73, 56), (101, 79, 60)], GOLD, gold)
	plank_button("button_pressed.png", [(58, 45, 36), (62, 48, 38), (55, 43, 34), (60, 46, 37)], GOLD_HI, gold, shift=1)
	plank_button("button_disabled.png", [(50, 45, 42), (53, 48, 44), (48, 43, 40), (52, 47, 43)], (70, 62, 56, 255),
		((80, 80, 80, 255), (55, 55, 55, 255), (100, 100, 100, 255)), alpha=200)
	# focus : seulement un liseré doré par-dessus
	w, h = 28, 14
	img = new(w, h)
	rect_outline(img, 0, 0, w - 1, h - 1, GOLD_HI)
	rect_outline(img, 1, 1, w - 2, h - 2, (242, 200, 106, 120))
	save(img, "button_focus.png")


def tabs():
	"""Onglets : celui choisi est plus clair et ouvert vers le bas."""
	for name, pal, edge in [("tab_selected.png", [(98, 76, 58), (104, 81, 62), (94, 73, 56)], GOLD),
			("tab.png", [(52, 41, 33), (56, 44, 35), (49, 39, 31)], (90, 70, 44, 255)),
			("tab_hover.png", [(74, 58, 46), (80, 62, 49), (70, 55, 44)], GOLD_MID)]:
		w, h = 20, 14
		img = new(w, h)
		wood_fill(img, 1, 1, w - 2, h - 1, pal, 255, seed=17)
		for x in range(1, w - 1):
			px(img, x, 0, edge)
			px(img, x, 1, tuple(min(255, v + 20) for v in pal[0]) + (255,))
		for y in range(1, h):
			px(img, 0, y, edge)
			px(img, w - 1, y, edge)
		if name != "tab_selected.png":
			for x in range(w):
				px(img, x, h - 1, edge)
		save(img, name)


# ---------------------------------------------------------------- titres et ornements

def ribbon():
	"""Bannière rouge à queues d'aronde derrière les titres (marges 10 à gauche et à droite)."""
	w, h = 40, 16
	img = new(w, h)
	for y in range(2, h - 2):
		for x in range(w):
			# queues d'aronde
			notch = abs(y - h // 2)
			if x < 6 - min(notch, 6) // 1 and x < 6 and notch < 3 and x < 3 - notch:
				continue
			if x > w - 4 + notch and notch < 3:
				continue
			c = CLOTH
			if y == 3:
				c = CLOTH_HI
			elif y >= h - 5:
				c = CLOTH_DARK
			px(img, x, y, c)
	# replis aux deux bouts, plus sombres
	for y in range(2, h - 2):
		for x in list(range(0, 6)) + list(range(w - 6, w)):
			if img.getpixel((x, y))[3] > 0:
				px(img, x, y, CLOTH_DARK if (x in (5, w - 6)) else tuple(max(0, v - 25) for v in CLOTH[:3]))
	# galons dorés
	for x in range(6, w - 6):
		px(img, x, 2, GOLD)
		px(img, x, 1, OUTLINE)
		px(img, x, h - 3, GOLD_MID)
		px(img, x, h - 2, OUTLINE)
	for y in range(1, h - 1):
		px(img, 5, y, OUTLINE)
		px(img, w - 6, y, OUTLINE)
	save(img, "ribbon.png")


def divider():
	"""Filet doré avec un losange au centre (séparateur de sections)."""
	w, h = 160, 7
	img = new(w, h)
	mid = w // 2
	for x in range(w):
		a = int(255 * min(1.0, min(x, w - 1 - x) / 40.0))
		if a <= 0:
			continue
		px(img, x, 3, GOLD_MID[:3] + (a,))
		px(img, x, 4, GOLD_SHADOW[:3] + (a // 2,))
	for j, line in enumerate([".o.", "oGo", "gRg", "odo", ".o."]):
		pass
	shape = ["...o...", "..oGo..", ".oGRgo.", "..odo..", "...o..."]
	for j, line in enumerate(shape):
		for i, ch in enumerate(line):
			c = {"o": OUTLINE, "G": GOLD_HI, "g": GOLD, "R": RUBY, "d": GOLD_DARK}.get(ch)
			if c:
				px(img, mid - 3 + i, 1 + j, c)
	for dx in (-14, 14):
		for j, line in enumerate([".o.", "oGo", ".o."]):
			for i, ch in enumerate(line):
				c = {"o": OUTLINE, "G": GOLD}.get(ch)
				if c:
					px(img, mid + dx - 1 + i, 2 + j, c)
	save(img, "divider.png")


# ---------------------------------------------------------------- cases, barres, ascenseurs

def slot():
	"""Case d'inventaire : creux sombre en relief inversé, coins dorés."""
	for name, corner in [("slot.png", GOLD_DARK), ("slot_selected.png", GOLD_HI)]:
		w = h = 18
		img = new(w, h)
		rect(img, 1, 1, w - 2, h - 2, (26, 20, 17, 230))
		for x in range(1, w - 1):
			px(img, x, 1, (12, 8, 6, 255))
			px(img, x, h - 2, (70, 56, 44, 255))
		for y in range(1, h - 1):
			px(img, 1, y, (12, 8, 6, 255))
			px(img, w - 2, y, (70, 56, 44, 255))
		rect_outline(img, 0, 0, w - 1, h - 1, (52, 40, 30, 255) if corner == GOLD_DARK else GOLD)
		for (x, y) in [(0, 0), (1, 0), (0, 1), (w - 1, 0), (w - 2, 0), (w - 1, 1), (0, h - 1), (1, h - 1), (0, h - 2),
				(w - 1, h - 1), (w - 2, h - 1), (w - 1, h - 2)]:
			px(img, x, y, corner)
		save(img, name)


def bars():
	"""Barres de vie, de faim, d'XP : creux sombre et remplissage clair (teinté en jeu)."""
	w, h = 16, 8
	img = new(w, h)
	rect(img, 1, 1, w - 2, h - 2, (16, 11, 9, 220))
	rect_outline(img, 0, 0, w - 1, h - 1, OUTLINE)
	for x in range(1, w - 1):
		px(img, x, 1, (8, 5, 4, 230))
	save(img, "bar_bg.png")
	img = new(w, h)
	for y in range(h):
		v = [255, 255, 236, 222, 210, 196, 182, 170][y]
		for x in range(w):
			px(img, x, y, (v, v, v, 255))
	for x in range(w):
		px(img, x, 1, (255, 255, 255, 255))
	save(img, "bar_fill.png")
	# cadre doré posé par-dessus la barre (vie du héros)
	w, h = 20, 10
	img = new(w, h)
	rect_outline(img, 0, 0, w - 1, h - 1, OUTLINE)
	gold_border(img, 1, 1, w - 2, h - 2, 1)
	save(img, "bar_frame.png")


def scroll():
	w, h = 6, 12
	img = new(w, h)
	rect(img, 1, 0, w - 2, h - 1, (18, 13, 10, 180))
	save(img, "scroll_track.png")
	for name, c1, c2 in [("scroll_grab.png", GOLD_DARK, GOLD_MID), ("scroll_grab_hover.png", GOLD_MID, GOLD)]:
		img = new(w, h)
		rect(img, 1, 1, w - 2, h - 2, c1)
		for y in range(1, h - 1):
			px(img, 2, y, c2)
		rect_outline(img, 0, 0, w - 1, h - 1, OUTLINE)
		px(img, 0, 0, (0, 0, 0, 0)); px(img, w - 1, 0, (0, 0, 0, 0))
		px(img, 0, h - 1, (0, 0, 0, 0)); px(img, w - 1, h - 1, (0, 0, 0, 0))
		save(img, name)


def field():
	"""Champ de saisie / liste déroulante : creux de bois."""
	w, h = 14, 12
	img = new(w, h)
	rect(img, 1, 1, w - 2, h - 2, (22, 17, 14, 240))
	rect_outline(img, 0, 0, w - 1, h - 1, (90, 70, 44, 255))
	for x in range(1, w - 1):
		px(img, x, 1, (10, 7, 5, 255))
	save(img, "field.png")
	img = new(w, h)
	rect(img, 1, 1, w - 2, h - 2, (22, 17, 14, 240))
	rect_outline(img, 0, 0, w - 1, h - 1, GOLD)
	save(img, "field_focus.png")


def portrait_frame():
	"""Médaillon pour les portraits (bestiaire, dialogues) : fond nuit, double cadre doré."""
	w = h = 32
	img = new(w, h)
	for y in range(h):
		for x in range(w):
			# dégradé radial bleu nuit
			d = ((x - w / 2) ** 2 + (y - h / 2) ** 2) ** 0.5 / (w / 2)
			c = (int(58 - 30 * d), int(48 - 26 * d), int(70 - 34 * d))
			px(img, x, y, c)
	rect_outline(img, 0, 0, w - 1, h - 1, OUTLINE)
	gold_border(img, 1, 1, w - 2, h - 2, 2)
	rect_outline(img, 3, 3, w - 4, h - 4, OUTLINE)
	for (cx, cy) in [(3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)]:
		corner_ornament(img, cx, cy, EMERALD)
	save(img, "portrait_frame.png")


# ---------------------------------------------------------------- icônes 12×12

ICONS = {
	"heart": (["..rr..rr....", ".rRRrrRRr...", "rRWRRRRRRr..", "rRRRRRRRRr..", "rRRRRRRRRr..", ".rRRRRRRr...",
		"..rRRRRr....", "...rRRr.....", "....rr......"], {"r": (90, 20, 24), "R": (220, 60, 60), "W": (255, 190, 180)}),
	"sword": (["..........ww", ".........wWw", "........wWw.", ".......wWw..", "..o...wWw...", "...o.wWw....",
		"....oWw.....", "....gog.....", "...g..o.....", "..b....o....", ".b..........", "b..........."],
		{"w": (120, 128, 140), "W": (225, 232, 240), "o": (60, 40, 30), "g": (242, 200, 106), "b": (120, 80, 50)}),
	"shield": ([".oooooooooo.", "oGGGGrrrrrro", "oGgggrRRRRro", "oGgggrRRRRro", "oGgggrRRRRro", "orrrrrGGGGGo",
		"orRRRrGgggGo", ".orRRrGggGo.", "..orRrGgGo..", "...orrGGo...", "....oooo...."],
		{"o": (30, 20, 14), "G": (242, 200, 106), "g": (201, 149, 63), "r": (110, 30, 30), "R": (170, 50, 48)}),
	"magic": ([".....s......", ".....S......", "....sSs.....", "sssSSWSSsss.", ".ssSWWWSss..", "..sSSWSSs...",
		"..sSs.sSs...", ".sSs...sSs..", ".ss.....ss..", "............", "..........s.", ".........sSs"],
		{"s": (110, 80, 200), "S": (180, 150, 255), "W": (240, 230, 255)}),
	"food": (["....g.......", "...gGg..g...", "....g..gGg..", "..g.g...g...", ".gGgg.g.g...", "..g.ggGgg...",
		"....gGgg....", ".....gg.....", ".....bb.....", ".....bb.....", ".....bb.....", "....bbbb...."],
		{"g": (200, 150, 50), "G": (250, 210, 100), "b": (120, 90, 40)}),
	"coin": (["...oooooo...", "..oGGGGGGo..", ".oGgggggdGo.", "oGgGggggdgdo", "oGggGgggdgdo", "oGggGgggdgdo",
		"oGggGgggdgdo", "oGgggGggdgdo", ".oGgggggdGo.", "..oddddddo..", "...oooooo..."],
		{"o": (90, 64, 30), "G": (255, 230, 150), "g": (242, 200, 106), "d": (190, 140, 60)}),
	"crown": (["............", "g....g....g.", "gg..ggg..gg.", "gGg.gGg.gGg.", "gGGgGGGgGGg.", "gGGGGGGGGGg.",
		"gGrGGbGGrGg.", "gGGGGGGGGGg.", "dddddddddd d", "............"],
		{"g": (201, 149, 63), "G": (250, 210, 110), "r": (200, 50, 50), "b": (70, 140, 230), "d": (138, 106, 58)}),
	"skull": (["..oooooooo..", ".oWWWWWWWWo.", "oWWWWWWWWWWo", "oWWWWWWWWWWo", "oWookWWookWo", "oWookWWookWo",
		"oWWWWooWWWWo", ".oWWWWWWWWo.", "..oWoWoWoo..", "..oWWWWWWo..", "...oooooo..."],
		{"o": (40, 34, 30), "W": (230, 222, 205), "k": (20, 16, 14)}),
	"scroll": (["..oooooooo..", ".oPPPPPPPPo.", "oPpPPPPPPpPo", ".oPPPPPPPPo.", ".oPlllllPPo.", ".oPPPPPPPPo.",
		".oPllllPPPo.", ".oPPPPPPPPo.", ".oPlllllPPo.", "oPpPPPPPPpPo", ".oPPPPPPPPo.", "..oooooooo.."],
		{"o": (110, 76, 40), "P": (236, 220, 180), "p": (200, 170, 120), "l": (120, 90, 60)}),
	"house": ([".....rr.....", "....rRRr....", "...rRRRRr...", "..rRRRRRRr..", ".rRRRRRRRRr.", "rrrrrrrrrrrr",
		".wWWWWWWWWw.", ".wWbbWWddWw.", ".wWbbWWddWw.", ".wWWWWWddWw.", ".wwwwwwwwww."],
		{"r": (110, 40, 34), "R": (170, 64, 50), "w": (90, 64, 44), "W": (170, 130, 90), "b": (120, 190, 230), "d": (70, 46, 30)}),
	"people": (["...oo...oo..", "..oSSo.oSSo.", "..oSSo.oSSo.", "...oo...oo..", "..obbo.oggo.", ".obbbbooggggo",
		".obbbbooggggo", ".obbbbooggggo", "..oo.o..o.oo"],
		{"o": (30, 22, 18), "S": (230, 190, 150), "b": (70, 110, 190), "g": (90, 160, 80)}),
	"star": ([".....o......", "....oGo.....", "....oGo.....", "oooogGgoooo.", "oGGGgggGGGo.", ".oGgggggGo..",
		"..ogggggo...", ".oggo.oggo..", ".ogo...ogo..", "oo.......oo."],
		{"o": (120, 80, 30), "G": (255, 236, 150), "g": (242, 200, 106)}),
	"moon": (["....oooo....", "..ooMMMo....", ".oMMMoo.....", ".oMMo.......", "oMMo........", "oMMo........",
		"oMMo........", "oMMMo.......", ".oMMMoo...o.", ".oMMMMMoooo.", "..ooMMMMMo..", "....oooo...."],
		{"o": (90, 100, 150), "M": (210, 220, 255)}),
	"sun": ([".....y......", ".y...y...y..", "..y.ooo.y...", "...oYYYo....", "..oYWYYYo...", "yyoYYYYYoyy.",
		"..oYYYYYo...", "...oYYYo....", "..y.ooo.y...", ".y...y...y..", ".....y......"],
		{"o": (220, 140, 40), "Y": (255, 220, 90), "W": (255, 250, 210), "y": (255, 200, 80)}),
	"gem": (["...oooooo...", "..oCWCCcco..", ".oCWCCCccco.", "oooooooooooo", ".oCCCCccco..", "..oCCCcco...",
		"...oCcco....", "....oco.....", ".....o......"],
		{"o": (30, 60, 80), "C": (110, 220, 240), "c": (60, 150, 190), "W": (230, 255, 255)}),
	"book": (["oooooooooo..", "oRRRRRRRRo..", "oRggggggRo..", "oRgRRRRgRo..", "oRggggggRo..", "oRRRRRRRRo..",
		"oRRRRRRRRo..", "oRRRRRRRRo..", "oRRRRRRRRo..", "oPPPPPPPPo..", "oooooooooo.."],
		{"o": (40, 24, 18), "R": (120, 40, 40), "g": (242, 200, 106), "P": (236, 220, 180)}),
	"compass": (["...oooooo...", "..oPPPPPPo..", ".oPPPrPPPPo.", "oPPPPrPPPPPo", "oPPPrrrPPPPo", "oPPPPkPPPPPo",
		"oPPPPbPPPPPo", "oPPPbbbPPPPo", ".oPPPbPPPPo.", "..oPPPPPPo..", "...oooooo..."],
		{"o": (138, 106, 58), "P": (236, 220, 180), "r": (200, 50, 50), "b": (60, 70, 110), "k": (30, 20, 14)}),
}


def icons():
	for name, (rows, cols) in ICONS.items():
		img = new(12, 12)
		for y, line in enumerate(rows[:12]):
			for x, ch in enumerate(line[:12]):
				if ch in cols:
					px(img, x, y, cols[ch])
		save(img, "icon_%s.png" % name)


# ---------------------------------------------------------------- blasons des nations

CRESTS = {
	# champ, champ sombre (partition), emblème, motif 12×12
	"karg": ((200, 110, 60), (150, 70, 40), (30, 22, 18), [
		"..........oo", ".........oWo", "....o...oWo.", "...oWo.oWo..", "..oWWWoWo...", ".oWWWWWo....",
		"..oWWWoo....", "...ooo.o....", "......o.o...", ".....o...o..", "....o.....o.", "............"]),
	"sylvae": ((70, 140, 70), (40, 100, 50), (242, 200, 106), [
		".....oo.....", "....oWWo....", "...oWWWWo...", "..oWWoWWWo..", ".oWWWoWWWWo.", ".oWWWWoWWWo.",
		"..oWWWWoWo..", "...oWWWWo...", "....ooWoo...", "......o.....", "......o.....", "............"]),
	"sables": ((222, 180, 90), (180, 130, 60), (130, 40, 30), [
		"......o.....", "..o...o...o.", "...o.ooo.o..", "....oWWWo...", "..ooWWWWWoo.", "....oWWWo...",
		"...o.ooo.o..", "..o...o...o.", "......o.....", "............", "oooooooooooo", "............"]),
	"givre": ((90, 150, 210), (50, 100, 170), (240, 248, 255), [
		".....o......", "...o.o.o....", "....ooo.....", ".o..ooo..o..", "..o.ooo.o...", "ooooooooooo.",
		"..o.ooo.o...", ".o..ooo..o..", "....ooo.....", "...o.o.o....", ".....o......", "............"]),
	"cendres": ((90, 30, 30), (50, 18, 20), (255, 150, 50), [
		".....o......", ".....oo.....", "....oWo..o..", "...oWWo.oo..", "..oWWWWoWo..", "..oWWYWWWo..",
		".oWWYYYWWo..", ".oWYYYYYWo..", ".oWYYYYYWo..", "..oWYYYWo...", "...ooooo....", "............"]),
}


def crests():
	"""Écu de chaque nation : champ parti en deux tons, bordure dorée, emblème au centre."""
	w, h = 24, 28
	for nid, (field, dark, emb, rows) in CRESTS.items():
		img = new(w, h)
		for y in range(h):
			for x in range(w):
				# forme d'écu : bords droits puis pointe en bas
				half = w / 2.0
				if y > 16:
					t = (y - 16) / (h - 16)
					if abs(x + 0.5 - half) > half * (1.0 - t * t) - 0.5:
						continue
				c = field if x < w // 2 else dark
				px(img, x, y, c)
		# contour et dorure
		edge = []
		for y in range(h):
			for x in range(w):
				if img.getpixel((x, y))[3] == 0:
					continue
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h or img.getpixel((nx, ny))[3] == 0:
						edge.append((x, y))
						break
		for (x, y) in edge:
			px(img, x, y, GOLD if y < h // 2 else GOLD_MID)
		for (x, y) in edge:
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] > 0 and (nx, ny) not in edge:
					px(img, nx, ny, GOLD_SHADOW)
		# emblème (W : couleur de l'emblème, Y : cœur clair, o : contour sombre)
		for j, line in enumerate(rows):
			for i, ch in enumerate(line):
				c = {"o": tuple(max(0, v - 90) for v in emb) if sum(emb) > 300 else OUTLINE[:3], "W": emb, "Y": (255, 230, 150)}.get(ch)
				if c:
					px(img, 6 + i, 7 + j, c)
		# reflet
		for y in range(3, 12):
			px(img, 3, y, (255, 255, 255, 60))
		save(img, "crest_%s.png" % nid)


if __name__ == "__main__":
	print("textures de l'interface ->", os.path.normpath(OUT))
	panel_frame()
	small_frame()
	card()
	parchment()
	buttons()
	tabs()
	ribbon()
	divider()
	slot()
	bars()
	scroll()
	field()
	portrait_frame()
	icons()
	crests()
