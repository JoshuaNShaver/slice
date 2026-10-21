#!/usr/bin/env python3
"""Draws the web page's loading screen (design log 0197) into web/shell.html,
between its "loader: begin" and "loader: end" markers: the FLATLAND title
card on torn parchment over the Priest, whose aura fills in as the game
downloads (the page's script moves it). Torn edges and hatching are laid out
here once, seeded, so the page stays static. The two fonts are IM Fell
English cut down to the letters shown, inlined.

    python3 tools/loading_screen.py

Needs fontTools (pip install fonttools).
"""
import base64, io, math, os, random, re
from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHELL = os.path.join(ROOT, "web", "shell.html")
TITLE = "FLATLAND"
SUBTITLE = "A Romance of Many Dimensions"
# Everything the italic face shows: the subtitle and the page's notes.
ITALIC_TEXT = SUBTITLE + "Loading…0123456789%"


def font64(name, text):
    opts = subset.Options()
    opts.flavor = "woff"
    opts.hinting = False
    opts.layout_features = []
    font = subset.load_font(os.path.join(ROOT, "assets", "fonts", name), opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    out = io.BytesIO()
    subset.save_font(font, out, opts)
    return base64.b64encode(out.getvalue()).decode()

r = random.Random(1884)
INK = "#3b2a1e"
def f(v): return ("%.1f" % v).rstrip('0').rstrip('.')
def pts(ps): return " ".join("%s,%s" % (f(x), f(y)) for x, y in ps)

# Torn banner, as Sketch.torn_rect.
x0, y0, x1, y1 = 130, 52, 670, 212
cx, cy = (x0+x1)/2, (y0+y1)/2
corners = [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
torn = []
for i in range(4):
    a, b = corners[i], corners[(i+1)%4]
    n = max(int(math.dist(a,b)/12), 1)
    for k in range(n):
        t = k/n
        p = (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t)
        bite = r.uniform(0,5) + (7 if r.random() < 0.08 else 0)
        d = math.dist(p,(cx,cy)); 
        torn.append((p[0]+(cx-p[0])/d*bite, p[1]+(cy-p[1])/d*bite))
second = [(x+r.uniform(-1,1)+1, y+r.uniform(-1,1)+1) for x,y in torn]
shade = []
for k in range(int((x1-x0-12)/5)):  # pencil shading inside the bottom edge
    x = x0+6+(k+r.random())*5; d = 14*r.uniform(0.4,1)
    shade.append('<line x1="%s" y1="%s" x2="%s" y2="%s"/>' % (f(x), f(y1-5), f(x+d*0.5), f(y1-5-d)))
for k in range(int((y1-y0-12)/5)):  # and the right
    y = y0+6+(k+r.random())*5; d = 14*r.uniform(0.4,1)
    shade.append('<line x1="%s" y1="%s" x2="%s" y2="%s"/>' % (f(x1-5), f(y), f(x1-5-d), f(y+d*0.5)))

# The priest: a 40-gon, as in the world (CenterTerrain NPCS).
PX, PY, PR, AURA = 400, 436, 62, 76
poly = [(PX+PR*math.cos(math.tau*i/40), PY+PR*math.sin(math.tau*i/40)) for i in range(40)]
C = math.tau*AURA

# Ground: a line with slanted pen ticks under it.
GY = PY+PR
ground = [(40+i*30, GY+r.uniform(-0.8,0.8)) for i in range(25)]
ticks = []
x = 52
while x < 760:
    ticks.append('<line x1="%s" y1="%s" x2="%s" y2="%s"/>' % (f(x), GY+5, f(x-9), GY+15))
    x += 14 + r.uniform(-1.5,1.5)

stains = []
for (sx, sy, n) in [(110,330,4),(690,300,3),(620,560,4),(150,560,3),(700,90,3)]:
    for i in range(n):
        stains.append('<circle cx="%s" cy="%s" r="%s"/>' % (f(sx+r.uniform(-30,30)), f(sy+r.uniform(-20,20)), f(r.uniform(10,30))))


parts = []
parts.append("""<style>
/* The loading screen (design log 0197): the title card over the Priest,
   whose aura fills in as the game downloads. Lettered in IM Fell English,
   cut down to the letters shown here (tools: fontTools subset). */
@font-face { font-family: 'Fell Loader'; src: url(data:font/woff;base64,%s) format('woff'); }
@font-face { font-family: 'Fell Loader Italic'; src: url(data:font/woff;base64,%s) format('woff'); }
</style>""" % (font64("fell.ttf", TITLE), font64("fell_italic.ttf", ITALIC_TEXT)))

parts.append('''<svg id="loader" viewBox="0 40 800 600" role="img" aria-label="Loading Flatland">
	<defs>
		<filter id="pencil" x="-5%%" y="-5%%" width="110%%" height="110%%">
			<feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="3"/>
			<feDisplacementMap in="SourceGraphic" scale="3"/>
		</filter>
		<filter id="glow" x="-30%%" y="-30%%" width="160%%" height="160%%">
			<feGaussianBlur stdDeviation="6"/>
		</filter>
	</defs>
	<g fill="%s" fill-opacity="0.06">%s</g>
	<g filter="url(#pencil)">
		<g stroke="%s" stroke-width="1.4" stroke-linecap="round">
			<polyline points="%s" fill="none" stroke-width="3"/>
			<g stroke-opacity="0.45">%s</g>
		</g>
		<circle id="aura-track" cx="%d" cy="%d" r="%d" fill="none" stroke="#cdbbe8" stroke-opacity="0.35" stroke-width="4"/>
		<circle id="aura-glow" class="aura" cx="%d" cy="%d" r="%d" fill="none" stroke="#b9a3df" stroke-width="14" filter="url(#glow)"
			stroke-dasharray="%s" stroke-dashoffset="%s" transform="rotate(-90 %d %d)"/>
		<circle id="aura" class="aura" cx="%d" cy="%d" r="%d" fill="none" stroke="#a88fd6" stroke-width="5" stroke-linecap="round"
			stroke-dasharray="%s" stroke-dashoffset="%s" transform="rotate(-90 %d %d)"/>
		<polygon points="%s" fill="#f7efdc" stroke="%s" stroke-width="3" stroke-linejoin="round"/>
		<g transform="rotate(-1.5 400 132)">
			<polygon points="%s" fill="#f7efdc"/>
			<g stroke="%s" stroke-opacity="0.18" stroke-width="1">%s</g>
			<polygon points="%s" fill="none" stroke="%s" stroke-width="2.4" stroke-linejoin="round"/>
			<polygon points="%s" fill="none" stroke="%s" stroke-opacity="0.45" stroke-width="1.4" stroke-linejoin="round"/>
			<text x="400" y="146" text-anchor="middle" font-family="'Fell Loader', Georgia, serif" font-size="80" fill="%s">%s</text>
			<text x="400" y="190" text-anchor="middle" font-family="'Fell Loader Italic', Georgia, serif" font-style="italic" font-size="30" fill="%s">%s</text>
		</g>
	</g>
	<text id="loader-note" x="400" y="600" text-anchor="middle" font-family="'Fell Loader Italic', Georgia, serif" font-style="italic" font-size="26" fill="%s" fill-opacity="0.55">Loading…</text>
</svg>''' % (INK, "".join(stains), INK, pts(ground), "".join(ticks),
    PX, PY, AURA,
    PX, PY, AURA, f(C), f(C), PX, PY,
    PX, PY, AURA, f(C), f(C), PX, PY,
    pts(poly), INK,
    pts(torn), INK, "".join(shade), pts(torn), INK, pts(second), INK, INK, TITLE, INK, SUBTITLE, INK))

block = "\n".join(parts)
page = open(SHELL, encoding="utf-8").read()
page, n = re.subn(r"(<!-- loader: begin -->).*?(\n\t*<!-- loader: end -->)",
        lambda m: m.group(1) + "\n" + block + m.group(2), page, flags=re.S)
assert n == 1, "web/shell.html needs one loader: begin / end pair"
open(SHELL, "w", encoding="utf-8").write(page)
print("wrote the loading screen into", os.path.relpath(SHELL, ROOT))
