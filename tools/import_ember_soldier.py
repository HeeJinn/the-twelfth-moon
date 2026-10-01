"""Imports Kael's soldiers (2026-10-02): the Clembod Warrior (Warrior-V1.3,
the first Mariane), recoloured for Ember Keep so she reads as an enemy, not a
heroine: the auburn hair dark like a hood, the purple cape ember red, the grey
armour blackened iron, the gold trim ember orange. They replace the goblins
cut from the Monsters Creatures Fantasy pack.

  assets/ember_soldier/walk.png    8 frames  (Run)
  assets/ember_soldier/attack.png 12 frames  (the sword raised, then two slashes)
  assets/ember_soldier/hurt.png    4 frames  (HurtnoEffect)
  assets/ember_soldier/death.png  11 frames  (DeathnoEffect)

Frames stay 64x44 (the sheet faces right, the body at x 21, the feet at the
bottom), eight to a row. Run from the project folder:
  python tools/import_ember_soldier.py
The pack is never edited; this only copies, recolours and repacks.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT.parent / "Warrior-V1.3" / "Warrior" / "Individual Sprite"
OUT = ROOT / "assets" / "ember_soldier"
FRAME = (64, 44)
COLUMNS = 8
# folder, file prefix, count -> output name
SHEETS = [
    ("Run", "Warrior_Run", 8, "walk"),
    ("Attack", "Warrior_Attack", 12, "attack"),
    ("HurtnoEffect", "Warrior_hurt", 4, "hurt"),
    ("DeathnoEffect", "Warrior_Death", 11, "death"),
]
RECOLOUR = {
    # hair -> a dark hood
    (125, 49, 26): (46, 38, 50), (176, 95, 40): (70, 58, 72), (77, 15, 10): (28, 22, 32),
    # cape -> ember red
    (86, 11, 40): (128, 30, 22), (50, 6, 50): (84, 18, 18), (18, 0, 34): (40, 10, 14),
    # armour -> blackened iron
    (126, 142, 147): (96, 88, 94), (63, 75, 78): (56, 48, 56), (195, 203, 219): (156, 146, 146),
    # gold trim -> ember orange
    (242, 191, 87): (255, 152, 64), (236, 141, 47): (222, 92, 34),
}


def frame_path(folder: str, prefix: str, index: int) -> Path:
    path = PACK / folder / f"{prefix}_{index}.png"
    if not path.exists():  # The pack is not consistent about capitals.
        matches = list((PACK / folder).glob(f"*_{index}.png"))
        path = matches[0]
    return path


def recolour(frame: Image.Image) -> Image.Image:
    pixels = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in RECOLOUR:
                pixels[x, y] = (*RECOLOUR[(r, g, b)], a)
    return frame


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for folder, prefix, count, name in SHEETS:
        rows = (count + COLUMNS - 1) // COLUMNS
        grid = Image.new("RGBA", (FRAME[0] * min(count, COLUMNS), FRAME[1] * rows))
        for i in range(count):
            frame = recolour(Image.open(frame_path(folder, prefix, i + 1)).convert("RGBA"))
            grid.alpha_composite(frame, ((i % COLUMNS) * FRAME[0], (i // COLUMNS) * FRAME[1]))
        grid.save(OUT / f"{name}.png")
        print(f"{name}: {count} frames -> assets/ember_soldier/{name}.png")
    idle = Image.open(frame_path("idle", "Warrior_Idle", 1)).convert("RGBA")
    box = idle.crop((0, 0, FRAME[0], 20)).getbbox()  # the head
    print(f"head at x {box[0]}-{box[2]}; feet at y {idle.getbbox()[3]}")


if __name__ == "__main__":
    main()
