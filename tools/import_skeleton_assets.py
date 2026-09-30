"""Chapter Four's keep guard: the Skeleton Sprite Pack, straightened.

Run from the project folder after the other importers:
    python tools/import_skeleton_assets.py

Where it comes from:
  Skeleton Sprite Pack.rar (author and licence still to be confirmed): six sheets
  with different frame sizes (Idle, Walk, React, Attack, Hit, Dead). The rar is
  unpacked with the `tar` that comes with Windows into "Skeleton Sprite Pack/"
  next to the other packs, the first time.

Every frame goes onto one 56x40 canvas with the body at the same x and the feet
on the bottom row, so a single sprite offset fits every animation. Frames that
reach out to the left (Attack, Hit, Dead) are shifted so their body stays put.
The skeleton is Mariane-sized (about 28 px tall), much smaller than the
Monsters Creatures Fantasy skeleton that throws swords in Chapter Three.
The pack is never edited; this only reads, unpacks and repacks.
"""
import subprocess

from PIL import Image

from import_assets import ASSETS, PACKS

RAR = PACKS / "Skeleton Sprite Pack.rar"
UNPACKED = PACKS / "Skeleton Sprite Pack"
OUT = ASSETS / "skeleton"

CANVAS_WIDTH, CANVAS_HEIGHT, BODY_X = 56, 40, 14
# name: (frame width, frame height, frame count, sideways shift of the body in
# its frame compared with Idle).
SHEETS = {
    "Idle": (24, 32, 11, 0),
    "Walk": (22, 33, 13, 0),
    "React": (22, 32, 4, 0),
    "Attack": (43, 37, 18, 3),
    "Hit": (30, 32, 8, 6),
    "Dead": (33, 32, 15, 11),
}


def unpack() -> None:
    if (UNPACKED / "Skeleton" / "Sprite Sheets").exists():
        return
    UNPACKED.mkdir(exist_ok=True)
    subprocess.run(["tar", "-xf", str(RAR), "-C", str(UNPACKED)], check=True)


def straighten() -> None:
    OUT.mkdir(exist_ok=True)
    for name, (frame_width, frame_height, count, shift) in SHEETS.items():
        sheet = Image.open(UNPACKED / "Skeleton" / "Sprite Sheets" / f"Skeleton {name}.png")
        sheet = sheet.convert("RGBA")
        assert sheet.size == (frame_width * count, frame_height), (name, sheet.size)
        strip = Image.new("RGBA", (CANVAS_WIDTH * count, CANVAS_HEIGHT), (0, 0, 0, 0))
        for index in range(count):
            frame = sheet.crop((index * frame_width, 0, (index + 1) * frame_width, frame_height))
            strip.paste(frame, (index * CANVAS_WIDTH + BODY_X - shift,
                                CANVAS_HEIGHT - frame_height))
        strip.save(OUT / f"skeleton_{name.lower()}.png")
        print(f"{name}: {count} frames -> assets/skeleton/skeleton_{name.lower()}.png")


if __name__ == "__main__":
    unpack()
    straighten()
