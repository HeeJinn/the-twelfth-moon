"""The boss health bar, from the Health & Stamina pack.

Run from the project folder after the other importers:
    python tools/import_ui_assets.py

Where it comes from:
  Health & Stamina 1.2.zip (author and licence still to be confirmed), the Red set:
  Border.png, BorderBG.png and Colors.png share one 240x400 sheet. The first
  bar on it is a 50x9 piece: a black frame, a dark inside and a two-tone red
  fill. Each layer is stretched sideways to the HUD's bar width, keeping the
  rounded end caps, into three textures for a TextureProgressBar:
    boss_bar_under.png  the dark inside
    boss_bar_fill.png   the red fill (cropped from the left as health drops)
    boss_bar_frame.png  the black frame, drawn over both
The same bar also makes Mariane's own bars for the HUD, drawn at twice the
size (the HUD's scale): her health from the Red set with a notch between
hearts, and her moonlight from the Silver set with a notch between moons:
    player_health_under/fill/frame.png   five hearts
    player_moon_under/fill/frame.png     three moons
The other bar shapes on the sheet are not used.
The pack is never edited; this only reads it.
"""
import io
import zipfile

from PIL import Image

from import_assets import ASSETS, PACKS

PACK_ZIP = PACKS / "Health & Stamina 1.2.zip"
# The same pack, unzipped (used when the zip is not there).
PACK_DIR = PACKS / "Health & Stamina 1.2"
UI = ASSETS / "ui"

# The first bar on the sheet, (left, top, right, bottom), and the width of the
# rounded caps to keep on each side while stretching.
BAR_BOX = (95, 20, 145, 29)
CAP = 4
BAR_WIDTH = 220

LAYERS = {
    "BorderBG": "boss_bar_under",
    "Colors": "boss_bar_fill",
    "Border": "boss_bar_frame",
}


def stretch(layer: Image.Image, new_width: int) -> Image.Image:
    """Keeps the end caps and repeats the middle column, in whole pixels."""
    width, height = layer.size
    result = Image.new("RGBA", (new_width, height), (0, 0, 0, 0))
    result.paste(layer.crop((0, 0, CAP, height)), (0, 0))
    result.paste(layer.crop((width - CAP, 0, width, height)), (new_width - CAP, 0))
    middle = layer.crop((CAP, 0, width - CAP, height))
    result.paste(middle.resize((new_width - 2 * CAP, height), Image.NEAREST), (CAP, 0))
    return result


# Her bars: name -> (colour set, width before doubling, segments)
PLAYER_BARS = {
    "player_health": ("Red", 64, 5),
    "player_moon": ("Silver", 40, 3),
}
# The bar's inside (where the fill shows), in the 50x9 piece: x 2-47, y 2-6.
INSIDE = (2, 2, 3, 7)  # left, top, right margin, bottom


def notched(frame: Image.Image, segments: int) -> Image.Image:
    """The frame with a dark notch between segments, over the fill."""
    result = frame.copy()
    left, top, right_margin, bottom = INSIDE
    inside = frame.width - left - right_margin
    for k in range(1, segments):
        x = left + round(inside * k / segments)
        for y in range(top, bottom):
            result.putpixel((x, y), (20, 12, 24, 255))
    return result


class Pack:
    """Reads the pack's files from the zip, or from the unzipped folder."""

    def __init__(self) -> None:
        self.zip = zipfile.ZipFile(PACK_ZIP) if PACK_ZIP.exists() else None

    def read(self, name: str) -> bytes:
        return self.zip.read(name) if self.zip else (PACK_DIR / name).read_bytes()


def build_player_bars(pack: Pack) -> None:
    for name, (colours, width, segments) in PLAYER_BARS.items():
        for layer_name, suffix in (("BorderBG", "under"), ("Colors", "fill"), ("Border", "frame")):
            data = pack.read(f"Health&Stamina/{colours}/{layer_name}.png")
            layer = stretch(Image.open(io.BytesIO(data)).convert("RGBA").crop(BAR_BOX), width)
            if suffix == "frame":
                layer = notched(layer, segments)
            layer = layer.resize((layer.width * 2, layer.height * 2), Image.NEAREST)
            layer.save(UI / f"{name}_{suffix}.png")
        print(f"{name}: {colours}, {segments} segments, {width * 2}x{BAR_BOX[3] * 2 - BAR_BOX[1] * 2}")


if __name__ == "__main__":
    UI.mkdir(exist_ok=True)
    pack = Pack()
    for layer_name, file_name in LAYERS.items():
        data = pack.read(f"Health&Stamina/Red/{layer_name}.png")
        layer = Image.open(io.BytesIO(data)).convert("RGBA").crop(BAR_BOX)
        stretch(layer, BAR_WIDTH).save(UI / f"{file_name}.png")
        print(f"{layer_name} -> assets/ui/{file_name}.png ({BAR_WIDTH}x{layer.height})")
    build_player_bars(pack)
