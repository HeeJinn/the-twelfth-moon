"""Makes the petal journal's open book from "UI assets pack 2".

The pack's open book (UI books & more.png, 96x48 at x 16, y 32) is too small
to write on at four times its size, so it is widened first: one column inside
each page and one row across both are repeated. Those run across flat paper
and the pages' drawn frames, so the frames simply get longer. Then it is
scaled four times in whole pixels:

  assets/ui/journal_book.png  472x240 (118x60 before scaling)

Run from the project folder: python tools/draw_journal_book.py
The pack is never edited; this only copies, repeats and scales.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT.parent / "UI assets pack 2" / "UI assets pack 2" / "UI books & more.png"
OUT = ROOT / "assets" / "ui" / "journal_book.png"
BOOK = (16, 32, 112, 80)  # left, top, right, bottom
# Columns (in the book) inside the left and right page, and a row across both.
LEFT_COLUMN, RIGHT_COLUMN, ROW = 24, 72, 24
EXTRA_COLUMNS, EXTRA_ROWS = 11, 12
SCALE = 4


def repeat_column(image: Image.Image, x: int, times: int) -> Image.Image:
    out = Image.new("RGBA", (image.width + times, image.height))
    out.paste(image.crop((0, 0, x, image.height)), (0, 0))
    column = image.crop((x, 0, x + 1, image.height))
    for i in range(times):
        out.paste(column, (x + i, 0))
    out.paste(image.crop((x, 0, image.width, image.height)), (x + times, 0))
    return out


def repeat_row(image: Image.Image, y: int, times: int) -> Image.Image:
    out = Image.new("RGBA", (image.width, image.height + times))
    out.paste(image.crop((0, 0, image.width, y)), (0, 0))
    row = image.crop((0, y, image.width, y + 1))
    for i in range(times):
        out.paste(row, (0, y + i))
    out.paste(image.crop((0, y, image.width, image.height)), (0, y + times))
    return out


def main() -> None:
    book = Image.open(PACK).convert("RGBA").crop(BOOK)
    # The right page first, so the left page's column index stays put.
    book = repeat_column(book, RIGHT_COLUMN, EXTRA_COLUMNS)
    book = repeat_column(book, LEFT_COLUMN, EXTRA_COLUMNS)
    book = repeat_row(book, ROW, EXTRA_ROWS)
    book = book.resize((book.width * SCALE, book.height * SCALE), Image.NEAREST)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    book.save(OUT)
    print(f"journal book -> assets/ui/journal_book.png {book.size}")


if __name__ == "__main__":
    main()
