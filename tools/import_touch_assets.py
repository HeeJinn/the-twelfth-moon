"""The on-screen buttons for playing on a phone, from Crusenho's Complete UI
Essential Pack (Flat theme, CC BY 4.0: credit "Crusenho" in the credits).

Run from the project folder:
    python tools/import_touch_assets.py

Where it comes from:
  UI_Flat_Button02a_4.png (raised) and UI_Flat_Button02a_1.png (pushed down): a
  cream 32x32 button with a black outline and an orange edge. UI_Flat_IconArrow01a
  is the blue arrow. The pack has no sword, shield or moon, so those icons are drawn
  here in its colours (black outline, the arrow's two blues, cream, orange).

Made here (assets/ui/touch/): <name>.png and <name>_pressed.png, 32x32, for
  left, right, up, down (the direction pad), jump, attack, guard, spark, dash,
  talk and pause. The icon sits in the middle of the button's face, and moves
  down with it when pressed.
The pack is never edited; this only reads it.
"""
from PIL import Image

from import_assets import ASSETS, PACKS

FLAT = (PACKS / "Complete_UI_Essential_Pack_Free" / "Complete_UI_Essential_Pack_Free"
        / "01_Flat_Theme" / "Sprites")
OUT = ASSETS / "ui" / "touch"

CREAM = (255, 253, 245, 255)
COLOURS = {
    "k": (0, 0, 0, 255),
    "b": (79, 134, 237, 255),
    "B": (51, 92, 207, 255),
    "w": CREAM,
    "o": (255, 197, 121, 255),
    "g": (150, 160, 178, 255),
    "G": (214, 222, 236, 255),
    "y": (255, 226, 140, 255),
    "r": (150, 84, 60, 255),
}

ICONS = {
    "jump": [
        ".....kk.....",
        "....kbbk....",
        "...kbbbbk...",
        "..kbbkkbbk..",
        ".kbbk..kbbk.",
        "kbbk....kbbk",
        "kkk......kkk",
        "............",
        "..kkkkkkkk..",
        "..kooooook..",
        "..kkkkkkkk..",
    ],
    "attack": [
        "..........kkk",
        ".........kGwk",
        "........kGwk.",
        ".......kGwk..",
        "......kGwk...",
        "..k..kGwk....",
        "..kkkGwk.....",
        "...kGwk......",
        "...kkGkk.....",
        "..krrk.kk....",
        ".krrrk.......",
        ".krrk........",
        "..kk.........",
    ],
    "guard": [
        ".kkkkkkkkkk.",
        "kbbbbbbbbbbk",
        "kbwwwwwwwwbk",
        "kbwbbbbbbwbk",
        "kbwbBBBBbwbk",
        "kbwbBBBBbwbk",
        "kbbwbBBbwbbk",
        ".kbbwbbwbbk.",
        ".kbbbwwbbbk.",
        "..kbbbbbbk..",
        "...kbbbbk...",
        "....kbbk....",
        ".....kk.....",
    ],
    "dash": [
        "kk.....kk.....",
        "kbk....kbk....",
        "kbbk...kbbk...",
        ".kbbk...kbbk..",
        "..kbbk...kbbk.",
        "..kbbk...kbbk.",
        ".kbbk...kbbk..",
        "kbbk...kbbk...",
        "kbk....kbk....",
        "kk.....kk.....",
    ],
    "spark": [
        "....kkkk....",
        "..kkyyyyk...",
        ".kyyykkk....",
        ".kyyk.......",
        "kyywk.......",
        "kyyk........",
        "kyyk........",
        "kyywk.......",
        ".kyyk.......",
        ".kyyykkk....",
        "..kkyyyyk...",
        "....kkkk....",
    ],
    "talk": [
        ".kkkkkkkkkkkk.",
        "kbbbbbbbbbbbbk",
        "kbbbbbbbbbbbbk",
        "kbwwbbwwbbwwbk",
        "kbwwbbwwbbwwbk",
        "kbbbbbbbbbbbbk",
        ".kkkkbbkkkkkk.",
        "....kbk.......",
        "....kk........",
    ],
    "pause": [
        "kkkk..kkkk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kbbk..kbbk",
        "kkkk..kkkk",
    ],
}
# The arrow points right; each direction is a turn of it (degrees, anticlockwise).
ARROWS = {"right": 0, "up": 90, "left": 180, "down": 270}


def draw(rows: list[str]) -> Image.Image:
    image = Image.new("RGBA", (max(len(row) for row in rows), len(rows)))
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char in COLOURS:
                image.putpixel((x, y), COLOURS[char])
    return image


def face_centre(button: Image.Image) -> tuple[int, int]:
    """The middle of the cream face (the part that moves when pressed)."""
    mask = Image.new("L", button.size)
    pixels = button.load()
    for y in range(button.height):
        for x in range(button.width):
            if pixels[x, y] == CREAM:
                mask.putpixel((x, y), 255)
    left, top, right, bottom = mask.getbbox()
    return (left + right) // 2, (top + bottom) // 2


def compose(button: Image.Image, icon: Image.Image) -> Image.Image:
    result = button.copy()
    cx, cy = face_centre(button)
    result.alpha_composite(icon, (cx - icon.width // 2, cy - icon.height // 2))
    return result


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    raised = Image.open(FLAT / "UI_Flat_Button02a_4.png").convert("RGBA")
    pushed = Image.open(FLAT / "UI_Flat_Button02a_1.png").convert("RGBA")
    arrow = Image.open(FLAT / "UI_Flat_IconArrow01a.png").convert("RGBA")
    icons = {name: draw(rows) for name, rows in ICONS.items()}
    for name, degrees in ARROWS.items():
        icons[name] = arrow.rotate(degrees, expand=True)
    for name, icon in icons.items():
        compose(raised, icon).save(OUT / f"{name}.png")
        compose(pushed, icon).save(OUT / f"{name}_pressed.png")
    print(f"assets/ui/touch: {len(icons)} buttons, raised and pressed")


if __name__ == "__main__":
    main()
