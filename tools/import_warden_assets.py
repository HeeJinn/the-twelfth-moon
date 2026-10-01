"""Chapter Four's mini-boss, the Grave Warden: the Necromancer pack, straightened,
plus his Dark-Bolt and the blood creature he summons.

Run from the project folder after the other importers:
    python tools/import_warden_assets.py

Where it comes from:
  Necromancer/ (author still to be confirmed): Idle, Walk, GetHit and Death strips
  of 96x96 frames, Attack and Spawn strips of 128x128. In both sizes the body sits
  at the same place once the 128 frames are cut 16 px in from the top left, so
  every animation goes onto one 96x96 canvas (body at x 52, feet at y 64, facing
  right) and a single sprite offset fits them all.
  Magic Pack 9 (Ansimuz): the Dark-Bolt (12 frames of 64x88, ground at y 83).

Made here (assets/warden/):
  warden_<animation>.png   8 frames wide (the long strips are over 4096 px, too
                           wide for some web browsers): idle, walk, cast (Attack
                           without its beam), summon (Spawn with the blood
                           creature erased), blink (GetHit with its ghost) and
                           death (he crumbles into a pile of bones).
  blood_spawn.png          the blood creature cut out of Spawn's frames 9-18 (48x64,
                           ground on the bottom row): a blob wells up, rears up
                           into a many-legged thing, and dissolves.
  dark_bolt.png            a warning mark on the ground (drawn here in the bolt's
                           own pinks), then the bolt falls onto the mark and bursts
                           (19 frames of 64x88).
The packs are never edited; this only reads and repacks.
"""
from PIL import Image, ImageDraw

from import_assets import ASSETS, PACKS

NECRO = PACKS / "Necromancer" / "Necromancer"
BOLT = PACKS / "Magic Pack 9 files" / "Magic Pack 9 files" / "sprites" / "DarkBolt"
OUT = ASSETS / "warden"

CELL = 96
COLUMNS = 8
# animation: (file, frame size, first frame, frame count)
SHEETS = {
    "idle": ("Idle/spr_NecromancerIdle_strip50.png", 96, 0, 50),
    "walk": ("Walk/spr_NecromancerWalk_strip10.png", 96, 0, 10),
    "cast": ("Attack/spr_NecromancerAttackWithoutEffect_strip47.png", 128, 0, 47),
    "summon": ("Spawn/spr_NecromancerSpawn_strip20.png", 128, 0, 20),
    "blink": ("GetHit/spr_NecromancerGetHit_strip9.png", 96, 0, 9),
    "death": ("Death/spr_NecromancerDeath_strip52.png", 96, 0, 52),
}
# In the 128 px frames the body is 16 px further right and down than in the 96 px ones.
BIG_SHIFT = 16
# In Spawn, everything right of this column (in its 128 px frame) is the blood
# creature, not him (his staff ends at 82).
CREATURE_X = 84
CREATURE_FRAMES = range(9, 19)
CREATURE_SIZE = (48, 64)
# The creature rises around column 100 of the 128 px frame.
CREATURE_CENTRE_X = 100

BOLT_SIZE = (64, 88)
BOLT_GROUND_Y = 83
MARK_COLOURS = [(118, 38, 150, 255), (226, 98, 230, 255), (255, 186, 255, 255)]


def frames(file: str, size: int, first: int, count: int) -> list[Image.Image]:
    sheet = Image.open(NECRO / file).convert("RGBA")
    return [sheet.crop(((first + i) * size, 0, (first + i + 1) * size, size))
            for i in range(count)]


def to_cell(frame: Image.Image) -> Image.Image:
    if frame.width == CELL:
        return frame
    return frame.crop((BIG_SHIFT, BIG_SHIFT, BIG_SHIFT + CELL, BIG_SHIFT + CELL))


def grid(cells: list[Image.Image], size: tuple[int, int]) -> Image.Image:
    rows = (len(cells) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (size[0] * COLUMNS, size[1] * rows))
    for i, cell in enumerate(cells):
        sheet.paste(cell, ((i % COLUMNS) * size[0], (i // COLUMNS) * size[1]))
    return sheet


def build_warden() -> None:
    for animation, (file, size, first, count) in SHEETS.items():
        cells = []
        for frame in frames(file, size, first, count):
            if animation == "summon":
                frame = frame.copy()
                frame.paste((0, 0, 0, 0), (CREATURE_X, 0, frame.width, frame.height))
            cells.append(to_cell(frame))
        grid(cells, (CELL, CELL)).save(OUT / f"warden_{animation}.png")
        print(f"warden_{animation}.png: {count} frames")


def build_creature() -> None:
    spawn = frames("Spawn/spr_NecromancerSpawn_strip20.png", 128, 0, 20)
    width, height = CREATURE_SIZE
    strip = Image.new("RGBA", (width * len(CREATURE_FRAMES), height))
    for i, index in enumerate(CREATURE_FRAMES):
        # Columns 84-127, rows 16-79 (his feet are on row 80), centred on the creature.
        part = spawn[index].crop((CREATURE_X, 80 - height, 128, 80))
        strip.paste(part, (i * width + width // 2 - (CREATURE_CENTRE_X - CREATURE_X), 0))
    strip.save(OUT / "blood_spawn.png")
    print(f"blood_spawn.png: {len(CREATURE_FRAMES)} frames")


def mark(step: int, steps: int) -> Image.Image:
    """A flat ring on the ground that opens out and pulses: the bolt lands here."""
    image = Image.new("RGBA", BOLT_SIZE)
    draw = ImageDraw.Draw(image)
    half_width = 5 + round(8 * min(step, steps - 1) / (steps - 1))
    centre_x = BOLT_SIZE[0] // 2
    bright = MARK_COLOURS[2] if step % 2 == 0 else MARK_COLOURS[1]
    draw.ellipse((centre_x - half_width - 1, BOLT_GROUND_Y - 3,
                  centre_x + half_width + 1, BOLT_GROUND_Y + 3), outline=MARK_COLOURS[0])
    draw.ellipse((centre_x - half_width, BOLT_GROUND_Y - 2,
                  centre_x + half_width, BOLT_GROUND_Y + 2), outline=bright)
    # A mote rising from the middle, higher each frame.
    rise = 3 + step * 2
    draw.point((centre_x, BOLT_GROUND_Y - rise), fill=bright)
    return image


def build_bolt() -> None:
    bolt = [Image.open(BOLT / f"Dark-Bolt{i}.png").convert("RGBA") for i in range(1, 13)]
    marks = [mark(step, 8) for step in range(8)]
    cells = list(marks)
    for falling in bolt[0:4]:  # the bolt falls onto a mark that stays lit
        cell = marks[-1 if len(cells) % 2 == 0 else -2].copy()
        cell.alpha_composite(falling)
        cells.append(cell)
    cells.extend(bolt[4:11])  # it bursts on the ground, then fades
    strip = Image.new("RGBA", (BOLT_SIZE[0] * len(cells), BOLT_SIZE[1]))
    for i, cell in enumerate(cells):
        strip.paste(cell, (i * BOLT_SIZE[0], 0))
    strip.save(OUT / "dark_bolt.png")
    print(f"dark_bolt.png: {len(cells)} frames")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_warden()
    build_creature()
    build_bolt()


if __name__ == "__main__":
    main()
