"""Copy the source art the game uses into res://assets and draw the few small
pieces no pack provides (petal, hearts, moons, bridge plank).

Run from the project folder with Pillow installed:
    python tools/import_assets.py

The asset packs live one folder up (GameDevAsset/). They are never edited;
this script only copies them under snake_case names and prints the numbers
(sprite bounds) the scenes need.
"""
import math
import shutil
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
PACKS = PROJECT.parent
ASSETS = PROJECT / "assets"

GANDALF = PACKS / "GandalfHardcore FREE Platformer Assets" / "GandalfHardcore FREE Platformer Assets"
HEROINE = PACKS / "Characters PackV2" / "Characters PackV2" / "WarriorWoman"
MAGIC = PACKS / "Magic Pack 9 files" / "Magic Pack 9 files"
MONSTERS = PACKS / "Monster_Creatures_Fantasy(Version 1.3)" / "Monster_Creatures_Fantasy(Version 1.3)"

# Mariane is the Warrior Woman from Dreamir's Characters Pack. Every sheet is
# one row of 80x64 frames with her feet at y = 48 and her body at x = 44, so
# the sheets are copied as they are. AttackCombo and JumpAttack are left
# out: they are pixel for pixel Attack1+2+3 and JumpAttack1+2 joined, which
# the game already plays in a row as its ground and air combos.
HEROINE_SHEETS = [
    "Idle", "Idle2", "Walk", "Run", "Jump", "Crouch", "CrouchAttack", "Slide",
    "Attack1", "Attack2", "Attack3", "JumpAttack1", "JumpAttack2", "Block",
    "IdleBlock", "Hit", "Death", "GettingUp", "HPRecovery", "MPRecovery",
    "Spell", "Spell2", "LadderClimb", "WallHang", "WallClimb",
]
HEROINE_LICENSE = """Mariane: "Warrior Woman" from Characters Pack by Dreamir
https://dreamir.itch.io/characters-pack

Free for personal and commercial projects, may be modified.
Credit is not required but appreciated (it is in the game's credits).
"""
# The glowing colours of her sword during the Moon Slash (Spell frame 10).
MOON_GLOW = {(127, 241, 245), (66, 206, 235), (186, 245, 239)}
MAGIC_LICENSE = """Magic Pack 9 by Luis Zuno (Ansimuz), https://ansimuz.com
Free for personal and commercial projects, may be modified.
Not to be redistributed or resold as standalone assets.
"""

# Village props: source file -> game file.
GANDALF_FILES = {
    "Floor Tiles1.png": "floor_tiles.png",
    "Animated Sprites/Campfire sheet.png": "campfire_sheet.png",
    "Flowering Tree.png": "flowering_tree.png",
    "Tree1.png": "tree_1.png",
    "Tree2.png": "tree_2.png",
    "Weeping Willow1.png": "weeping_willow.png",
    "House Tiles.png": "house_tiles.png",
    "Angel Statue.png": "angel_statue.png",
    "Tall Grass.png": "tall_grass.png",
    "READ ME.txt": "LICENSE.txt",
}


def frame_key(path: Path) -> int:
    digits = "".join(c for c in path.stem if c.isdigit())
    return int(digits) if digits else 0


def copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def snake_case(name: str) -> str:
    """"HPRecovery" -> "hp_recovery", "JumpAttack1" -> "jump_attack_1"."""
    out = ""
    for i, char in enumerate(name):
        previous = name[i - 1] if i else ""
        following = name[i + 1] if i + 1 < len(name) else ""
        starts_word = char.isupper() and previous and (previous.islower() or following.islower())
        if (starts_word or (char.isdigit() and not previous.isdigit())) and i:
            out += "_"
        out += char.lower()
    return out


def copy_heroine() -> None:
    target_dir = ASSETS / "heroine"
    target_dir.mkdir(parents=True, exist_ok=True)
    for sheet in HEROINE_SHEETS:
        copy(HEROINE / f"WarriorWoman{sheet}.png", target_dir / f"{snake_case(sheet)}.png")
    (target_dir / "LICENSE.txt").write_text(HEROINE_LICENSE)


def draw_moon_wave() -> Image.Image:
    """The crescent of light her sword leaves in the Moon Slash, cut out of
    the Spell sheet (frame 10) so it can fly on as its own sprite."""
    sheet = Image.open(HEROINE / "WarriorWomanSpell.png").convert("RGBA")
    frame = sheet.crop((10 * 80, 0, 11 * 80, 64))
    wave = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    for y in range(frame.height):
        for x in range(52, frame.width):  # Right of her hands.
            pixel = frame.getpixel((x, y))
            if pixel[3] and pixel[:3] in MOON_GLOW:
                wave.putpixel((x, y), pixel)
    return wave.crop(wave.getbbox())


def copy_magic() -> None:
    target_dir = ASSETS / "magic"
    target_dir.mkdir(parents=True, exist_ok=True)
    # Moon Spark: a ball of light (frames 0-2) that bursts (3-6). 32x32.
    copy(MAGIC / "spritesheets" / "spark.png", target_dir / "spark.png")
    (target_dir / "LICENSE.txt").write_text(MAGIC_LICENSE)
    draw_moon_wave().save(target_dir / "moon_wave.png")


def copy_gandalf() -> None:
    target_dir = ASSETS / "gandalfhardcore"
    for source_name, target_name in GANDALF_FILES.items():
        copy(GANDALF / source_name, target_dir / target_name)
    layers = GANDALF / "GandalfHardcore Background layers" / "Normal BG"
    for i in range(1, 6):
        copy(layers / f"GandalfHardcore Background layers_layer {i}.png",
             target_dir / "background" / f"village_layer_{i}.png")


def copy_misc() -> None:
    copy(MONSTERS / "Goblin" / "Attack3.png", ASSETS / "monster_creatures" / "goblin_attack3.png")
    # Everything the monster pack has, used by the attacks: each monster's
    # "Attack3" sheet and its projectile sheet (bomb, spores, sword, spit).
    for monster, projectile in (("Goblin", "Bomb_sprite.png"), ("Mushroom", "Projectile_sprite.png"),
                                ("Skeleton", "Sword_sprite.png"), ("Flying eye", "projectile_sprite.png")):
        name = monster.lower().replace(" ", "_")
        copy(MONSTERS / monster / "Attack3.png", ASSETS / "monster_creatures" / f"{name}_attack3.png")
        copy(MONSTERS / monster / projectile, ASSETS / "monster_creatures" / f"{name}_projectile.png")
    copy(PACKS / "New free backgrounds part1" / "background 2" / "orig.png",
         ASSETS / "skies" / "sky_pink.png")
    copy(PACKS / "New free backgrounds part1" / "license.txt", ASSETS / "skies" / "LICENSE.txt")
    copy(PACKS / "pixelmax" / "Pixelmax-Regular.otf", ASSETS / "fonts" / "pixelmax_regular.otf")
    copy(PACKS / "pixelmax" / "Pixelmax-Outline.otf", ASSETS / "fonts" / "pixelmax_outline.otf")


def draw_petal() -> Image.Image:
    """A small five-petal blossom, 15x15, drawn from circles."""
    size = 15
    center = (size - 1) / 2
    fill = set()
    for y in range(size):
        for x in range(size):
            for k in range(5):
                angle = math.radians(-90 + 72 * k)
                px = center + 3.7 * math.cos(angle)
                py = center + 3.7 * math.sin(angle)
                if (x - px) ** 2 + (y - py) ** 2 <= 2.5 ** 2:
                    fill.add((x, y))
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    outline = (138, 59, 92, 255)
    petal = (247, 168, 200, 255)
    light = (255, 224, 238, 255)
    for (x, y) in fill:
        shade = light if (x - center) + (y - center) < -3 else petal
        image.putpixel((x, y), shade)
    for y in range(size):
        for x in range(size):
            if (x, y) in fill:
                continue
            neighbours = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if any(n in fill for n in neighbours):
                image.putpixel((x, y), outline)
    for (x, y) in [(7, 7), (6, 7), (8, 7), (7, 6), (7, 8)]:
        image.putpixel((x, y), (255, 209, 102, 255))
    image.putpixel((7, 7), (232, 163, 61, 255))
    return image


HEART = [
    ".OO...OO.",
    "OHHO.OFFO",
    "OHFFOFFFO",
    "OFFFFFFFO",
    ".OFFFFFO.",
    "..OFFFO..",
    "...OFO...",
    "....O....",
]


def draw_heart(full: bool) -> Image.Image:
    image = Image.new("RGBA", (len(HEART[0]), len(HEART)), (0, 0, 0, 0))
    colours = {
        "O": (62, 31, 43, 255),
        "F": (228, 59, 68, 255) if full else (90, 48, 64, 200),
        "H": (255, 139, 139, 255) if full else (90, 48, 64, 200),
    }
    for y, row in enumerate(HEART):
        for x, char in enumerate(row):
            if char in colours:
                image.putpixel((x, y), colours[char])
    return image


MOON = [
    "..OOO..",
    ".OFFO..",
    "OFFO...",
    "OFFO...",
    "OFFO...",
    ".OFFO..",
    "..OOO..",
]


def draw_moon(full: bool) -> Image.Image:
    """A small crescent for the moonlight meter (Moon Spark charges)."""
    image = Image.new("RGBA", (len(MOON[0]), len(MOON)), (0, 0, 0, 0))
    colours = {
        "O": (40, 44, 84, 255),
        "F": (150, 238, 245, 255) if full else (70, 78, 120, 200),
    }
    for y, row in enumerate(MOON):
        for x, char in enumerate(row):
            if char in colours:
                image.putpixel((x, y), colours[char])
    return image


def draw_plank() -> Image.Image:
    """One 32x32 tile with a wooden bridge plank along its top edge."""
    sheet = Image.open(GANDALF / "Other Tiles1.png").convert("RGBA")
    plank = sheet.crop((32, 192, 64, 198))
    tile = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    tile.paste(plank, (0, 0))
    return tile


def make_generated() -> None:
    target_dir = ASSETS / "generated"
    target_dir.mkdir(parents=True, exist_ok=True)
    draw_petal().save(target_dir / "petal.png")
    draw_heart(True).save(target_dir / "heart_full.png")
    draw_heart(False).save(target_dir / "heart_empty.png")
    draw_moon(True).save(target_dir / "moon_full.png")
    draw_moon(False).save(target_dir / "moon_empty.png")
    draw_plank().save(target_dir / "village_plank.png")


def report_bounds() -> None:
    """Print the opaque bounds the scenes use to put each sprite's feet at y = 0."""
    print("village props (size, bbox):")
    for name in ["flowering_tree", "tree_1", "tree_2", "weeping_willow", "angel_statue", "tall_grass"]:
        image = Image.open(ASSETS / "gandalfhardcore" / f"{name}.png")
        print(f"  {name}: {image.size} {image.getbbox()}")
    house = Image.open(ASSETS / "gandalfhardcore" / "house_tiles.png")
    print(f"  house left half: {house.crop((0, 0, 224, 224)).getbbox()}")
    goblin = Image.open(ASSETS / "monster_creatures" / "goblin_attack3.png")
    boxes = [goblin.crop((i * 150, 0, i * 150 + 150, 150)).getbbox() for i in range(6)]
    print(f"  goblin frames 0-5 bboxes: {boxes}")


if __name__ == "__main__":
    copy_heroine()
    copy_magic()
    copy_gandalf()
    copy_misc()
    make_generated()
    report_bounds()
