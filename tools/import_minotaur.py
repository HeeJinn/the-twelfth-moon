"""Imports the Minotaur (Minotaur - Sprite Sheet.png, added by the user on
2026-10-02), the heavy brute that replaces the mushroom cut from the Monsters
Creatures Fantasy pack in Chapters Two and Three.

The sheet is a 96 px grid, one animation a row, facing right in rows 0-9 and
left in rows 10-19. Taken: row 1 walk (8), row 3 the overhead chop (9: the axe
raised high, slammed down ahead, dragged back), row 7 hurt (3), row 9 death
(6). Frames stay 96x96 (the body at x 45, the feet at y 64), eight to a row:

  assets/minotaur/walk.png, attack.png, hurt.png, death.png

Run from the project folder: python tools/import_minotaur.py
The sheet is never edited; this only copies and repacks.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT.parent / "Minotaur - Sprite Sheet.png"
OUT = ROOT / "assets" / "minotaur"
SIZE, COLUMNS = 96, 8
ROWS = {"walk": (1, 8), "attack": (3, 9), "hurt": (7, 3), "death": (9, 6)}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET).convert("RGBA")
    for name, (row, count) in ROWS.items():
        rows = (count + COLUMNS - 1) // COLUMNS
        grid = Image.new("RGBA", (SIZE * min(count, COLUMNS), SIZE * rows))
        for i in range(count):
            frame = sheet.crop((i * SIZE, row * SIZE, i * SIZE + SIZE, row * SIZE + SIZE))
            grid.alpha_composite(frame, ((i % COLUMNS) * SIZE, (i // COLUMNS) * SIZE))
        grid.save(OUT / f"{name}.png")
        print(f"{name}: {count} frames -> assets/minotaur/{name}.png")


if __name__ == "__main__":
    main()
