#!/usr/bin/env python3
"""Recolour the frontend's artwork from green to pink (needs Pillow).

    recolor.py <ProsperoEden checkout>

The brand and icon come from logo.py instead. Each picture goes through its own luminance: dark stays dark plum, mid tones become rose, highlights
blush, so the sunset, leaves and icon keep their shapes. Alpha is kept. A picture that is already
pink is skipped, so re-running does nothing. Not covered: sce_sys/pic0.dds and pic1.dds (the PS5
home screen's DX10-compressed backgrounds) and the *-source.png files.
"""
import sys
from pathlib import Path

from PIL import Image, ImageOps

root = Path(sys.argv[1])
FILES = [
    "headless/prosperoeden/ui/art/backdrop.tga",
    "headless/prosperoeden/ui/art/backdrop-blur.tga",
]
BLACK, MID, WHITE = (8, 4, 8), (176, 74, 118), (255, 216, 232)


def mean_channel(img, band):
    data = img.convert("RGB").resize((64, 64)).getdata()
    return sum(p[band] for p in data) / len(data)


for rel in FILES:
    path = root / rel
    img = Image.open(path)
    rgba = img.convert("RGBA")
    if mean_channel(rgba, 0) > mean_channel(rgba, 1) * 1.15:
        print(f"{rel}: already pink")
        continue
    gray = ImageOps.autocontrast(rgba.convert("L"), cutoff=0)
    pink = ImageOps.colorize(gray, black=BLACK, mid=MID, white=WHITE, midpoint=110).convert("RGBA")
    pink.putalpha(rgba.getchannel("A"))
    if path.suffix == ".tga":
        pink.save(path, orientation=1)
    else:
        pink.convert(img.mode if img.mode in ("RGB", "RGBA") else "RGB").save(path)
    print(f"{rel}: recoloured")
