#!/usr/bin/env python3
"""Convert tools/icons/out/*.png to 32-bit uncompressed TGA in addon/EverSettings/Media/Icons.

WoW loads TGA textures with power-of-two dimensions; icons are 32x32 RGBA, pure white with
alpha, so the addon can tint them.
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "addon" / "EverSettings" / "Media" / "Icons"


def _save_white(alpha: Image.Image, name: str):
    white = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    white.save(OUT / f"{name}.tga", compression=None)


def generate_shapes():
    """Anti-aliased UI shapes, drawn at 8x and downsampled."""
    from PIL import ImageDraw

    ss = 8
    # knob: 32x32 canvas, circle of diameter 20 centred, so the slider thumb's hit area
    # (the whole texture) is larger than the visible knob.
    big = Image.new("L", (32 * ss, 32 * ss), 0)
    d = ImageDraw.Draw(big)
    r = 10 * ss
    c = 16 * ss
    d.ellipse((c - r, c - r, c + r, c + r), fill=255)
    _save_white(big.resize((32, 32), Image.LANCZOS), "knob")
    # pill: 64x32 rounded rectangle filling the canvas (toggle track).
    big = Image.new("L", (64 * ss, 32 * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, 64 * ss - 1, 32 * ss - 1), radius=16 * ss, fill=255)
    _save_white(big.resize((64, 32), Image.LANCZOS), "pill")
    # dot: 16x16 filled circle (modified indicator).
    big = Image.new("L", (16 * ss, 16 * ss), 0)
    ImageDraw.Draw(big).ellipse((2 * ss, 2 * ss, 14 * ss, 14 * ss), fill=255)
    _save_white(big.resize((16, 16), Image.LANCZOS), "dot")
    # rounded: 32x32 rounded square (logo tile, count pills via 9-slice-free stretching).
    big = Image.new("L", (32 * ss, 32 * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, 32 * ss - 1, 32 * ss - 1), radius=7 * ss, fill=255)
    _save_white(big.resize((32, 32), Image.LANCZOS), "rounded")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    generate_shapes()
    count = 0
    for png in sorted((HERE / "out").glob("*.png")):
        img = Image.open(png).convert("RGBA")
        if img.size[0] & (img.size[0] - 1) or img.size[1] & (img.size[1] - 1):
            raise SystemExit(f"{png.name}: size {img.size} is not a power of two")
        # Force pure white RGB; keep only the alpha channel from the render.
        alpha = img.getchannel("A")
        white = Image.new("RGBA", img.size, (255, 255, 255, 0))
        white.putalpha(alpha)
        white.save(OUT / (png.stem + ".tga"), compression=None)
        count += 1
    print(f"wrote {count} TGA icons to {OUT}")


if __name__ == "__main__":
    main()
