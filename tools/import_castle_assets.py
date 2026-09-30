"""Chapter Four art: Ember Keep, the castle.

Run from the project folder after the other importers:
    python tools/import_castle_assets.py            # writes assets/castle/
    python tools/import_castle_assets.py --preview  # also a test picture next to it

Where it comes from:
  Pixel2DCastle1.1 (Szadi art): ground.png (16 px stone floor pieces), env_objects.png
  (gothic windows, arches, columns), and the animated lights anim_light1/2/3 and
  anim_lights (hanging lanterns, braziers, chandeliers, wall lamps, candles).

What it makes:
  castle_terrain.png   16x16 stone block, one tile for each of the 256 ways a
                       cell's eight neighbours can be solid (like the forest's
                       terrain), so autotiling always finds an exact match. The
                       pack's grey stone lip with hanging stones is the top edge,
                       its carved side pieces are the left and right edges, and
                       its dark brick fill is the inside.
  castle_platform.png  a one-way stone ledge: left end, middle, right end, single.
  window_*.png         gothic windows with the red moon shining through, for the
                       "red moon grows bigger in the windows" of the story.
  lantern / brazier / chandelier / sconce_* / candles  strips of the animated lights.
  castle_wall.png      a dim plum-coloured brick wall, 96x288, for the backdrop behind
                       the stone (drawn here: the pack's wall sheets are lit panels
                       that do not tile).
  castle_vignette.png  a screen-sized soft dark edge, to keep the eye on the middle.
  castle_lift.png      the moving stone lift: the ledge's left end, three middles and right end.
  ember_grate.png      a small iron floor grate with glowing embers under it, drawn here: the
                       mark of an ember vent, so it can be seen while it sleeps.
  fire_bomb.png        Magic Pack 9's Fire-bomb (a shrinking blue ring, a spark, then a
                       dome of fire), copied whole: the ember vents use it, and so will
                       Kael's falling embers later.
The pack is never edited; this only copies, crops, recolours and repacks.
"""
import math
import random
import shutil
import sys

from PIL import Image

from import_assets import ASSETS, PACKS

CASTLE = PACKS / "Pixel2DCastle1.1"
OUT = ASSETS / "castle"
TILE = 16

# Neighbour bits for the 256-tile terrain atlas (tile index = mask). The same
# order as the forest's: N, NE, E, SE, S, SW, W, NW.
N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128

GROUND = Image.open(CASTLE / "ground.png").convert("RGBA")
ENV = Image.open(CASTLE / "env_objects.png").convert("RGBA")


def cell(column: int, row: int) -> Image.Image:
    return GROUND.crop((column * TILE, row * TILE, (column + 1) * TILE, (row + 1) * TILE))


# The pieces of the pack's floor block (see ground.png): the lip of light
# stones sits in the bottom four rows of row 0, the body with hanging stones
# below it in row 1, the carved sides are (0, 1) and (8, 1).
LIP_TOP_ROW = 12
FILL = cell(1, 4)
TOP_LIP = cell(2, 0)
TOP_BODY = cell(2, 1)
SIDE_LEFT = cell(0, 1)
SIDE_RIGHT = cell(8, 1)


def top_edge() -> Image.Image:
    """The lip and the hanging stones under it, as the top 16 rows of a tile."""
    piece = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    piece.paste(TOP_LIP.crop((0, LIP_TOP_ROW, TILE, TILE)), (0, 0))
    piece.paste(TOP_BODY.crop((0, 0, TILE, TILE - (TILE - LIP_TOP_ROW))), (0, TILE - LIP_TOP_ROW))
    return piece


def terrain_tile(mask: int) -> Image.Image:
    solid = {bit: bool(mask & bit) for bit in (N, NE, E, SE, S, SW, W, NW)}
    tile = FILL.copy()
    top = top_edge()
    if not solid[N]:
        tile.alpha_composite(top.crop((0, 0, TILE, 9)), (0, 0))
    if not solid[S]:
        # A ceiling: the lip turned upside down along the bottom.
        lip = top.crop((0, 0, TILE, 4)).transpose(Image.FLIP_TOP_BOTTOM)
        tile.alpha_composite(lip, (0, TILE - 4))
    if not solid[W]:
        tile.alpha_composite(SIDE_LEFT.crop((0, 0, 5, TILE)), (0, 0))
    if not solid[E]:
        tile.alpha_composite(SIDE_RIGHT.crop((TILE - 5, 0, TILE, TILE)), (TILE - 5, 0))
    # Outer corners get a rounded nick, and inner corners a small shadow.
    px = tile.load()
    for side_a, side_b, cx, cy in [(N, W, 0, 0), (N, E, TILE - 1, 0),
                                   (S, W, 0, TILE - 1), (S, E, TILE - 1, TILE - 1)]:
        if not solid[side_a] and not solid[side_b]:
            px[cx, cy] = (0, 0, 0, 0)
    return tile


def build_terrain() -> Image.Image:
    atlas = Image.new("RGBA", (TILE * 16, TILE * 16), (0, 0, 0, 0))
    for mask in range(256):
        atlas.paste(terrain_tile(mask), ((mask % 16) * TILE, (mask // 16) * TILE))
    atlas.save(OUT / "castle_terrain.png")
    return atlas


def build_platform() -> None:
    """Left end, middle, right end, single: a slab of the floor's lip, 16x16 each."""
    top = top_edge()
    middle = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    middle.paste(top.crop((0, 0, TILE, 9)), (0, 0))
    left = middle.copy()
    left.alpha_composite(SIDE_LEFT.crop((0, 0, 4, 9)), (0, 0))
    right = middle.copy()
    right.alpha_composite(SIDE_RIGHT.crop((TILE - 4, 0, TILE, 9)), (TILE - 4, 0))
    single = left.copy()
    single.alpha_composite(SIDE_RIGHT.crop((TILE - 4, 0, TILE, 9)), (TILE - 4, 0))
    strip = Image.new("RGBA", (TILE * 4, TILE), (0, 0, 0, 0))
    for index, piece in enumerate([left, middle, right, single]):
        strip.paste(piece, (index * TILE, 0))
    strip.save(OUT / "castle_platform.png")


# Gothic windows on env_objects.png, (left, top, right, bottom).
WINDOWS = {
    "window_tall": (0, 256, 44, 304),
    "window_arch": (48, 256, 96, 320),
    "window_twin": (98, 256, 144, 320),
}
RED_NIGHT = [(38, 8, 20), (58, 10, 26), (84, 14, 32)]
MOON = [(214, 76, 70), (184, 52, 56), (150, 36, 48)]


def build_windows() -> None:
    """Each window with a dark red night and a big red moon behind its opening."""
    for name, box in WINDOWS.items():
        frame = ENV.crop(box)
        width, height = frame.size
        panel = Image.new("RGBA", (width, height), RED_NIGHT[0] + (255,))
        px = panel.load()
        for y in range(height):
            shade = RED_NIGHT[min(2, y * 3 // height)]
            for x in range(width):
                px[x, y] = shade + (255,)
        # The moon, low and large, so the window frames a piece of it.
        cx, cy, radius = width * 0.55, height * 0.62, min(width, height) * 0.42
        for y in range(height):
            for x in range(width):
                distance = math.hypot(x - cx, y - cy)
                if distance < radius:
                    px[x, y] = MOON[0 if distance < radius * 0.55 else 1 if distance < radius * 0.85 else 2] + (255,)
        panel.alpha_composite(frame)
        # Only keep what the window frame covers or shows through.
        mask = Image.new("L", (width, height), 0)
        mask_px = mask.load()
        frame_px = frame.load()
        for y in range(height):
            for x in range(width):
                mask_px[x, y] = 255 if frame_px[x, y][3] or _inside(frame, x, y) else 0
        result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        result.paste(panel, (0, 0), mask)
        result.save(OUT / f"{name}.png")


def _inside(frame: Image.Image, x: int, y: int) -> bool:
    """True for transparent pixels with frame on the left, right and above: the opening."""
    if frame.getpixel((x, y))[3]:
        return False
    left = any(frame.getpixel((i, y))[3] for i in range(0, x))
    right = any(frame.getpixel((i, y))[3] for i in range(x + 1, frame.width))
    above = any(frame.getpixel((x, j))[3] for j in range(0, y))
    return left and right and above


# Animated lights: file -> [(output name, left, top, frame width, frame height, frames)].
LIGHTS = {
    "anim_light1.png": [("lantern", 0, 0, 48, 32, 6)],
    "anim_light2.png": [("brazier", 0, 0, 32, 16, 4)],
    "anim_light3.png": [("chandelier", 0, 0, 64, 64, 5)],
    "anim_lights.png": [
        ("sconce_a", 0, 0, 16, 16, 3), ("sconce_b", 0, 16, 16, 16, 3),
        ("sconce_c", 0, 32, 16, 16, 3), ("sconce_d", 0, 48, 16, 16, 3),
        ("candles", 0, 64, 16, 16, 3), ("gold_brazier", 0, 80, 16, 16, 4),
    ],
}


def build_lights() -> None:
    for file_name, strips in LIGHTS.items():
        sheet = Image.open(CASTLE / file_name).convert("RGBA")
        for name, left, top, width, height, count in strips:
            strip = sheet.crop((left, top, left + width * count, top + height))
            strip.save(OUT / f"{name}.png")


def build_wall() -> None:
    """Staggered bricks, 16x8 each, in dim plums, with a few darker and lighter ones."""
    rng = random.Random(4)
    mortar = (22, 12, 26, 255)
    shades = [(48, 31, 46, 255), (54, 35, 50, 255), (43, 27, 42, 255), (58, 38, 52, 255)]
    wall = Image.new("RGBA", (96, 288), mortar)
    px = wall.load()
    for row in range(288 // 8):
        offset = 0 if row % 2 == 0 else 8
        for column in range(-1, 96 // 16 + 1):
            shade = rng.choice(shades)
            left = column * 16 + offset
            for y in range(row * 8, row * 8 + 7):
                for x in range(left, left + 15):
                    if 0 <= x < 96:
                        # A touch of shading: lit top edge, dark bottom edge.
                        light = 1.12 if y == row * 8 else 0.88 if y == row * 8 + 6 else 1.0
                        px[x, y] = tuple(min(255, int(c * light)) for c in shade[:3]) + (255,)
    wall.save(OUT / "castle_wall.png")


def build_vignette() -> None:
    width, height = 480, 270
    vignette = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = vignette.load()
    for y in range(height):
        for x in range(width):
            dx, dy = (x - width / 2) / (width / 2), (y - height / 2) / (height / 2)
            edge = min(1.0, max(0.0, (math.hypot(dx, dy) - 0.55) / 0.75))
            px[x, y] = (10, 4, 14, int(150 * edge * edge))
    vignette.save(OUT / "castle_vignette.png")


def build_lift() -> None:
    platform = Image.open(OUT / "castle_platform.png")
    pieces = [0, 1, 1, 1, 2]
    lift = Image.new("RGBA", (TILE * len(pieces), TILE), (0, 0, 0, 0))
    for index, piece in enumerate(pieces):
        lift.paste(platform.crop((piece * TILE, 0, (piece + 1) * TILE, TILE)), (index * TILE, 0))
    lift.save(OUT / "castle_lift.png")


def build_grate() -> None:
    """16x6: dark iron bars over a bed of embers."""
    grate = Image.new("RGBA", (TILE, 6), (0, 0, 0, 0))
    px = grate.load()
    iron, dark, ember, glow = (58, 50, 56, 255), (30, 24, 30, 255), (226, 98, 40, 255), (255, 170, 70, 255)
    for x in range(1, TILE - 1):
        for y in range(6):
            px[x, y] = dark
    for x in range(1, TILE - 1):
        px[x, 0] = iron
        px[x, 5] = iron
    for x in range(2, TILE - 2):
        px[x, 2] = ember if x % 3 else glow
        px[x, 3] = ember
    for x in range(2, TILE - 2, 4):
        for y in range(1, 5):
            px[x, y] = iron
    grate.save(OUT / "ember_grate.png")


def copy_fire_bomb() -> None:
    source = PACKS / "Magic Pack 9 files" / "Magic Pack 9 files" / "spritesheets" / "Fire-bomb.png"
    shutil.copyfile(source, ASSETS / "effects" / "fire_bomb.png")


def preview(atlas: Image.Image) -> None:
    """A little test level drawn from the atlas, to check the look without Godot."""
    rows = [
        "..............................",
        "..............................",
        "..............................",
        ".........######...............",
        "..............................",
        "......##.............###......",
        "......##.....................#",
        "########..######..############",
        "########..######..############",
        "########..######..############",
    ]
    height, width = len(rows), len(rows[0])
    solid = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == "#"}
    picture = Image.new("RGBA", (width * TILE, height * TILE), (40, 18, 34, 255))
    for x, y in solid:
        mask = 0
        for bit, (dx, dy) in {N: (0, -1), NE: (1, -1), E: (1, 0), SE: (1, 1), S: (0, 1),
                              SW: (-1, 1), W: (-1, 0), NW: (-1, -1)}.items():
            if (x + dx, y + dy) in solid or not (0 <= x + dx < width and 0 <= y + dy < height):
                mask |= bit
        tile = atlas.crop(((mask % 16) * TILE, (mask // 16) * TILE,
                           (mask % 16 + 1) * TILE, (mask // 16 + 1) * TILE))
        picture.alpha_composite(tile, (x * TILE, y * TILE))
    x = 12 * TILE
    for index, name in enumerate(["window_tall", "window_arch", "window_twin"]):
        window = Image.open(OUT / f"{name}.png")
        picture.alpha_composite(window, (x + index * 52 - 120, 1 * TILE))
    picture.resize((picture.width * 2, picture.height * 2), Image.NEAREST).convert("RGB").save(
        OUT / "_preview.png")
    print("preview -> assets/castle/_preview.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    terrain = build_terrain()
    print("terrain -> assets/castle/castle_terrain.png")
    build_platform()
    print("platform -> assets/castle/castle_platform.png")
    build_windows()
    print("windows ->", ", ".join(WINDOWS))
    build_lights()
    print("lights ->", ", ".join(name for strips in LIGHTS.values() for name, *_ in strips))
    build_lift()
    build_grate()
    build_wall()
    build_vignette()
    copy_fire_bomb()
    print("wall, vignette, assets/effects/fire_bomb.png")
    if "--preview" in sys.argv:
        preview(terrain)
