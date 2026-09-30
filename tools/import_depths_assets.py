"""Chapter Four's second half: the undercroft beneath Ember Keep.

Run from the project folder after the other importers:
    python tools/import_depths_assets.py            # writes assets/depths/
    python tools/import_depths_assets.py --preview  # also a test picture next to it

Where it comes from:
  CRAWLING DEPTHS (pingupollas): the slate tiles, the tentacle, the mouth in the
  floor, the floating rock, the Amalgam, the Eldritch Entity, the book altar, and
  statues, urns and vein columns.

What it makes:
  depths_terrain.png  16x16 slate block, one tile for each of the 256 neighbour masks
                      (like the castle's): the pack's slate as the inside, a pale rim
                      where the top is open, dark edges and drips elsewhere.
  depths_wall.png     the cave wall behind, the same slate darkened, 96x288.
  tentacle.png        21 frames of 32x64: a rumble at a crack (4, the warning), the
                      tentacle rising out of the ground and swaying (13), sinking (4).
  crack.png           the crack a tentacle comes out of, always visible.
  mouth.png           the pack's mouth, 18 frames of 64x64, and mouth_closed.png, the
                      closed mouth that lies in the floor between snaps.
  amalgam.png         the Amalgam's crawl, each frame mirrored to face right.
  floating_rock.png, eldritch_dormant.png, eldritch_awake.png,
  book_altar.png, statue_a1.png, statue_b1.png, urn_1.png, vein_column_tall.png
The pack is never edited; this only copies, crops and draws.
"""
import shutil
import sys

from PIL import Image

from import_assets import ASSETS, PACKS

DEPTHS = PACKS / "CRAWLING DEPTHS" / "CRAWLING DEPTHS"
OUT = ASSETS / "depths"
TILE = 16
N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128

TILES = Image.open(DEPTHS / "Terrain" / "Tiles.png").convert("RGBA")
FILL = TILES.crop((0, 0, TILE, TILE))


def luminance(colour: tuple) -> float:
    return 0.2126 * colour[0] + 0.7152 * colour[1] + 0.0722 * colour[2]


PALETTE = sorted({FILL.getpixel((x, y))[:3] for y in range(TILE) for x in range(TILE)}, key=luminance)
DARKEST, LIGHTEST = PALETTE[0], PALETTE[-1]
EDGE = (12, 10, 20, 255)
RIM = tuple(min(255, int(c * 1.35) + 10) for c in LIGHTEST) + (255,)
RIM_SHADE = LIGHTEST + (255,)


def terrain_tile(mask: int) -> Image.Image:
    solid = {bit: bool(mask & bit) for bit in (N, NE, E, SE, S, SW, W, NW)}
    tile = FILL.copy()
    px = tile.load()
    for y in range(TILE):
        for x in range(TILE):
            if not solid[W] and x == 0 or not solid[E] and x == TILE - 1:
                px[x, y] = EDGE
            if not solid[S] and (y == TILE - 1 or y == TILE - 2 and x % 5 in (1, 2)):
                px[x, y] = EDGE  # a ragged underside, like drips
            if not solid[N]:
                if y == 0:
                    px[x, y] = RIM
                elif y == 1:
                    px[x, y] = RIM_SHADE
    for diagonal, side_a, side_b, cx, cy in [(NW, N, W, 0, 0), (NE, N, E, TILE - 1, 0),
                                             (SW, S, W, 0, TILE - 1), (SE, S, E, TILE - 1, TILE - 1)]:
        if not solid[side_a] and not solid[side_b]:
            px[cx, cy] = (0, 0, 0, 0)
        elif solid[side_a] and solid[side_b] and not solid[diagonal]:
            px[cx, cy] = EDGE
    return tile


def build_terrain() -> Image.Image:
    atlas = Image.new("RGBA", (TILE * 16, TILE * 16), (0, 0, 0, 0))
    for mask in range(256):
        atlas.paste(terrain_tile(mask), ((mask % 16) * TILE, (mask // 16) * TILE))
    atlas.save(OUT / "depths_terrain.png")
    return atlas


def build_wall() -> None:
    """The five by four slate tiles laid in a pattern, darkened, as the cave wall."""
    wall = Image.new("RGBA", (96, 288), (0, 0, 0, 255))
    for row in range(288 // TILE):
        for column in range(96 // TILE):
            index = (column * 7 + row * 3) % 20
            piece = TILES.crop(((index % 5) * TILE, (index // 5) * TILE,
                                (index % 5 + 1) * TILE, (index // 5 + 1) * TILE))
            wall.paste(piece, (column * TILE, row * TILE))
    px = wall.load()
    for y in range(wall.height):
        for x in range(wall.width):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * 0.3), int(g * 0.3), int(b * 0.38), 255)
    wall.save(OUT / "depths_wall.png")


def build_tentacle() -> None:
    sheet = Image.open(DEPTHS / "Creatures" / "Tentacle 1 Sheet.png").convert("RGBA")
    width, height = 32, 64
    sway = [sheet.crop((i * width, 0, (i + 1) * width, height)) for i in range(9)]
    frames = []
    # The warning: a crack in the floor, with grit hopping out of it.
    for step in range(4):
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        fpx = frame.load()
        for x in range(10, 22):
            fpx[x, height - 1] = EDGE
        for dx, rise in ((12, (1, 3, 2, 4)[step]), (17, (3, 1, 4, 2)[step]), (20, (2, 4, 1, 3)[step])):
            fpx[dx, height - 1 - rise] = RIM_SHADE
        frames.append(frame)
    # Rising: the first pose, showing a little more of it each frame.
    for shown in (16, 32, 48, 64):
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        frame.paste(sway[0].crop((0, 0, width, shown)), (0, height - shown))
        frames.append(frame)
    frames += sway
    # Sinking: the rise backwards.
    for shown in (48, 32, 16, 4):
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        frame.paste(sway[-1].crop((0, 0, width, shown)), (0, height - shown))
        frames.append(frame)
    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.paste(frame, (index * width, 0))
    strip.save(OUT / "tentacle.png")
    crack = Image.new("RGBA", (TILE, 3), (0, 0, 0, 0))
    cpx = crack.load()
    for x in range(2, 14):
        cpx[x, 2] = EDGE
    for x in (4, 7, 11):
        cpx[x, 1] = EDGE
    cpx[9, 0] = EDGE
    crack.save(OUT / "crack.png")


def build_amalgam() -> None:
    """Nine 64x64 frames, each mirrored: the pack's Amalgam faces left, and the
    game's enemies are drawn facing right."""
    sheet = Image.open(DEPTHS / "Creatures" / "Amalgam 1 Sheet.png").convert("RGBA")
    strip = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for index in range(sheet.width // 64):
        frame = sheet.crop((index * 64, 0, (index + 1) * 64, 64))
        strip.paste(frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (index * 64, 0))
    strip.save(OUT / "amalgam.png")


def build_floating_rock() -> None:
    """Six 32x32 frames with a pale rim on top, like the floor's, so the rocks can be
    seen against the dark cave: they are where she lands over the chasm."""
    sheet = Image.open(DEPTHS / "Terrain" / "Floating Rock A1 Sheet.png").convert("RGBA")
    px = sheet.load()
    for x in range(sheet.width):
        top = next((y for y in range(sheet.height) if px[x, y][3] > 0), None)
        if top is None:
            continue
        px[x, top] = RIM
        if top + 1 < sheet.height and px[x, top + 1][3] > 0:
            px[x, top + 1] = RIM_SHADE
    sheet.save(OUT / "floating_rock.png")


def build_mouth() -> None:
    sheet = Image.open(DEPTHS / "Creatures" / "Mouth 1 Sheet.png").convert("RGBA")
    sheet.save(OUT / "mouth.png")
    sheet.crop((9 * 64, 0, 10 * 64, 64)).save(OUT / "mouth_closed.png")


COPIES = {
    "Creatures/Eldritch Entity Dormant.png": "eldritch_dormant.png",
    "Creatures/Eldritch Entity Awaken.png": "eldritch_awake.png",
    "Structures & Details/Book Altar.png": "book_altar.png",
    "Structures & Details/Statue A1.png": "statue_a1.png",
    "Structures & Details/Statue B1.png": "statue_b1.png",
    "Structures & Details/Urn 1.png": "urn_1.png",
    "Structures & Details/Tall Vein Column 1.png": "vein_column_tall.png",
}


def preview(atlas: Image.Image) -> None:
    rows = [
        "##############################",
        "##############################",
        "######.........###############",
        "..............................",
        "..............................",
        "......##............###.......",
        "......##......................",
        "########..######..############",
        "########..######..############",
    ]
    height, width = len(rows), len(rows[0])
    solid = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == "#"}
    wall = Image.open(OUT / "depths_wall.png").convert("RGBA")
    picture = Image.new("RGBA", (width * TILE, height * TILE), (0, 0, 0, 255))
    for x in range(0, picture.width, wall.width):
        picture.paste(wall.crop((0, 0, wall.width, picture.height)), (x, 0))
    for x, y in solid:
        mask = 0
        for bit, (dx, dy) in {N: (0, -1), NE: (1, -1), E: (1, 0), SE: (1, 1), S: (0, 1),
                              SW: (-1, 1), W: (-1, 0), NW: (-1, -1)}.items():
            if (x + dx, y + dy) in solid or not (0 <= x + dx < width and 0 <= y + dy < height):
                mask |= bit
        picture.alpha_composite(atlas.crop(((mask % 16) * TILE, (mask // 16) * TILE,
                                            (mask % 16 + 1) * TILE, (mask // 16 + 1) * TILE)),
                                (x * TILE, y * TILE))
    tentacle = Image.open(OUT / "tentacle.png").convert("RGBA")
    picture.alpha_composite(tentacle.crop((10 * 32, 0, 11 * 32, 64)), (20 * TILE, 7 * TILE - 64))
    mouth = Image.open(OUT / "mouth_closed.png").convert("RGBA")
    picture.alpha_composite(mouth, (24 * TILE, 7 * TILE - 58))
    face = Image.open(OUT / "eldritch_dormant.png").convert("RGBA")
    picture.alpha_composite(face.crop((0, 0, 160, 112)), (1 * TILE, 0))
    picture.resize((picture.width * 2, picture.height * 2), Image.NEAREST).convert("RGB").save(
        OUT / "_preview.png")
    print("preview -> assets/depths/_preview.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    terrain = build_terrain()
    build_wall()
    build_tentacle()
    build_mouth()
    build_amalgam()
    build_floating_rock()
    for source, target in COPIES.items():
        shutil.copyfile(DEPTHS / source, OUT / target)
    print("depths -> terrain, wall, tentacle, crack, mouth,", ", ".join(COPIES.values()))
    if "--preview" in sys.argv:
        preview(terrain)
