"""Chapter Five, the Twelfth Night: the storm over Ember Keep's roof, the huge red
moon, the lightning rods, and Kael's fight sheets.

Run from the project folder after the other importers:
    python tools/import_rooftop_assets.py

Where it comes from:
  New free backgrounds part3 / background 4 (CraftPix): a storm sky in four layers
    of 576x324 (flat sky, far clouds, near clouds, a dark cloud ceiling with two
    lightning bolts in it). The bolts are split off the ceiling so they can flash
    on their own.
  Magic Pack 9 (Ansimuz): Lightning (11 frames of 64x128, ground on the bottom row).
  Elementals Fire Knight (chierit): Kael's sheets, 288x128 frames with his head at
    x 146 and his feet on the bottom row, facing right.

Made here (assets/rooftop/):
  storm_sky.png, storm_far.png, storm_near.png, storm_ceiling.png, storm_bolts.png
  red_moon_huge.png      the red moon drawn like the small ones, 112 px across
  moon_glow_huge.png     a soft red glow behind it
  lightning.png          the rod's tip sparkles (the warning), then the bolt falls
                         and bursts (19 frames of 64x128)
  lightning_rod.png      an iron rod on a little stone foot
  kael_<animation>.png   200x112 cells (his body at x 86, feet at y 112), eight to a
                         row (the long strips are too wide for some web browsers):
                         idle, run, slash, double, fire_combo, cast (the special
                         attack without its flame pillar), hurt, death, hop_up,
                         hop_down
The packs are never edited; this only reads, cuts, recolours and draws.
"""
import random
import re

from PIL import Image, ImageDraw

from import_assets import ASSETS, PACKS
from import_story_assets import draw_glow, draw_red_moon

STORM = PACKS / "New free backgrounds part3" / "background 4"
LIGHTNING = PACKS / "Magic Pack 9 files" / "Magic Pack 9 files" / "sprites" / "Lightning"
KNIGHT = (PACKS / "Elementals_fire_knight_FREE_v1.1" / "Elementals_fire_knight_FREE_v1.1"
          / "png" / "fire_knight")
OUT = ASSETS / "rooftop"

# Kael: the cell cut out of each 288x128 frame (left, top, right, bottom).
KAEL_CELL = (60, 16, 260, 128)
COLUMNS = 8
# animation: (folder, frames used)
KAEL_SHEETS = {
    "idle": ("01_idle", None),
    "run": ("02_run", None),
    "slash": ("05_1_atk", None),
    "double": ("06_2_atk", None),
    "fire_combo": ("07_3_atk", None),
    # 0-11 he hurls fire into the sky, 15-17 embers drift down (12-14, a flame
    # pillar in front of him, are left out: the embers are the attack).
    "cast": ("08_sp_atk", list(range(0, 12)) + [15, 16, 17]),
    "hurt": ("10_take_hit", None),
    "death": ("11_death", None),
    "hop_up": ("03_jump_up", None),
    "hop_down": ("03_jump_down", None),
}

LIGHTNING_SIZE = (64, 128)
ROD_HEIGHT = 26
SPARK_COLOURS = [(150, 235, 255, 255), (235, 252, 255, 255)]


def numbered(folder) -> list:
    files = sorted(folder.glob("*.png"), key=lambda f: int(re.findall(r"(\d+)\.png", f.name)[0]))
    return [Image.open(f).convert("RGBA") for f in files]


def grid(cells: list, size: tuple) -> Image.Image:
    rows = (len(cells) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (size[0] * COLUMNS, size[1] * rows))
    for i, cell in enumerate(cells):
        sheet.paste(cell, ((i % COLUMNS) * size[0], (i // COLUMNS) * size[1]))
    return sheet


def build_sky() -> None:
    for number, name in ((1, "storm_sky"), (2, "storm_far"), (3, "storm_near")):
        Image.open(STORM / f"{number}.png").convert("RGBA").save(OUT / f"{name}.png")
    ceiling = Image.open(STORM / "4.png").convert("RGBA")
    bolts = Image.new("RGBA", ceiling.size)
    pixels, bolt_pixels = ceiling.load(), bolts.load()
    for y in range(ceiling.height):
        for x in range(ceiling.width):
            r, g, b, a = pixels[x, y]
            if a and r + g + b > 330:  # the pale bolts, not the dark cloud
                bolt_pixels[x, y] = (r, g, b, a)
                pixels[x, y] = (0, 0, 0, 0)
    ceiling.save(OUT / "storm_ceiling.png")
    bolts.save(OUT / "storm_bolts.png")
    print("storm sky: 4 layers and the bolts")


def build_moon() -> None:
    draw_red_moon(112).save(OUT / "red_moon_huge.png")
    draw_glow(200, (255, 70, 70)).save(OUT / "moon_glow_huge.png")
    print("red_moon_huge.png, moon_glow_huge.png")


def sparks(step: int) -> Image.Image:
    """Sparks crackling round the rod's tip, more and wider each frame, with a
    pulsing glow: lightning is coming."""
    image = Image.new("RGBA", LIGHTNING_SIZE)
    draw = ImageDraw.Draw(image)
    tip = (LIGHTNING_SIZE[0] // 2, LIGHTNING_SIZE[1] - ROD_HEIGHT)
    glow = 3 + step % 3
    draw.ellipse((tip[0] - glow, tip[1] - glow, tip[0] + glow, tip[1] + glow),
                 fill=(120, 220, 255, 70))
    chance = random.Random(step)
    reach = 4 + min(step, 8)
    for _ in range(3 + step // 2):
        dx, dy = chance.randint(-reach, reach), chance.randint(-reach, reach // 2)
        end = (tip[0] + dx, tip[1] + dy)
        start = (tip[0] + dx // 2, tip[1] + dy // 2)
        draw.line((start, end), fill=SPARK_COLOURS[(step + dx) % 2])
    draw.rectangle((tip[0] - 1, tip[1] - 1, tip[0] + 1, tip[1] + 1), fill=SPARK_COLOURS[step % 2])
    return image


def build_lightning() -> None:
    bolt = [Image.open(LIGHTNING / f"Lightning{i}.png").convert("RGBA") for i in range(1, 12)]
    cells = [sparks(step) for step in range(8)]
    for falling in bolt[0:4]:
        cell = sparks(8 + len(cells))
        cell.alpha_composite(falling)
        cells.append(cell)
    cells.extend(bolt[4:11])
    strip = Image.new("RGBA", (LIGHTNING_SIZE[0] * len(cells), LIGHTNING_SIZE[1]))
    for i, cell in enumerate(cells):
        strip.paste(cell, (i * LIGHTNING_SIZE[0], 0))
    strip.save(OUT / "lightning.png")

    rod = Image.new("RGBA", (9, ROD_HEIGHT + 2))
    draw = ImageDraw.Draw(rod)
    draw.rectangle((1, ROD_HEIGHT - 1, 7, ROD_HEIGHT + 1), fill=(58, 58, 70, 255))  # stone foot
    draw.line((4, 2, 4, ROD_HEIGHT - 1), fill=(44, 46, 58, 255))
    draw.line((5, 3, 5, ROD_HEIGHT - 1), fill=(96, 104, 120, 255))  # lit edge
    draw.line((3, 0, 4, 1), fill=(130, 140, 160, 255))  # the tip
    draw.point((4, 0), fill=(190, 200, 215, 255))
    rod.save(OUT / "lightning_rod.png")
    print(f"lightning.png: {len(cells)} frames; lightning_rod.png")


def build_kael() -> None:
    size = (KAEL_CELL[2] - KAEL_CELL[0], KAEL_CELL[3] - KAEL_CELL[1])
    for animation, (folder, used) in KAEL_SHEETS.items():
        frames = numbered(KNIGHT / folder)
        if used is not None:
            frames = [frames[i] for i in used]
        grid([frame.crop(KAEL_CELL) for frame in frames], size).save(OUT / f"kael_{animation}.png")
        print(f"kael_{animation}.png: {len(frames)} frames")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_sky()
    build_moon()
    build_lightning()
    build_kael()


if __name__ == "__main__":
    main()
