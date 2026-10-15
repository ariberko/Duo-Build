"""Draws the DuoBuild app icon (1024x1024, no transparency).

Two panes side by side, like the open iPhone Duo: a conversation on the left
and a live preview on the right, in DuoBuild's single indigo accent.
Run: python3 scripts/make_icon.py
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 4096  # draw big, then shrink for smooth edges
OUT = sys.argv[1] if len(sys.argv) > 1 else "AppAssets/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
BG_TOP, BG_BOTTOM = (28, 30, 44), (14, 15, 24)
PANE = (40, 43, 60)
LINE = (88, 92, 118)
ACCENT = (92, 97, 230)
WHITE = (236, 238, 248)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    d.line([(0, y), (S, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / (S - 1)))

# Soft shadow under the panes.
shadow = Image.new("L", (S, S), 0)
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle([560, 980, 3536, 3240], radius=260, fill=150)
shadow = shadow.filter(ImageFilter.GaussianBlur(120))
img.paste((6, 6, 10), (0, 0), shadow)
d = ImageDraw.Draw(img)

left = [520, 900, 1990, 3196]
right = [2106, 900, 3576, 3196]
for box in (left, right):
    d.rounded_rectangle(box, radius=200, fill=PANE)

# Left pane: a short conversation.
x0, y0 = left[0] + 170, left[1] + 230
d.rounded_rectangle([x0 + 420, y0, left[2] - 170, y0 + 230], radius=115, fill=ACCENT)
d.rounded_rectangle([x0, y0 + 380, x0 + 900, y0 + 520], radius=70, fill=LINE)
d.rounded_rectangle([x0, y0 + 600, x0 + 700, y0 + 740], radius=70, fill=LINE)
d.rounded_rectangle([x0 + 300, y0 + 920, left[2] - 170, y0 + 1150], radius=115, fill=ACCENT)
d.rounded_rectangle([x0, left[3] - 400, left[2] - 170, left[3] - 190], radius=105, outline=LINE, width=36)

# Right pane: a tiny app preview.
x0, y0 = right[0] + 170, right[1] + 230
d.rounded_rectangle([x0, y0, x0 + 820, y0 + 170], radius=85, fill=WHITE)
d.rounded_rectangle([x0, y0 + 300, right[2] - 170, y0 + 760], radius=110, fill=lerp(PANE, ACCENT, 0.45))
d.ellipse([x0 + 90, y0 + 400, x0 + 350, y0 + 660], fill=ACCENT)
for i in range(2):
    top = y0 + 900 + i * 230
    d.rounded_rectangle([x0, top, right[2] - 170, top + 150], radius=75, fill=LINE)
d.rounded_rectangle([x0, right[3] - 400, right[2] - 170, right[3] - 190], radius=105, fill=ACCENT)

img.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("Saved", OUT)
