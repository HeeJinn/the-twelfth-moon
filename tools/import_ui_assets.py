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
The Silver set and the other bar shapes on the sheet are not used.
The pack is never edited; this only reads it.
"""
import io
import zipfile

from PIL import Image

from import_assets import ASSETS, PACKS

PACK_ZIP = PACKS / "Health & Stamina 1.2.zip"
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


if __name__ == "__main__":
    UI.mkdir(exist_ok=True)
    with zipfile.ZipFile(PACK_ZIP) as pack:
        for layer_name, file_name in LAYERS.items():
            data = pack.read(f"Health&Stamina/Red/{layer_name}.png")
            layer = Image.open(io.BytesIO(data)).convert("RGBA").crop(BAR_BOX)
            stretch(layer, BAR_WIDTH).save(UI / f"{file_name}.png")
            print(f"{layer_name} -> assets/ui/{file_name}.png ({BAR_WIDTH}x{layer.height})")
