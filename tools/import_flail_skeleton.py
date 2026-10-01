"""Imports the flail skeleton (skeletonAsset/, added by the user on 2026-10-02)
for Chapter Three, where it replaces the sword-throwing skeleton that was cut
from one Monsters Creatures Fantasy sheet.

The pack's sheets differ in size (move, hurt and idle 64x64; attack 146x64 and
death 118x64, each a 5x5 grid) and face left. Every frame is put on one
146x64 canvas with the body in the same place (found by matching the standing
pose at the start of each sheet against the idle pose), mirrored to face
right like the game's other art, and packed eight to a row (long strips are
wider than some web browsers allow):

  assets/flail_skeleton/walk.png    10 frames   (move)
  assets/flail_skeleton/attack.png  23 frames   (the flail raised high, then slammed ahead)
  assets/flail_skeleton/hurt.png     3 frames   (with its red flash)
  assets/flail_skeleton/death.png   24 frames   (it falls apart; the skull rolls away)

It prints the body's x on the canvas: build_resources.gd and skeleton.tscn's
sprite_offset use it. Run from the project folder:
  python tools/import_flail_skeleton.py
The pack is never edited; this only copies, shifts, mirrors and repacks.
"""
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT.parent / "skeletonAsset" / "skeletonAsset"
OUT = ROOT / "assets" / "flail_skeleton"
CANVAS = (146, 64)
COLUMNS = 8


def frames_of(name: str, width: int, grid: bool) -> list[Image.Image]:
    sheet = Image.open(PACK / name).convert("RGBA")
    frames = []
    rows = sheet.height // 64 if grid else 1
    for row in range(rows):
        for column in range(sheet.width // width):
            frame = sheet.crop((column * width, row * 64, column * width + width, row * 64 + 64))
            if frame.getbbox():
                frames.append(frame)
    return frames


def best_shift(small: Image.Image, wide: Image.Image) -> int:
    """Where `small` sits in `wide`, judged by the alpha masks."""
    best, best_score = 0, None
    small_alpha = small.getchannel("A")
    for dx in range(wide.width - small.width + 1):
        part = wide.crop((dx, 0, dx + small.width, 64)).getchannel("A")
        histogram = ImageChops.difference(small_alpha, part).histogram()
        score = sum(level * count for level, count in enumerate(histogram))
        if best_score is None or score < best_score:
            best, best_score = dx, score
    return best


def place(frames: list[Image.Image], dx: int) -> list[Image.Image]:
    placed = []
    for frame in frames:
        canvas = Image.new("RGBA", CANVAS)
        canvas.alpha_composite(frame, (dx, 0))
        placed.append(canvas.transpose(Image.FLIP_LEFT_RIGHT))
    return placed


def save_grid(frames: list[Image.Image], name: str) -> None:
    rows = (len(frames) + COLUMNS - 1) // COLUMNS
    columns = min(len(frames), COLUMNS)
    grid = Image.new("RGBA", (CANVAS[0] * columns, CANVAS[1] * rows))
    for index, frame in enumerate(frames):
        grid.alpha_composite(frame, ((index % COLUMNS) * CANVAS[0], (index // COLUMNS) * CANVAS[1]))
    grid.save(OUT / f"{name}.png")
    print(f"{name}: {len(frames)} frames -> assets/flail_skeleton/{name}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    idle = frames_of("skeletonIdle-Sheet64x64.png", 64, False)
    attack = frames_of("skeletonAttack-Sheet146x64.png", 146, True)
    death = frames_of("skeletonDie-Sheet118x64_all.png", 118, True)
    # The 64-wide sheets sit where the idle pose matches the attack's first frame.
    small_dx = best_shift(idle[0], attack[0])
    # The death sheet's first frame is the idle pose too.
    death_dx = small_dx - best_shift(idle[0], death[0])
    save_grid(place(frames_of("skeletonMove-Sheet64x64.png", 64, False), small_dx), "walk")
    save_grid(place(attack, 0), "attack")
    save_grid(place(frames_of("skeletonHurt-Sheet64x64.png", 64, False), small_dx), "hurt")
    save_grid(place(death, death_dx), "death")
    # The body's middle (its skull, above the flail) in the idle frame, mirrored.
    box = idle[0].crop((0, 0, 64, 34)).getbbox()
    body = small_dx + (box[0] + box[2]) // 2
    print(f"64 px sheets at x {small_dx}, death at x {death_dx}; "
          f"body at x {CANVAS[0] - body} of {CANVAS[0]} after mirroring")


if __name__ == "__main__":
    main()
