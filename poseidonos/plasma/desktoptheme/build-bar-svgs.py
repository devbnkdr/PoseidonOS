#!/usr/bin/env python3
"""Generates the PoseidonOS taskbar art for the Plasma style:

  poseidonos/{,translucent/}widgets/panel-background.svg   (panel at 92% opacity)
  poseidonos/{solid,opaque}/widgets/panel-background.svg    (panel fully opaque)
  poseidonos/{,translucent/,solid/,opaque/}widgets/tasks.svg (task button states)

Everything is drawn with ColorScheme-* classes, so Plasma paints it in whichever
phosphor (green / amber / blue) colour scheme is active.  Run from this folder:
    python3 build-bar-svgs.py
"""
import os, sys

STYLE = """<style type="text/css" id="current-color-scheme">
.ColorScheme-Text { color:#1aff80; }
.ColorScheme-Background { color:#030a05; }
.ColorScheme-Highlight { color:#1aff80; }
.ColorScheme-NeutralText { color:#e8ff5a; }
.ColorScheme-ViewBackground { color:#030a05; }
</style>"""

def rect(x, y, w, h, cls=None, op=1.0):
    if cls is None:
        return '<rect x="%g" y="%g" width="%g" height="%g" fill="none"/>' % (x, y, w, h)
    return ('<rect x="%g" y="%g" width="%g" height="%g" class="ColorScheme-%s" '
            'style="fill:currentColor" fill-opacity="%.3f"/>' % (x, y, w, h, cls, op))

def group(gid, parts):
    return '<g id="%s">%s</g>' % (gid, "".join(parts))

# ------------------------------------------------------------------ panel
B, T = 6, 192          # border thickness, edge tile length (one major tick per tile)
C = 48                 # centre tile (multiple of the 3 px scanline pitch)

def panel(bg_op):
    W, H = B + T + B, B + C + B
    bg = lambda x, y, w, h: rect(x, y, w, h, "Background", bg_op)
    out = []

    def top_rows(x, w, ticks):
        # the bezel: a bright rule, two rows of phosphor bloom, a gap, a dim
        # second rule, and ruler ticks hanging off it toward the desktop
        p = [bg(x, 0, w, B),
             rect(x, 0, w, 1, "Text", 1.0),
             rect(x, 1, w, 1, "Text", 0.30),
             rect(x, 2, w, 1, "Text", 0.11),
             rect(x, 4, w, 1, "Text", 0.34)]
        if ticks:
            p.append(rect(x, 3, 1, 3, "Text", 0.85))               # major tick
            for i in (1, 2, 3):
                p.append(rect(x + i * T // 4, 4, 1, 2, "Text", 0.60))   # minor ticks
        return p

    out.append(group("topleft", top_rows(0, B, False) + [rect(0, 0, 1, B, "Text", 0.6)]))
    out.append(group("top", top_rows(B, T, True)))
    out.append(group("topright", top_rows(B + T, B, False) + [rect(W - 1, 0, 1, B, "Text", 0.6)]))
    out.append(group("left", [bg(0, B, B, C), rect(0, B, 1, C, "Text", 0.6)]))
    # centre: faint CRT scanlines every third row
    centre = [bg(B, B, C, C)] + [rect(B, B + y, C, 1, "Text", 0.045) for y in range(1, C, 3)]
    out.append('<g id="center">%s</g>' % "".join(centre))
    out.append(group("right", [bg(B + C, B, B, C), rect(B + C + B - 1, B, 1, C, "Text", 0.6)]))
    by = B + C
    out.append(group("bottomleft", [bg(0, by, B, B), rect(0, by, 1, B, "Text", 0.6), rect(0, by + B - 1, B, 1, "Text", 0.6)]))
    out.append(group("bottom", [bg(B, by, T, B), rect(B, by + B - 1, T, 1, "Text", 0.6)]))
    out.append(group("bottomright", [bg(B + T, by, B, B), rect(W - 1, by, 1, B, "Text", 0.6), rect(B + T, by + B - 1, B, 1, "Text", 0.6)]))
    # NB: the left/right/bottom pieces only show on a panel that does not touch
    # those screen edges; a full-width bottom bar draws just the top bezel.
    masks = [("topleft", 0, 0, B, B), ("top", B, 0, T, B), ("topright", B + T, 0, B, B),
             ("left", 0, B, B, C), ("center", B, B, C, C), ("right", B + C, B, B, C),
             ("bottomleft", 0, by, B, B), ("bottom", B, by, T, B), ("bottomright", B + T, by, B, B)]
    for name, x, y, w, h in masks:
        out.append('<rect id="mask-%s" x="%g" y="%g" width="%g" height="%g" fill="#000000"/>' % (name, x, y, w, h))
    for side in ("top", "bottom", "left", "right"):
        out.append('<rect id="hint-%s-margin" x="0" y="0" width="6" height="6" fill="none"/>' % side)
    out.append('<rect id="hint-tile-center" x="0" y="0" width="1" height="1" fill="none"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, H, W, H)
            + STYLE + "".join(out) + "</svg>\n")

# ------------------------------------------------------------------ task buttons
K, E = 6, 20           # corner size (= bracket arm length), edge/centre size
S = K + E + K          # one state block

def tasks():
    out = []
    def block(state, x0, deco):
        pos = {"topleft": (0, 0, K, K), "top": (K, 0, E, K), "topright": (K + E, 0, K, K),
               "left": (0, K, K, E), "center": (K, K, E, E), "right": (K + E, K, K, E),
               "bottomleft": (0, K + E, K, K), "bottom": (K, K + E, E, K), "bottomright": (K + E, K + E, K, K)}
        for part, (x, y, w, h) in pos.items():
            body = [rect(x0 + x, y, w, h)] + [rect(x0 + x + a, y + b, c, d, cls, op)
                                              for (a, b, c, d, cls, op) in deco(part, w, h)]
            out.append(group("%s-%s" % (state, part), body))
        for side in ("top", "bottom", "left", "right"):
            out.append('<rect id="%s-hint-%s-margin" x="0" y="0" width="4" height="4" fill="none"/>' % (state, side))

    def fill(cls, op):
        return lambda part, w, h: [(0, 0, w, h, cls, op)]
    def brackets(cls, op):
        def d(part, w, h):
            arms = {"topleft": [(0, 0, K, 1), (0, 0, 1, K)], "topright": [(0, 0, K, 1), (K - 1, 0, 1, K)],
                    "bottomleft": [(0, K - 1, K, 1), (0, 0, 1, K)], "bottomright": [(0, K - 1, K, 1), (K - 1, 0, 1, K)]}
            return [a + (cls, op) for a in arms.get(part, [])]
        return d
    def underline(cls, op, rows=2, dash=None):
        def d(part, w, h):
            if not part.startswith("bottom"):
                return []
            if dash is None:
                return [(0, h - rows, w, rows, cls, op)]
            on, off = dash
            segs, x = [], 0
            while x < w:
                segs.append((x, h - rows, min(on, w - x), rows, cls, op)); x += on + off
            return segs
        return d
    def combine(*fs):
        return lambda part, w, h: [r for f in fs for r in f(part, w, h)]

    # running, not active: a dashed underline
    block("normal", 0, underline("Text", 0.60, rows=2, dash=(3, 2)))
    # minimised: a faint dotted underline
    block("minimized", S, underline("Text", 0.65, rows=1, dash=(1, 1)))
    # under the mouse: selection brackets and a whisper of fill
    block("hover", 2 * S, combine(fill("Text", 0.07), brackets("Text", 0.80)))
    # the active window: lit fill, full-strength brackets, solid underline
    block("focus", 3 * S, combine(fill("Text", 0.16), brackets("Text", 1.0), underline("Text", 1.0, rows=2)))
    # wants attention: the same in the warning colour
    block("attention", 4 * S, combine(fill("NeutralText", 0.18), brackets("NeutralText", 1.0), underline("NeutralText", 1.0, rows=2)))
    W = 5 * S
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, S, W, S)
            + STYLE + "".join(out) + "</svg>\n")

if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "poseidonos")
    if len(sys.argv) > 1:
        root = sys.argv[1]
    for sub, op in (("", 0.92), ("translucent/", 0.92), ("solid/", 1.0), ("opaque/", 1.0)):
        d = os.path.join(root, sub + "widgets")
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "panel-background.svg"), "w").write(panel(op))
        open(os.path.join(d, "tasks.svg"), "w").write(tasks())
    print("wrote panel-background.svg and tasks.svg into", root)
