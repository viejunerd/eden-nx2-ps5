#!/usr/bin/env python3
"""Put the Eglantine logo (eglantine/logo.png, 256x256 RGBA) where the frontend shows its icon.

    logo.py <ProsperoEden checkout>      (needs Pillow)

Writes, from the logo alone (so re-running gives the same files):
  headless/prosperoeden/ui/art/brand.tga   384x384 RGBA, transparent: the launcher header and
                                            the stand-in cover of games without art
  sce_sys/icon0.png                         512x512 RGB: the PS5 home screen icon, on a plum field
The logo is 256 px, so both are upscaled: a larger original would look sharper.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

root = Path(sys.argv[1])
logo = Image.open(Path(__file__).with_name("logo.png")).convert("RGBA")


def fitted(size, share):
    side = round(size * share)
    return logo.resize((side, side), Image.Resampling.LANCZOS)


# Header / cover stand-in: transparent, the flower fills most of the square
brand = Image.new("RGBA", (384, 384), (0, 0, 0, 0))
flower = fitted(384, 0.92)
brand.alpha_composite(flower, ((384 - flower.width) // 2, (384 - flower.height) // 2))
brand.save(root / "headless/prosperoeden/ui/art/brand.tga", orientation=1)

# PS5 icon: radial plum field with a soft glow behind the flower
size = 512
field = Image.new("RGB", (size, size), (24, 13, 19))
glow = Image.new("L", (size, size), 0)
ImageDraw.Draw(glow).ellipse((size * .12, size * .12, size * .88, size * .88), fill=150)
glow = glow.filter(ImageFilter.GaussianBlur(70))
field = Image.composite(Image.new("RGB", (size, size), (92, 36, 62)), field, glow)
icon = field.convert("RGBA")
flower = fitted(size, 0.74)
icon.alpha_composite(flower, ((size - flower.width) // 2, (size - flower.height) // 2))
icon.convert("RGB").save(root / "sce_sys/icon0.png")
print("brand.tga and icon0.png written")
