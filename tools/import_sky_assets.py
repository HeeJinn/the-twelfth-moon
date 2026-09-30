"""Night sky art for the Lantern Forest (Chapter Two) and shooting stars, and
the title and end screen skies.

Run from the project folder after the other importers:
    python tools/import_sky_assets.py

Where it comes from:
  Starry_Night_Itch_Package  eight parallax layers drawn at 640x360 (author and
                             licence still to be confirmed) and a falling-star GIF

The layers are used as drawn, in whole pixels: no scaling, so nothing blurs.
The game's view is 480x270, so each layer is cut to its lower 270 rows (the
top rows are all sky the view never reaches for the near layers) and the
scene slides it sideways.
  layer 8  the night sky with the ringed planet and the Milky Way. Does NOT
           tile (its two edges differ), so it only drifts a little.
  layer 7, 6, 5  far, middle and near silhouettes. These tile sideways.
Layers 4 to 1 (big trees and ground) are left out: they would fight the
forest's own trees and platforms.
The falling-star GIF becomes a strip of its seven frames (62x85 each).

  Free DEMO Pixel Skies (Digital Moons; credit by linking
  digitalmoons.itch.io/pixel-skies in the game): six skies drawn at 240x135,
  exactly half the view, so they are doubled in whole pixels to 480x270.
  demo06 (night clouds) is the title sky. Its crescent is covered over, since
  the title puts the red moon there: the sky is drawn in horizontal bands, so
  each row inside the crescent's box is refilled from the pixel to its left.
  demo04 (purple stars) is the end screen sky.
The packs are never edited; this only copies, crops and repacks.
"""
from PIL import Image

from import_assets import ASSETS, PACKS

STARRY = PACKS / "Starry_Night_Itch_Package" / "Starry_Night_Itch_Package"
LAYERS = STARRY / "Layers_640x360"
FALLING_STAR = STARRY / "Falling_Star" / "Starry_night_star_640x360.gif"
FOREST = ASSETS / "forest"
EFFECTS = ASSETS / "effects"
SKIES = ASSETS / "skies"
DIGITAL_MOONS = (PACKS / "Free DEMO Pixel Skies Background pack by Digital Moons"
        / "Free DEMO Pixel Skies Background pack by Digital Moons" / "Pixel Skies 240x135px")
# demo06's crescent moon (x 178-199, y 27-47) with a margin, (left, top, right, bottom).
MOON_BOX = (175, 26, 203, 51)

WIDTH, HEIGHT = 640, 360
VIEW_HEIGHT = 270
SKY_TOP = HEIGHT - VIEW_HEIGHT

# Pack layer number -> file in assets/forest.
LAYERS_USED = {8: "starry_sky", 7: "starry_far", 6: "starry_mid", 5: "starry_near"}


def cut_layers() -> None:
    for number, name in LAYERS_USED.items():
        layer = Image.open(LAYERS / f"Starry_night_Layer_{number}.png").convert("RGBA")
        layer.crop((0, SKY_TOP, WIDTH, HEIGHT)).save(FOREST / f"{name}.png")
        print(f"layer {number} -> assets/forest/{name}.png")


def cut_falling_star() -> None:
    gif = Image.open(FALLING_STAR)
    frames = []
    for index in range(gif.n_frames):
        gif.seek(index)
        frames.append(gif.convert("RGBA"))
    width, height = frames[0].size
    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.paste(frame, (index * width, 0))
    strip.save(EFFECTS / "shooting_star.png")
    print(f"falling star -> assets/effects/shooting_star.png ({len(frames)} of {width}x{height})")


def cut_title_skies() -> None:
    sky = Image.open(DIGITAL_MOONS / "demo06_PixelSky.png").convert("RGB")
    pixels = sky.load()
    left, top, right, bottom = MOON_BOX
    for y in range(top, bottom):
        if pixels[left - 2, y] != pixels[right + 1, y]:
            print(f"  note: row {y} differs on the two sides of the moon box")
        for x in range(left, right):
            pixels[x, y] = pixels[left - 2, y]
    sky.resize((480, 270), Image.NEAREST).save(SKIES / "title_night.png")
    print("demo06 (moon covered) -> assets/skies/title_night.png")
    stars = Image.open(DIGITAL_MOONS / "demo04_PixelSky.png").convert("RGB")
    stars.resize((480, 270), Image.NEAREST).save(SKIES / "end_stars.png")
    print("demo04 -> assets/skies/end_stars.png")


if __name__ == "__main__":
    cut_layers()
    cut_falling_star()
    cut_title_skies()
