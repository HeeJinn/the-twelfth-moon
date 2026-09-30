"""Chapter Two art: the Lantern Forest.

Run from the project folder after the other importers:
    python tools/import_forest_assets.py

The stringstar fields tileset is made for flat ground and decoration, with
no cliff edges. For cliffs, shafts and ledges this script draws a 16 px
"mossy block" terrain set in the same palette: one tile for each of the 256
ways a cell's eight neighbours can be solid, so autotiling always finds an
exact match. It also cuts the forest decorations into props, builds a vine
ladder, and straightens the Moon Witch's vertical sheets into strips.
"""
import math
from pathlib import Path

from PIL import Image

from import_assets import ASSETS, PACKS, copy

STRINGSTAR = PACKS / "stringstar fields"
WITCH = PACKS / "Blue Witch" / "Blue_witch"
MONSTERS = PACKS / "Monster_Creatures_Fantasy(Version 1.3)" / "Monster_Creatures_Fantasy(Version 1.3)"
FOREST = ASSETS / "forest"

TILE = 16
FILL = (0, 27, 35, 255)
MOSS_DARK = (27, 38, 30, 255)
MOSS = (42, 62, 51, 255)
MOSS_LIGHT = (59, 108, 101, 255)
TEAL = (75, 138, 153, 255)
LEAF_RED = (99, 40, 42, 255)
LANTERN = (225, 185, 143)

# Neighbour bits for the 256-tile terrain atlas (tile index = mask).
N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128

# Tileset objects -> (left, top, right, bottom) in stringstar tileset.png.
PROPS = {
    "coral_tree": (165, 16, 288, 144),
    "coral_tree_small": (6, 81, 56, 144),
    "lantern_vine": (0, 32, 15, 61),
    "lantern_vine_long": (35, 32, 45, 78),
    "rock_purple": (48, 59, 80, 80),
    "red_plant": (16, 64, 31, 80),
    "bush_dark": (116, 92, 157, 112),
    "bush_wide": (73, 125, 140, 144),
    "sprout": (146, 133, 155, 144),
}
# Platform cells in tileset.png (column, row): left end, middle, right end.
PLATFORM_CELLS = [(5, 4), (7, 4), (9, 4)]
# Witch sheets are vertical strips: file -> (frame height, game name).
WITCH_SHEETS = {
    "B_witch_idle.png": (48, "idle"),
    "B_witch_run.png": (48, "run"),
    "B_witch_charge.png": (48, "charge"),
    "B_witch_attack.png": (46, "attack"),
    "B_witch_take_damage.png": (48, "hurt"),
    "B_witch_death.png": (40, "death"),
}
# Every witch frame goes on a canvas this size, her body centred at
# WITCH_BODY_X and her feet on the bottom edge, so one offset fits all.
WITCH_CANVAS = (144, 48)
WITCH_BODY_X = 40


def noise(i: int, seed: int) -> float:
    """Repeatable 0..1 value, so every tile edge has the same bumpy profile."""
    return (math.sin(i * 12.9898 + seed * 78.233) * 43758.5453) % 1.0


def terrain_tile(mask: int) -> Image.Image:
    """One 16x16 mossy block tile for a neighbour mask."""
    solid = {bit: bool(mask & bit) for bit in (N, NE, E, SE, S, SW, W, NW)}
    tile = Image.new("RGBA", (TILE, TILE), FILL)
    px = tile.load()
    # Faint speckles so large areas aren't flat. Sparse enough that the
    # 16 px repeat doesn't read as a grid.
    for y in range(TILE):
        for x in range(TILE):
            speck = noise(x * 31 + y * 17, 5)
            if speck > 0.96:
                px[x, y] = MOSS_DARK
            elif speck > 0.92:
                px[x, y] = (5, 36, 45, 255)

    def depth_from_edges(x: int, y: int) -> float:
        """Distance (px) to the nearest exposed side or corner, or 99."""
        best = 99.0
        if not solid[N]:
            best = min(best, y - noise(x, 1) * 1.2)
        if not solid[S]:
            best = min(best, (TILE - 1 - y) - noise(x, 2) * 2.0)
        if not solid[W]:
            best = min(best, x - noise(y, 3) * 2.0)
        if not solid[E]:
            best = min(best, (TILE - 1 - x) - noise(y, 4) * 2.0)
        # Inner corners: sides solid but the diagonal open.
        corners = [(NW, N, W, 0, 0), (NE, N, E, TILE - 1, 0),
                   (SW, S, W, 0, TILE - 1), (SE, S, E, TILE - 1, TILE - 1)]
        for diagonal, side_a, side_b, cx, cy in corners:
            if solid[side_a] and solid[side_b] and not solid[diagonal]:
                best = min(best, math.hypot(x - cx, y - cy) - 2.5)
        # Outer corners get rounded.
        for side_a, side_b, cx, cy in [(N, W, 0, 0), (N, E, TILE - 1, 0),
                                       (S, W, 0, TILE - 1), (S, E, TILE - 1, TILE - 1)]:
            if not solid[side_a] and not solid[side_b]:
                best = min(best, math.hypot(x - cx, y - cy) - 3.0)
        return best

    for y in range(TILE):
        for x in range(TILE):
            d = depth_from_edges(x, y)
            top_edge = not solid[N] and y <= 3
            if d < 0.0:
                px[x, y] = (0, 0, 0, 0)
            elif d < 1.0:
                px[x, y] = MOSS_LIGHT if top_edge else MOSS
            elif d < 2.2:
                if top_edge and noise(x, 7) > 0.8:
                    px[x, y] = LEAF_RED
                elif top_edge and noise(x, 8) > 0.7:
                    px[x, y] = TEAL
                else:
                    px[x, y] = MOSS if top_edge else MOSS_DARK
            elif d < 3.2 and noise(x * 3 + y, 9) > 0.55:
                px[x, y] = MOSS_DARK
    return tile


def build_terrain() -> None:
    atlas = Image.new("RGBA", (TILE * 16, TILE * 16), (0, 0, 0, 0))
    for mask in range(256):
        atlas.paste(terrain_tile(mask), ((mask % 16) * TILE, (mask // 16) * TILE))
    atlas.save(FOREST / "forest_terrain.png")


def build_platform() -> None:
    """Left end, middle, right end, single: one 16x16 tile each."""
    sheet = Image.open(STRINGSTAR / "tileset.png").convert("RGBA")
    cells = [sheet.crop((c * TILE, r * TILE, c * TILE + TILE, r * TILE + TILE))
             for c, r in PLATFORM_CELLS]
    single = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    single.paste(cells[0].crop((0, 0, 8, TILE)), (0, 0))
    single.paste(cells[2].crop((8, 0, TILE, TILE)), (8, 0))
    strip = Image.new("RGBA", (TILE * 4, TILE), (0, 0, 0, 0))
    for index, cell in enumerate(cells + [single]):
        strip.paste(cell, (index * TILE, 0))
    strip.save(FOREST / "forest_platform.png")


def build_vine_ladder() -> Image.Image:
    """A 16x16 tile of two twisting vines with leaves; stacks seamlessly."""
    tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = tile.load()
    for y in range(TILE):
        for rail, phase in ((4, 0.0), (11, 2.0)):
            x = rail + round(math.sin((y / TILE) * math.tau + phase))
            px[x, y] = MOSS_LIGHT
            px[x + 1, y] = MOSS
    for y in (3, 11):  # rungs of twisted vine
        for x in range(5, 12):
            px[x, y] = MOSS_DARK if px[x, y][3] == 0 else px[x, y]
    for x, y in ((2, 6), (13, 1), (3, 13), (14, 9), (7, 7)):
        px[x, y] = TEAL
    px[9, 14] = LEAF_RED
    return tile


def draw_glow(size: int, colour: tuple) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    centre = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x - centre, y - centre) / (size / 2)
            if distance < 1.0:
                image.putpixel((x, y), colour + (int(255 * (1.0 - distance) ** 2),))
    return image


def draw_orb() -> Image.Image:
    """The Moon Witch's floating magic orb, 10x10."""
    image = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    for y in range(10):
        for x in range(10):
            d = math.hypot(x - 4.5, y - 4.5)
            if d < 3.0:
                image.putpixel((x, y), (235, 225, 255, 255))
            elif d < 4.3:
                image.putpixel((x, y), (150, 110, 230, 255))
            elif d < 5.0:
                image.putpixel((x, y), (80, 50, 150, 200))
    return image


def build_props() -> None:
    sheet = Image.open(STRINGSTAR / "tileset.png").convert("RGBA")
    (FOREST / "props").mkdir(parents=True, exist_ok=True)
    for name, box in PROPS.items():
        sheet.crop(box).save(FOREST / "props" / f"{name}.png")


def build_witch() -> None:
    target = ASSETS / "witch"
    target.mkdir(parents=True, exist_ok=True)
    for source, (height, name) in WITCH_SHEETS.items():
        sheet = Image.open(WITCH / source).convert("RGBA")
        count = sheet.height // height
        first = sheet.crop((0, 0, sheet.width, height))
        box = first.getbbox()
        body_x = (box[0] + box[2]) // 2 if name != "attack" else 16
        strip = Image.new("RGBA", (WITCH_CANVAS[0] * count, WITCH_CANVAS[1]), (0, 0, 0, 0))
        for i in range(count):
            frame = sheet.crop((0, i * height, sheet.width, (i + 1) * height))
            x = i * WITCH_CANVAS[0] + WITCH_BODY_X - body_x
            strip.paste(frame, (x, WITCH_CANVAS[1] - height), frame)
        strip.save(target / f"witch_{name}.png")
        print(f"  witch {name}: {count} frames")


def main() -> None:
    FOREST.mkdir(parents=True, exist_ok=True)
    for i in range(3):
        copy(STRINGSTAR / f"background_{i}.png", FOREST / f"background_{i}.png")
    copy(STRINGSTAR / "!readme!.txt", FOREST / "README.txt")
    build_terrain()
    build_platform()
    build_props()
    build_vine_ladder().save(FOREST / "vine_ladder.png")
    draw_glow(24, LANTERN).save(FOREST / "glow_lantern.png")
    draw_glow(24, (170, 130, 255)).save(FOREST / "glow_violet.png")
    draw_orb().save(FOREST / "witch_orb.png")
    build_witch()
    copy(MONSTERS / "Mushroom" / "Attack3.png", ASSETS / "monster_creatures" / "mushroom_attack3.png")
    # For the Chapter Two memory: a blacksmith's forge and a bright day sky.
    gandalf = PACKS / "GandalfHardcore FREE Platformer Assets" / "GandalfHardcore FREE Platformer Assets"
    forge = Image.open(gandalf / "Pixel Art Furnace and Sawmill.png").convert("RGBA")
    forge.crop((0, 0, 384, 64)).save(ASSETS / "gandalfhardcore" / "forge_sheet.png")
    copy(PACKS / "New free backgrounds part2" / "background 1" / "orig.png", ASSETS / "skies" / "sky_day.png")
    print("forest assets done")


if __name__ == "__main__":
    main()
