"""Draws the ten digits Pixelmax lacks, as a small bitmap font.

Pixelmax has letters and punctuation but no digits, so the story writes
numbers as words. The credits need real ones (licence names such as
"CC BY 4.0" and their links), so this draws 0-9 in Pixelmax's style (12 px
caps, 2 px strokes, stepped corners) and writes a BMFont that Godot imports:

  assets/fonts/pixelmax_digits.png  the ten glyphs in a row
  assets/fonts/pixelmax_digits.fnt  BMFont text file, sized for Pixelmax at 16 px

ui/credits/credits_font.tres is Pixelmax with this font as its fallback, so any
label using it shows digits. Run from the project folder:
  python tools/draw_digits.py
"""
from pathlib import Path

from PIL import Image

FONTS = Path(__file__).resolve().parent.parent / "assets" / "fonts"
WIDTH, HEIGHT = 8, 12
# Pixelmax at 16 px: ascent 13, descent 4; capitals span rows 1 to 12.
LINE_HEIGHT, BASE, TOP = 17, 13, 1
ADVANCE = 10

DIGITS = {
    "0": ["..####..", ".######.", "###..###", "##....##", "##....##", "##....##",
          "##....##", "##....##", "##....##", "###..###", ".######.", "..####.."],
    "1": ["...##...", "..###...", ".####...", "##.##...", "...##...", "...##...",
          "...##...", "...##...", "...##...", "...##...", ".######.", ".######."],
    "2": ["..####..", ".######.", "###..###", ".....###", ".....##.", "....###.",
          "...###..", "..###...", ".###....", "###.....", "########", "########"],
    "3": [".######.", "########", ".....###", ".....##.", "...####.", "...#####",
          "......##", "......##", "......##", "##...###", "########", ".######."],
    "4": ["....###.", "...####.", "..##.##.", ".##..##.", "##...##.", "##...##.",
          "########", "########", ".....##.", ".....##.", ".....##.", ".....##."],
    "5": ["########", "########", "##......", "##......", "######..", "#######.",
          ".....###", "......##", "......##", "##...###", "#######.", ".#####.."],
    "6": ["..#####.", ".######.", "###.....", "##......", "##.###..", "#######.",
          "###..###", "##....##", "##....##", "###..###", ".######.", "..####.."],
    "7": ["########", "########", ".....###", ".....##.", "....###.", "....##..",
          "...###..", "...##...", "..###...", "..##....", "..##....", "..##...."],
    "8": ["..####..", ".######.", "###..###", "##....##", "###..###", ".######.",
          ".######.", "###..###", "##....##", "###..###", ".######.", "..####.."],
    "9": ["..####..", ".######.", "###..###", "##....##", "##....##", "###..###",
          ".#######", "..######", "......##", ".....###", ".######.", ".#####.."],
}


def main() -> None:
    sheet = Image.new("RGBA", ((WIDTH + 1) * len(DIGITS), HEIGHT))
    lines = [
        'info face="Pixelmax Digits" size=16 bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1",
        f"common lineHeight={LINE_HEIGHT} base={BASE} scaleW={sheet.width} "
        f"scaleH={sheet.height} pages=1 packed=0",
        'page id=0 file="pixelmax_digits.png"',
        f"chars count={len(DIGITS)}",
    ]
    for index, (digit, rows) in enumerate(DIGITS.items()):
        assert len(rows) == HEIGHT and all(len(row) == WIDTH for row in rows), digit
        left = index * (WIDTH + 1)
        for y, row in enumerate(rows):
            for x, cell in enumerate(row):
                if cell == "#":
                    sheet.putpixel((left + x, y), (255, 255, 255, 255))
        lines.append(
            f"char id={ord(digit)} x={left} y=0 width={WIDTH} height={HEIGHT} "
            f"xoffset=1 yoffset={TOP} xadvance={ADVANCE} page=0 chnl=15")
    sheet.save(FONTS / "pixelmax_digits.png")
    (FONTS / "pixelmax_digits.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("digits -> assets/fonts/pixelmax_digits.png and .fnt")


if __name__ == "__main__":
    main()
