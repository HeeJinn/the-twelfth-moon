"""Draws the ending's paper lanterns into assets/generated/.

  paper_lantern.png  7x10: a red paper lantern lit from inside, with a tassel,
                     hung along the village's garland at dawn.
  sky_lantern.png    11x12: the same lantern without the tassel, in a soft
                     halo, for the lanterns that float up into the dawn sky.

Run from the project folder: python tools/draw_ending_assets.py
Nothing is read from the packs; every pixel is drawn here.
"""
from pathlib import Path

from PIL import Image

GENERATED = Path(__file__).resolve().parent.parent / "assets" / "generated"

COLORS = {
    "D": (74, 36, 40, 255),     # dark cap
    "R": (196, 64, 58, 255),    # red paper at the edge
    "O": (238, 132, 72, 255),   # orange paper
    "Y": (255, 206, 120, 255),  # lit paper
    "W": (255, 242, 200, 255),  # the flame's glow
    "T": (196, 64, 58, 255),    # tassel
    ".": (0, 0, 0, 0),
}
LANTERN = [
    "..DDD..",
    ".ROOOR.",
    "ROYYYOR",
    "ROYWYOR",
    "ROYWYOR",
    "ROYYYOR",
    ".ROOOR.",
    "..DDD..",
    "...T...",
    "...T...",
]
HALO = (255, 176, 96)


def draw(rows: list[str]) -> Image.Image:
    image = Image.new("RGBA", (len(rows[0]), len(rows)))
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            image.putpixel((x, y), COLORS[key])
    return image


def with_halo(lantern: Image.Image, margin: int) -> Image.Image:
    """Puts the lantern in a faint glow: alpha falls off with distance."""
    width, height = lantern.size
    out = Image.new("RGBA", (width + margin * 2, height + margin * 2))
    cx, cy = out.width / 2 - 0.5, out.height / 2 - 0.5
    radius = max(out.width, out.height) / 2
    for y in range(out.height):
        for x in range(out.width):
            distance = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / radius
            alpha = int(max(0.0, 1.0 - distance) * 90)
            # Whole steps, so the halo stays in a few flat pixel-art bands.
            alpha = (alpha // 30) * 30
            if alpha > 0:
                out.putpixel((x, y), (*HALO, alpha))
    out.alpha_composite(lantern, (margin, margin))
    return out


def main() -> None:
    lantern = draw(LANTERN)
    lantern.save(GENERATED / "paper_lantern.png")
    print("paper lantern -> assets/generated/paper_lantern.png", lantern.size)
    sky = with_halo(draw(LANTERN[:8]), 2)
    sky.save(GENERATED / "sky_lantern.png")
    print("sky lantern -> assets/generated/sky_lantern.png", sky.size)


if __name__ == "__main__":
    main()
