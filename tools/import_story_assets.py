"""Chapter One story art: villagers, village decor, Kael, effects, and a few
small pieces drawn here (moon shard, red moon, talk bubble, butterfly...).

Run from the project folder after tools/import_assets.py:
    python tools/import_story_assets.py

Like import_assets.py, it never edits the packs one folder up. Villagers are
built by stacking the GandalfHardcore character layers (skin, clothes, hair)
into one 800x448 sheet per villager, the same layout as the source layers.
"""
import math
from pathlib import Path

from PIL import Image

from import_assets import ASSETS, GANDALF, PACKS, copy, frame_key

CHARACTERS = PACKS / "GandalfHardcore FREE Character Asset Pack" / "GandalfHardcore Character Asset Pack"
FIRE_KNIGHT = (PACKS / "Elementals_fire_knight_FREE_v1.1" / "Elementals_fire_knight_FREE_v1.1"
               / "png" / "fire_knight")
EFFECTS = (PACKS / "Super Pixel Effects Gigapack (Free Version) v2.7.0"
           / "Super Pixel Effects Gigapack (Free Version)")

# Villager -> layers bottom to top. "grey:" recolors that layer to silver hair.
VILLAGERS = {
    "tomas": ["Character skin colors/Male Skin2.png", "Male Clothing/Pants.png",
              "Male Clothing/Shoes.png", "Male Clothing/Purple Shirt v2.png",
              "grey:Male Hair/Male Hair2.png"],
    "rosa": ["Character skin colors/Female Skin3.png", "Female Clothing/Skirt.png",
             "Female Clothing/Boots.png", "Female Clothing/Green Corset v2.png",
             "Female Hair/Female Hair3.png"],
    "lina": ["Character skin colors/Female Skin1.png", "Female Clothing/Skirt.png",
             "Female Clothing/Boots.png", "Female Clothing/Blue Corset v2.png",
             "Female Hair/Female Hair4.png"],
    "mara": ["Character skin colors/Female Skin2.png", "Female Clothing/Skirt.png",
             "Female Clothing/Boots.png", "Female Clothing/Purple Corset v2.png",
             "grey:Female Hair/Female Hair1.png"],
    "joss": ["Character skin colors/Male Skin4.png", "Male Clothing/Pants.png",
             "Male Clothing/Shoes.png", "Male Clothing/orange Shirt v2.png",
             "Male Hair/Male Hair4.png"],
    "bram": ["Character skin colors/Male Skin5.png", "Male Clothing/Blue Pants.png",
             "Male Clothing/Boots.png", "Male Clothing/Blue Shirt v2.png",
             "Male Hair/Male Hair5.png", "Male Hand/Male Sword.png"],
    "theo": ["Character skin colors/Male Skin3.png", "Male Clothing/Green Pants.png",
             "Male Clothing/Boots.png", "Male Clothing/Green Shirt v2.png",
             "Male Hair/Male Hair1.png"],
    # Chapter Two: Wren the lantern keeper and Pell, a nervous traveller.
    "wren": ["Character skin colors/Female Skin4.png", "Female Clothing/Skirt.png",
             "Female Clothing/Boots.png", "Female Clothing/Orange Corset v2.png",
             "Female Hair/Female Hair5.png"],
    "pell": ["Character skin colors/Male Skin1.png", "Male Clothing/Purple Pants.png",
             "Male Clothing/Boots.png", "Male Clothing/Shirt v2.png",
             "Male Hair/Male Hair3.png"],
    # Chapter Three: Hild the shepherdess.
    "hild": ["Character skin colors/Female Skin5.png", "Female Clothing/Skirt.png",
             "Female Clothing/Boots.png", "Female Clothing/Green Corset.png",
             "Female Hair/Female Hair1.png"],
    # Past lives, for the prologue: she has brown hair like Mariane, he has
    # dark hair like Kael.
    "past_girl": ["Character skin colors/Female Skin2.png", "Female Clothing/Skirt.png",
                  "Female Clothing/Boots.png", "Female Clothing/Corset v2.png",
                  "Female Hair/Female Hair2.png"],
    "past_boy": ["Character skin colors/Male Skin2.png", "Male Clothing/Pants.png",
                 "Male Clothing/Boots.png", "Male Clothing/Shirt v2.png",
                 "Male Hair/Male Hair1.png"],
}

# Decor.png object -> (left, top, right, bottom), found by tools on the sheet.
DECOR = {
    "crate": (2, 16, 29, 32),
    "crates": (34, 0, 61, 32),
    "barrel": (73, 14, 88, 32),
    "barrels": (98, 14, 127, 32),
    "chopping_block": (231, 11, 252, 32),
    "apples": (354, 14, 382, 32),
    "apple_stand": (267, 34, 306, 64),
    "basket": (360, 49, 377, 64),
    "log_pile": (201, 75, 248, 96),
    "pumpkin": (390, 113, 409, 128),
    "wheat_bundle": (288, 139, 352, 192),
    "rocks": (41, 210, 87, 224),
    "scarecrow": (300, 197, 340, 256),
    "rocks_big": (4, 280, 92, 320),
    "laundry": (27, 354, 133, 416),
    "bush": (3, 424, 60, 448),
    "bush_small": (64, 431, 96, 448),
}
GARDEN = {
    "flower_pot_purple": (36, 7, 59, 32),
    "flower_pot_green": (37, 36, 58, 64),
}
GANDALF_EXTRA = {
    "Cooking area.png": "cooking_stall_sheet.png",
    "Large Tent.png": "tent_large.png",
    "Small Tent.png": "tent_small.png",
    "birds1.png": "sky/birds_1.png",
    "birds2.png": "sky/birds_2.png",
    "cloud1.png": "sky/cloud_1.png",
    "cloud2.png": "sky/cloud_2.png",
    "cloud3.png": "sky/cloud_3.png",
    "cloud4.png": "sky/cloud_4.png",
    "cloud5.png": "sky/cloud_5.png",
    "cloud6.png": "sky/cloud_6.png",
    "sun.png": "sky/sun.png",
    "hot air balloon.png": "sky/hot_air_balloon.png",
}
FIRE_KNIGHT_ANIMATIONS = {"01_idle": "idle", "02_run": "run", "08_sp_atk": "special"}
# Effect folder (inside spritesheet/<category>/) -> game name.
EFFECT_STRIPS = {
    "Explosions/epic_explosion_001/epic_explosion_001_small_orange": "fire_burst",
    "Explosions/symmetrical_explosion_001/symmetrical_explosion_001_small_orange": "fire_puff",
    "Fantasy Spells/spell_absorb_001/spell_absorb_001_small_violet": "moon_absorb",
    "Fantasy Spells/status_sparkling_001/status_sparkling_001_small_yellow": "sparkle",
    "Magic Bursts/round_sparkle_burst_003/round_sparkle_burst_003_small_red": "shard_burst",
    "Smoke Bursts/symmetrical_smoke_burst_001/symmetrical_smoke_burst_001_small_brown": "dust_puff",
}


def load_layer(name: str) -> Image.Image:
    grey = name.startswith("grey:")
    image = Image.open(CHARACTERS / name.removeprefix("grey:")).convert("RGBA")
    if not grey:
        return image
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a:
                light = int(0.3 * r + 0.59 * g + 0.11 * b)
                value = min(255, 120 + int(light * 0.75))
                pixels[x, y] = (value, value, min(255, value + 8), a)
    return image


def build_villagers() -> None:
    target_dir = ASSETS / "villagers"
    target_dir.mkdir(parents=True, exist_ok=True)
    for name, layers in VILLAGERS.items():
        sheet = None
        for layer in layers:
            image = load_layer(layer)
            sheet = image if sheet is None else Image.alpha_composite(sheet, image)
        sheet.save(target_dir / f"{name}.png")
    copy(CHARACTERS / "READ ME.txt", target_dir / "LICENSE.txt")


def crop_decor() -> None:
    target_dir = ASSETS / "gandalfhardcore" / "decor"
    target_dir.mkdir(parents=True, exist_ok=True)
    decor = Image.open(GANDALF / "Decor.png").convert("RGBA")
    for name, box in DECOR.items():
        decor.crop(box).save(target_dir / f"{name}.png")
    garden = Image.open(GANDALF / "Garden Decorations.png").convert("RGBA")
    for name, box in GARDEN.items():
        garden.crop(box).save(target_dir / f"{name}.png")
    for source, target in GANDALF_EXTRA.items():
        copy(GANDALF / source, ASSETS / "gandalfhardcore" / target)


def compose_houses() -> None:
    """House Tiles.png is a kit: the attic face, part of the ground-floor
    wall and the foundation are left open, to be filled with its repeating
    brick. Fill them so each house stands as one finished picture."""
    source = Image.open(GANDALF / "House Tiles.png").convert("RGBA")
    tile = 16

    def cell(image: Image.Image, cx: int, cy: int) -> Image.Image:
        return image.crop((cx * tile, cy * tile, cx * tile + tile, cy * tile + tile))

    for variant, first_column in (("house_a", 0), ("house_b", 14)):
        house = source.crop((first_column * tile, 0, first_column * tile + 14 * tile, 14 * tile))
        back = Image.new("RGBA", house.size, (0, 0, 0, 0))
        gable, wall = cell(house, 5, 3), cell(house, 4, 10)
        base_top, base = cell(house, 4, 12), cell(house, 4, 13)
        for cy in (4, 5):
            for cx in range(4, 10):
                back.paste(gable, (cx * tile, cy * tile))
        for cx in range(6, 10):
            back.paste(base_top, (cx * tile, 12 * tile))
            back.paste(base, (cx * tile, 13 * tile))
        back.alpha_composite(house)
        # Any see-through pixel left inside the walls becomes brick.
        px, brick = back.load(), wall.load()
        for y in range(6 * tile, 12 * tile):
            for x in range(2 * tile, 12 * tile):
                r, g, b, a = px[x, y]
                if a < 255:
                    w = brick[x % tile, y % tile]
                    k = a / 255
                    px[x, y] = (int(r * k + w[0] * (1 - k)), int(g * k + w[1] * (1 - k)),
                                int(b * k + w[2] * (1 - k)), 255)
        back.save(ASSETS / "gandalfhardcore" / f"{variant}.png")


def copy_fire_knight() -> None:
    target_dir = ASSETS / "fire_knight"
    for source, anim in FIRE_KNIGHT_ANIMATIONS.items():
        frames = sorted((FIRE_KNIGHT / source).glob("*.png"), key=frame_key)
        for index, frame in enumerate(frames):
            copy(frame, target_dir / anim / f"fire_knight_{anim}_{index:02d}.png")


def build_effect_strips() -> None:
    """Each effect becomes one horizontal strip; prints its frame size."""
    target_dir = ASSETS / "effects"
    target_dir.mkdir(parents=True, exist_ok=True)
    for folder, name in EFFECT_STRIPS.items():
        source_dir = EFFECTS / "spritesheet" / folder
        sheet = Image.open(source_dir / "spritesheet.png").convert("RGBA")
        rects = []
        for line in (source_dir / "spritesheet.txt").read_text().splitlines():
            if "=" in line:
                rects.append([int(v) for v in line.split("=")[1].split()])
        width, height = rects[0][2], rects[0][3]
        strip = Image.new("RGBA", (width * len(rects), height), (0, 0, 0, 0))
        for index, (x, y, w, h) in enumerate(rects):
            strip.paste(sheet.crop((x, y, x + w, y + h)), (index * width, 0))
        strip.save(target_dir / f"{name}.png")
        print(f"  effect {name}: {len(rects)} frames of {width}x{height}")
    copy(EFFECTS / "license.txt", target_dir / "LICENSE.txt")


def draw_moon_shard() -> Image.Image:
    """A small pale crystal with a red core, 11x15."""
    rows = [
        ".....O.....",
        "....OWO....",
        "...OWWPO...",
        "...OWPPO...",
        "..OWWPRPO..",
        "..OWPPRPO..",
        ".OWWPRRRPO.",
        ".OWPPRRRPO.",
        ".OWPPRRRPO.",
        "..OWPRRPO..",
        "..OWPPRPO..",
        "...OWPPO...",
        "...OPPPO...",
        "....OPO....",
        ".....O.....",
    ]
    colours = {"O": (120, 30, 50, 255), "W": (255, 240, 245, 255),
               "P": (255, 170, 190, 255), "R": (225, 60, 80, 255)}
    return draw_rows(rows, colours)


def draw_red_moon(size: int = 40) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    centre = (size - 1) / 2
    radius = size / 2 - 1
    craters = [(0.3, 0.35, 0.16), (0.62, 0.55, 0.12), (0.42, 0.7, 0.09), (0.7, 0.28, 0.07)]
    for y in range(size):
        for x in range(size):
            dx, dy = x - centre, y - centre
            if dx * dx + dy * dy > radius * radius:
                continue
            # Lit from the upper left.
            light = 1.0 - ((dx + dy) / (2 * radius) + 0.5) * 0.55
            colour = (int(235 * light + 20), int(70 * light + 20), int(70 * light + 25))
            for cx, cy, cr in craters:
                if (x / size - cx) ** 2 + (y / size - cy) ** 2 < cr * cr:
                    colour = tuple(int(c * 0.78) for c in colour)
            image.putpixel((x, y), colour + (255,))
    return image


def draw_glow(size: int, colour: tuple) -> Image.Image:
    """A soft round glow, strongest in the middle."""
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    centre = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x - centre, y - centre) / (size / 2)
            if distance < 1.0:
                alpha = int(255 * (1.0 - distance) ** 2)
                image.putpixel((x, y), colour + (alpha,))
    return image


def draw_rows(rows: list, colours: dict) -> Image.Image:
    image = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char in colours:
                image.putpixel((x, y), colours[char])
    return image


def draw_small_pieces() -> None:
    target_dir = ASSETS / "generated"
    draw_moon_shard().save(target_dir / "moon_shard.png")
    draw_red_moon(40).save(target_dir / "red_moon.png")
    draw_red_moon(14).save(target_dir / "red_moon_small.png")
    draw_glow(32, (255, 120, 140)).save(target_dir / "glow_pink.png")
    draw_glow(96, (255, 60, 70)).save(target_dir / "glow_red.png")
    ink = {"O": (40, 26, 44, 255), "W": (255, 255, 255, 255), "D": (40, 26, 44, 255)}
    draw_rows([
        ".OOOOOOOOO.",
        "OWWWWWWWWWO",
        "OWDWWDWWDWO",
        "OWWWWWWWWWO",
        ".OOOWWOOOO.",
        "...OWO.....",
        "...OO......",
    ], ink).save(target_dir / "talk_bubble.png")
    draw_rows([
        "WWWWWWW",
        ".WWWWW.",
        "..WWW..",
        "...W...",
    ], {"W": (255, 214, 230, 255)}).save(target_dir / "dialogue_arrow.png")
    draw_rows(["PP.", "PPP", ".P."], {"P": (250, 175, 205, 255)}).save(
        target_dir / "petal_particle.png")
    # Butterfly: two frames side by side, wings open then folded.
    wing = {"O": (60, 40, 60, 255), "W": (255, 255, 255, 255)}
    open_frame = draw_rows(["WW.WW", "WWOWW", ".WOW.", "W.O.W"], wing)
    closed_frame = draw_rows(["..W..", ".WOW.", "..O..", "..O.."], wing)
    butterfly = Image.new("RGBA", (10, 4), (0, 0, 0, 0))
    butterfly.paste(open_frame, (0, 0))
    butterfly.paste(closed_frame, (5, 0))
    butterfly.save(target_dir / "butterfly.png")
    copy(PACKS / "New free backgrounds part1" / "background 1" / "orig.png",
         ASSETS / "skies" / "sky_night.png")


if __name__ == "__main__":
    build_villagers()
    crop_decor()
    compose_houses()
    copy_fire_knight()
    build_effect_strips()
    draw_small_pieces()
    print("story assets done")
