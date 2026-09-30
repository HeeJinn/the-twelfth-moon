"""Campfire rest effects: the Holy pack's Heal sparkles, in two colours.

Run from the project folder after the other importers:
    python tools/import_holy_assets.py

Where it comes from:
  PixelHolyEffectsPack01 (Sentient Dream Studio): Heal, twelve frames of 64x64

Every frame of the pack uses the same five colours, so recolouring is a plain
palette swap with no blur or new shades:
  heal_gold  warm pale gold, for the heart refill when she lights a campfire
  heal_moon  silver-blue moonlight, for the moons that refill after it
The pack's Holy Shield (a cross) and the rest of its effects are not used.
The pack is never edited; this only copies and recolours.
"""
from PIL import Image

from import_assets import ASSETS, PACKS

HEAL = PACKS / "PixelHolyEffectsPack01 v1_1" / "Heal" / "Spritesheet" / "Heal_spritesheet.png"
EFFECTS = ASSETS / "effects"

# The pack's palette, brightest first.
SOURCE = [(253, 253, 253), (254, 248, 217), (252, 241, 180), (239, 209, 184), (208, 145, 128)]
RAMPS = {
    "heal_gold": [(255, 253, 240), (255, 243, 196), (255, 224, 138), (232, 180, 90), (183, 121, 58)],
    "heal_moon": [(246, 250, 255), (214, 232, 255), (170, 204, 245), (122, 160, 215), (78, 104, 170)],
}


def recolour(image: Image.Image, ramp: list[tuple[int, int, int]]) -> Image.Image:
    swap = {SOURCE[i]: ramp[i] for i in range(len(SOURCE))}
    result = image.convert("RGBA")
    pixels = result.load()
    unknown = set()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha:
                if (red, green, blue) not in swap:
                    unknown.add((red, green, blue))
                pixels[x, y] = swap.get((red, green, blue), (red, green, blue)) + (alpha,)
    if unknown:
        print(f"  note: {len(unknown)} colour(s) outside the pack palette left as they are")
    return result


if __name__ == "__main__":
    sheet = Image.open(HEAL)
    for name, ramp in RAMPS.items():
        recolour(sheet, ramp).save(EFFECTS / f"{name}.png")
        print(f"Heal -> assets/effects/{name}.png")
