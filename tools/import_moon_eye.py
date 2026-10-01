"""Imports the moon-eye (2026-10-02): the floating Eye from Crawling Depths
(pingupollas), the moon-soaked creature that replaces the flying eye cut from
the Monsters Creatures Fantasy pack in Chapters Three and Four.

  assets/depths/moon_eye.png  28 frames of 32x32, eight to a row: 0-20 it
                              looks about, 21-24 it shuts, 25-27 it opens wide

Run from the project folder: python tools/import_moon_eye.py
The pack is never edited; this only repacks the strip into rows (long strips
are wider than some web browsers allow).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = (ROOT.parent / "CRAWLING DEPTHS" / "CRAWLING DEPTHS" / "Creatures" / "Eye 1 Sheet.png")
OUT = ROOT / "assets" / "depths" / "moon_eye.png"
SIZE, COUNT, COLUMNS = 32, 28, 8


def main() -> None:
    strip = Image.open(SHEET).convert("RGBA")
    rows = (COUNT + COLUMNS - 1) // COLUMNS
    grid = Image.new("RGBA", (SIZE * COLUMNS, SIZE * rows))
    for i in range(COUNT):
        frame = strip.crop((i * SIZE, 0, i * SIZE + SIZE, SIZE))
        grid.alpha_composite(frame, ((i % COLUMNS) * SIZE, (i // COLUMNS) * SIZE))
    grid.save(OUT)
    print(f"moon eye: {COUNT} frames -> assets/depths/moon_eye.png")


if __name__ == "__main__":
    main()
