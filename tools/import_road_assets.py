"""Chapter Three art: the Long Road, from autumn into winter.

Run from the project folder after the other importers:
    python tools/import_road_assets.py

Where it comes from:
  GandalfHardcore     autumn and winter background layers with the castle on
                      the horizon, the blizzard, animated water and waterfall
  Pixel Valley        swaying golden oak, pines and grass, frogs, fish and a
                      snake, and road props (signposts, reeds, mushrooms,
                      boulders, ice crystals, an old mine cart...)
  16x16 Fantasy       red and teal trees, snowy fences and bushes, sheep, a
                      well, and the small effects every chapter now uses
                      (hit sparks, landing dust, "!" and "?" pop-ups,
                      glimmers, frost spikes, the fireflies jar)
  Crawling Depths     a vein statue, veins and little blinking eyes in the
                      ice cave (a first glimpse of the moon's rot under the
                      keep in Chapter Four)
  Knight              Kael's Shield, the mini-boss, every sheet straightened
                      onto one canvas so one offset fits all
The packs are never edited; this only copies, crops and repacks.
"""
from pathlib import Path

from PIL import Image, ImageSequence

from import_assets import ASSETS, GANDALF, PACKS, copy

ROAD = ASSETS / "road"
EFFECTS = ASSETS / "effects"
BACKGROUND_LAYERS = GANDALF / "GandalfHardcore Background layers"
VALLEY = PACKS / "Pixel Valley - Revamp" / "Pixel Valley Revamp"
FANTASY = PACKS / "16x16 Fantasy Platformer Pack" / "16x16 Fantasy Platformer Pack"
DEPTHS = PACKS / "CRAWLING DEPTHS" / "CRAWLING DEPTHS"
KNIGHT = PACKS / "Knight" / "Knight"

# Static props: name -> (sheet, (left, top, right, bottom)).
VALLEY_SHEET = VALLEY / "Enviroment.png"
FANTASY_TREES = FANTASY / "Tilesets" / "Basic Tiles Only.png"
FANTASY_PLANTS = FANTASY / "Tilesets" / "Vegetation Tileset 1.png"
PROPS = {
    # Pixel Valley, the autumn road.
    "wheat": (VALLEY_SHEET, (294, 22, 409, 48)),
    "tall_grass": (VALLEY_SHEET, (294, 86, 409, 112)),
    "grass_tuft": (VALLEY_SHEET, (294, 57, 327, 81)),
    "fern": (VALLEY_SHEET, (810, 44, 851, 64)),
    "sapling": (VALLEY_SHEET, (881, 53, 910, 80)),
    "cattail": (VALLEY_SHEET, (834, 106, 846, 160)),
    "reeds": (VALLEY_SHEET, (882, 106, 894, 160)),
    "hollow_stump": (VALLEY_SHEET, (592, 112, 640, 160)),
    "signpost": (VALLEY_SHEET, (832, 161, 862, 192)),
    "signpost_small": (VALLEY_SHEET, (867, 161, 888, 192)),
    "bush_gold": (VALLEY_SHEET, (837, 0, 889, 32)),
    "bush_round": (VALLEY_SHEET, (826, 231, 867, 256)),
    "bush_low": (VALLEY_SHEET, (880, 241, 916, 256)),
    "stone": (VALLEY_SHEET, (802, 315, 839, 336)),
    "boulder": (VALLEY_SHEET, (498, 616, 544, 666)),
    "red_mushrooms": (VALLEY_SHEET, (478, 316, 556, 371)),
    "mine_cart": (VALLEY_SHEET, (240, 527, 271, 544)),
    "mine_door": (VALLEY_SHEET, (481, 552, 511, 607)),
    # Pixel Valley, the ice cave.
    "ice_urchin": (VALLEY_SHEET, (96, 394, 175, 466)),
    "ice_crystals": (VALLEY_SHEET, (47, 356, 94, 384)),
    "ice_column": (VALLEY_SHEET, (0, 432, 32, 496)),
    "ice_cluster": (VALLEY_SHEET, (64, 432, 96, 496)),
    "ice_spikes": (VALLEY_SHEET, (96, 468, 128, 496)),
    "icicle": (VALLEY_SHEET, (146, 467, 157, 496)),
    "green_crystal": (VALLEY_SHEET, (134, 556, 171, 592)),
    # 16x16 Fantasy trees: red for the last of autumn, teal for winter.
    "red_pine": (FANTASY_TREES, (780, 1, 902, 160)),
    "red_pine_small": (FANTASY_TREES, (551, 31, 637, 160)),
    "red_fir": (FANTASY_TREES, (632, 167, 696, 256)),
    "red_tree": (FANTASY_TREES, (881, 137, 1007, 288)),
    "teal_pine": (FANTASY_TREES, (780, 289, 902, 448)),
    "teal_pine_small": (FANTASY_TREES, (551, 319, 637, 448)),
    "teal_fir": (FANTASY_TREES, (550, 452, 618, 560)),
    "teal_fir_small": (FANTASY_TREES, (704, 463, 752, 528)),
    "bare_tree": (FANTASY_TREES, (768, 463, 832, 576)),
    "teal_tree": (FANTASY_TREES, (881, 425, 1007, 576)),
    "stump_snow": (FANTASY_TREES, (640, 549, 672, 576)),
    # 16x16 Fantasy fences, snow and a well.
    "fence": (FANTASY_PLANTS, (0, 24, 48, 48)),
    "fence_snow": (FANTASY_PLANTS, (0, 104, 48, 128)),
    "snow_bush": (FANTASY_PLANTS, (32, 128, 80, 160)),
    "snow_bush_small": (FANTASY_PLANTS, (48, 112, 80, 128)),
    "snow_mound": (FANTASY_PLANTS, (80, 112, 96, 128)),
    "frost_cypress": (FANTASY_PLANTS, (80, 144, 96, 176)),
    "frost_fern": (FANTASY_PLANTS, (16, 160, 32, 176)),
    "well": (FANTASY_PLANTS, (14, 254, 52, 304)),
    # Crawling Depths: the moon's rot, reaching out from the keep.
    "vein_statue": (DEPTHS / "Structures & Details" / "Statue B1.png", None),
    "vein_column": (DEPTHS / "Structures & Details" / "Short Vein Column 1.png", None),
}

# Animated sheets from Pixel Valley: name -> (file, cell size). Frames are
# read left to right, top to bottom, skipping empty cells, then cropped to
# the area every frame covers and repacked in a grid of GRID_COLUMNS.
SWAYING = {
    "oak_sway": ("Tree1 - 42F.png", (256, 256)),
    "pine_sway": ("Pine - 60F.png", (128, 128)),
    "pine_tall_sway": ("Pine II - 60F.png", (256, 256)),
    "grass_sway": ("Bush - 60F.png", (128, 128)),
}
GRID_COLUMNS = 8
# Strips that are already one row: name -> (file, frame width).
VALLEY_STRIPS = {
    "frog": ("Frog - 14F.png", 27),
    "fish": ("Fish - 7F.png", 29),
    "snake": ("Snake - 6F.png", 23),
}
# GIFs made into one-row strips: file -> target.
GIFS = {
    FANTASY / "Animals" / "Sheep" / "White Sheep Idle.gif": ROAD / "sheep_white_idle.png",
    FANTASY / "Animals" / "Sheep" / "White Sheep Walking.gif": ROAD / "sheep_white_walk.png",
    FANTASY / "Animals" / "Sheep" / "White Sheep Sleeping.gif": ROAD / "sheep_white_sleep.png",
    FANTASY / "Animals" / "Sheep" / "Black Sheep Idle.gif": ROAD / "sheep_black_idle.png",
    FANTASY / "Animals" / "Sheep" / "Black Sheep Walking.gif": ROAD / "sheep_black_walk.png",
    FANTASY / "Animals" / "Sheep" / "Black Sheep Sleeping.gif": ROAD / "sheep_black_sleep.png",
    FANTASY / "Tilesets" / "Fireflies pot v2.gif": ROAD / "fireflies_jar.png",
    FANTASY / "Particles And Spells" / "Ice.gif": ROAD / "frost_spikes.png",
    FANTASY / "Particles And Spells" / "Blue Particles.gif": ROAD / "ice_glints.png",
    # Shared effects for every chapter.
    FANTASY / "Particles And Spells" / "Hit (Orange).gif": EFFECTS / "hit_spark.png",
    FANTASY / "Particles And Spells" / "Hit (Blue).gif": EFFECTS / "guard_spark.png",
    FANTASY / "Particles And Spells" / "Dirt.gif": EFFECTS / "landing_dust.png",
    FANTASY / "Particles And Spells" / "Color Shifting Particles.gif": EFFECTS / "glimmer.png",
    FANTASY / "GUI" / "Popups" / "Alert White.gif": EFFECTS / "alert.png",
    FANTASY / "GUI" / "Popups" / "Question Mark White.gif": EFFECTS / "question.png",
}

# GIFs where only some frames are wanted: target -> (first, end). The dirt
# effect's frames 1-7 are a low puff; 8-12 are a tall spray we don't want.
GIF_FRAMES = {"landing_dust.png": (1, 8)}

# The Knight's sheets have different frame widths and put him in different
# places. name -> (file, frame width, his body's x in a frame). Every frame
# goes on a KNIGHT_CANVAS canvas with his body at KNIGHT_BODY_X and his feet
# (y 44) where they were. The long attack sheet is split into its three
# moves so no strip is wider than a web browser allows.
KNIGHT_SHEETS = {
    "idle": ("noBKG_KnightIdle_strip.png", 64, 35),
    "run": ("noBKG_KnightRun_strip.png", 96, 51),
    "attack": ("noBKG_KnightAttack_strip.png", 144, 67),
    "guard": ("noBKG_KnightShield_strip.png", 96, 51),
    "roll": ("noBKG_KnightRoll_strip.png", 180, 67),
    "leap": ("noBKG_KnightJumpAndFall_strip.png", 144, 67),
    "death": ("noBKG_KnightDeath_strip.png", 96, 51),
}
# Attack frames: 0-8 a thrust, 9-13 an overhead slash, 14-21 a spinning low
# sweep that steps forward.
KNIGHT_ATTACKS = {"thrust": (0, 9), "slash": (9, 14), "sweep": (14, 22)}
KNIGHT_CANVAS = (192, 64)
KNIGHT_BODY_X = 64

LICENSE = """Chapter Three art:
- Background layers, blizzard, water: GandalfHardcore (FREE Platformer Assets)
- Swaying trees, grass, frog, fish, snake, road and cave props:
  Pixel Valley | Forest and Cave (Revamped) by kauzz, kauzz.itch.io
- Red and teal trees, fences, snow, sheep, well, effects and pop-ups:
  16x16 Fantasy Platformer Pack (author to confirm from its download page)
- Vein statue, veins, little eyes: Crawling Depths by pingupollas
- Kael's Shield: Knight (see the pack's own terms)
"""


def gif_strip(source: Path, only: tuple = None) -> Image.Image:
    gif = Image.open(source)
    frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)]
    if only:
        frames = frames[only[0]:only[1]]
    width, height = frames[0].size
    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * width, 0))
    return strip


def grid_frames(sheet: Image.Image, cell: tuple) -> list:
    frames = []
    for row in range(sheet.height // cell[1]):
        for column in range(sheet.width // cell[0]):
            box = (column * cell[0], row * cell[1], (column + 1) * cell[0], (row + 1) * cell[1])
            frame = sheet.crop(box)
            if frame.getbbox():
                frames.append(frame)
    return frames


def repack(frames: list) -> tuple:
    """Crops frames to their shared bounds and lays them in a grid.
    Returns the sheet, the frame size and the frame count."""
    left = min(f.getbbox()[0] for f in frames)
    top = min(f.getbbox()[1] for f in frames)
    right = max(f.getbbox()[2] for f in frames)
    bottom = max(f.getbbox()[3] for f in frames)
    size = (right - left, bottom - top)
    rows = (len(frames) + GRID_COLUMNS - 1) // GRID_COLUMNS
    sheet = Image.new("RGBA", (size[0] * GRID_COLUMNS, size[1] * rows), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        cell = frame.crop((left, top, right, bottom))
        sheet.paste(cell, ((i % GRID_COLUMNS) * size[0], (i // GRID_COLUMNS) * size[1]))
    return sheet, size, len(frames)


def copy_backgrounds() -> None:
    for season, castle in (("Autumn", "Background Castle Autumn.png"),
                           ("Winter", "Background Castle  Winter.png")):
        folder = BACKGROUND_LAYERS / f"{season} BG"
        name = season.lower()
        for i in range(1, 6):
            copy(folder / f"GandalfHardcore Background layers_layer {i}.png",
                 ROAD / "background" / f"{name}_layer_{i}.png")
        copy(folder / castle, ROAD / "background" / f"{name}_castle.png")
    copy(VALLEY / "Background.png", ROAD / "background" / "wood_back.png")
    copy(VALLEY / "Midleground.png", ROAD / "background" / "wood_mid.png")
    copy(GANDALF / "Snow blizzard sheet frame size 484x274.png", ROAD / "blizzard.png")


def cut_water() -> None:
    """The river's animated surface (20 frames of 32x32) and the waterfall
    (20 frames of 32x128: three tiles of falling water and the splash)."""
    sheet = Image.open(GANDALF / "Animated Sprites" / "GandalfHardcore Animated Water Tiles.png")
    sheet = sheet.convert("RGBA")
    surface = Image.new("RGBA", (32 * 20, 32), (0, 0, 0, 0))
    fall = Image.new("RGBA", (32 * 20, 128), (0, 0, 0, 0))
    for i in range(20):
        surface.paste(sheet.crop((i * 32, 64, i * 32 + 32, 96)), (i * 32, 0))
        fall.paste(sheet.crop((i * 32, 96, i * 32 + 32, 224)), (i * 32, 0))
    surface.save(ROAD / "water_surface.png")
    fall.save(ROAD / "waterfall.png")
    deep = surface.getpixel((16, 31))
    print(f"  deep water colour: {deep}")


def draw_ladder() -> Image.Image:
    """One 32x32 cell of wooden ladder in the village plank colours."""
    dark, mid, light = (58, 36, 32, 255), (112, 70, 52, 255), (152, 101, 70, 255)
    tile = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in (8, 23):  # The two rails, 3 px wide with a dark outline.
            tile.putpixel((x - 1, y), dark)
            tile.putpixel((x, y), light)
            tile.putpixel((x + 1, y), mid)
            tile.putpixel((x + 2, y), dark)
    for rung_y in (5, 13, 21, 29):
        for x in range(7, 26):
            tile.putpixel((x, rung_y - 1), dark)
            tile.putpixel((x, rung_y), light if 9 < x < 23 else mid)
            tile.putpixel((x, rung_y + 1), dark)
    return tile


def copy_props() -> None:
    for name, (sheet, box) in PROPS.items():
        image = Image.open(sheet).convert("RGBA")
        if box:
            image = image.crop(box)
        image = image.crop(image.getbbox())
        image.save(ROAD / "props" / f"{name}.png")


def make_animations() -> None:
    for name, (source, cell) in SWAYING.items():
        sheet, size, count = repack(grid_frames(Image.open(VALLEY / source).convert("RGBA"), cell))
        sheet.save(ROAD / f"{name}.png")
        print(f"  {name}: {count} frames of {size}, sheet {sheet.size}")
    for name, (source, width) in VALLEY_STRIPS.items():
        copy(VALLEY / source, ROAD / f"{name}.png")
        print(f"  {name}: {Image.open(VALLEY / source).width // width} frames of {width}")
    for source, target in GIFS.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        strip = gif_strip(source, GIF_FRAMES.get(target.name))
        strip.save(target)
        print(f"  {target.name}: {strip.size}")
    # The ice cave's back wall: Crawling Depths stone, tiled.
    copy(DEPTHS / "Terrain" / "Tiles.png", ROAD / "cave_wall.png")
    for name in ("Little Eyes 1", "Vein A1"):
        copy(DEPTHS / "Structures & Details" / f"{name} Sheet.png",
             ROAD / f"{name.lower().replace(' ', '_')}.png")


def straighten_knight() -> None:
    target_dir = ASSETS / "knight"
    target_dir.mkdir(parents=True, exist_ok=True)
    frames_of = {}
    for name, (source, width, body_x) in KNIGHT_SHEETS.items():
        sheet = Image.open(KNIGHT / source).convert("RGBA")
        frames = []
        for i in range(sheet.width // width):
            canvas = Image.new("RGBA", KNIGHT_CANVAS, (0, 0, 0, 0))
            frame = sheet.crop((i * width, 0, (i + 1) * width, sheet.height))
            canvas.paste(frame, (KNIGHT_BODY_X - body_x, 0), frame)
            frames.append(canvas)
        frames_of[name] = frames
    for name, (start, end) in KNIGHT_ATTACKS.items():
        frames_of[name] = frames_of["attack"][start:end]
    del frames_of["attack"]
    for name, frames in frames_of.items():
        strip = Image.new("RGBA", (KNIGHT_CANVAS[0] * len(frames), KNIGHT_CANVAS[1]))
        for i, frame in enumerate(frames):
            strip.paste(frame, (i * KNIGHT_CANVAS[0], 0))
        strip.save(target_dir / f"knight_{name}.png")
        print(f"  knight_{name}: {len(frames)} frames")


if __name__ == "__main__":
    for folder in (ROAD, ROAD / "props", ROAD / "background", EFFECTS):
        folder.mkdir(parents=True, exist_ok=True)
    copy_backgrounds()
    cut_water()
    draw_ladder().save(ROAD / "ladder.png")
    copy_props()
    make_animations()
    straighten_knight()
    (ROAD / "LICENSE.txt").write_text(LICENSE)
    print("road assets done")
