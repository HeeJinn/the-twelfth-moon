"""Draws the game's icon (the window, the web page's tab and the Android
launcher): the red moon on a night sky with a petal drifting past.

  assets/generated/app_icon.png             192x192 (48x48 drawn, scaled 4x)
  assets/generated/app_icon_foreground.png  432x432 Android adaptive layer: the
                                            moon and petal, kept inside the middle
                                            two thirds (launchers crop the rest)
  assets/generated/app_icon_background.png  432x432 Android adaptive layer: the sky

It reuses the game's own red moon and petal (assets/generated/red_moon.png and
petal.png, drawn by the importers). Run from the project folder:
  python tools/draw_app_icon.py
"""
from pathlib import Path

from PIL import Image

GENERATED = Path(__file__).resolve().parent.parent / "assets" / "generated"
SKY_TOP = (22, 18, 48)
SKY_BOTTOM = (54, 30, 70)
STAR = (255, 236, 244, 255)
STARS = [(6, 7), (40, 5), (9, 33), (42, 39), (21, 4), (35, 43)]


def sky(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / (size - 1)
        # Four flat bands, not a smooth gradient: it stays pixel art.
        t = round(t * 3) / 3
        color = tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM))
        for x in range(size):
            image.putpixel((x, y), (*color, 255))
    return image


def figures(size: int, scale_moon: float) -> Image.Image:
    """The moon in the middle and the petal at its lower right, at 1x."""
    layer = Image.new("RGBA", (size, size))
    moon = Image.open(GENERATED / "red_moon.png").convert("RGBA")
    if scale_moon != 1.0:
        side = round(moon.width * scale_moon)
        moon = moon.resize((side, side), Image.NEAREST)
    layer.alpha_composite(moon, ((size - moon.width) // 2, (size - moon.height) // 2))
    petal = Image.open(GENERATED / "petal.png").convert("RGBA")
    layer.alpha_composite(petal, (size // 2 + moon.width // 4, size // 2 + moon.height // 4))
    return layer


def main() -> None:
    icon = sky(48)
    for star in STARS:
        icon.putpixel(star, STAR)
    icon.alpha_composite(figures(48, 0.8))
    icon.resize((192, 192), Image.NEAREST).save(GENERATED / "app_icon.png")
    # Adaptive layers: 108 drawn, scaled 4x; the figures fit the middle 72.
    background = sky(108)
    for x, y in STARS:
        background.putpixel((x * 2 + 6, y * 2 + 6), STAR)
    background.resize((432, 432), Image.NEAREST).save(GENERATED / "app_icon_background.png")
    figures(108, 1.4).resize((432, 432), Image.NEAREST).save(
            GENERATED / "app_icon_foreground.png")
    print("icon -> assets/generated/app_icon.png and the two adaptive layers")


if __name__ == "__main__":
    main()
