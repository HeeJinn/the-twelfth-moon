"""Draws Chapter Five's map (the Twelfth Night, the roof of Ember Keep) into
levels/maps/chapter_05.txt.

Run from the project folder:
    python tools/make_chapter_05.py

The map is 16 px cells, 136 wide and 28 tall. Like Chapter Four it is laid out
with coordinates; edit the numbers here and run it again. Cell (x, y): x counts
from the left, y from the top. An entity stands on the bottom of its cell, so
put it in the row just above the floor.

The last chapter is short and gentle: out of the stair onto the roof, along the
battlements past lightning rods, up two towers and a ledge to the summit, where
Kael waits under the moon. Rises are three or four tiles, the gaps have a
floor under them (a fall never leaves the map), and there are three campfires.

Legend (Chapter Five's own letters, see spawn_overrides in chapter_05.tres):
    #  castle stone        =  stone ledge (one-way)
    P  start               K  campfire
    Z  lightning rod (sparks at its tip, then a strike, over and over)
    N  the summit arena (its middle; the walls of fire stand 14.5 cells either
       side; Kael waits east of the middle)
    @  the twenty-first petal (hidden until it falls from Kael at the reveal)
    r  brazier             g  gold brazier
    (  the roof thought    )  the towers thought        [  the summit thought
    l  lightning hint
"""
from pathlib import Path

WIDTH, HEIGHT = 136, 28
OUT = Path(__file__).resolve().parent.parent / "levels" / "maps" / "chapter_05.txt"

grid = [["."] * WIDTH for _ in range(HEIGHT)]


def block(x0: int, x1: int, y0: int, y1: int, char: str = "#") -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = char


def put(x: int, y: int, char: str) -> None:
    assert grid[y][x] in ".", (x, y, grid[y][x], char)
    grid[y][x] = char


def ledge(x0: int, x1: int, y: int) -> None:
    block(x0, x1, y, y, "=")


# --- The roof, west to east -------------------------------------------------------
block(0, 12, 24, 27)        # the head of the stair
block(13, 44, 24, 27)       # the battlements
block(45, 54, 20, 27)       # the first tower, four tiles up
block(55, 57, 24, 27)       # a gap with a floor (nothing to fall into)
ledge(55, 57, 21)           # and a ledge, to climb out either way
block(58, 68, 18, 27)       # the second tower
ledge(70, 72, 15)           # a ledge up to the summit
block(69, 73, 22, 27)       # a lower roof under it: a fall lands here, four tiles below the tower
block(74, 135, 12, 27)      # the summit, the highest roof of the keep
block(132, 135, 8, 11)      # its far parapet

# --- Start, fire and story ------------------------------------------------------------
put(2, 23, "P")
put(6, 23, "K")
put(9, 23, "(")
put(15, 23, "l")
put(60, 17, "K")
put(62, 17, ")")
put(84, 11, "K")
put(90, 11, "[")

# --- Lightning rods along the way ------------------------------------------------------
for x, y in ((22, 23), (34, 23), (66, 17), (79, 11)):
    put(x, y, "Z")

# --- The summit arena -----------------------------------------------------------------
put(111, 11, "N")           # its middle; Kael waits six cells east
put(117, 6, "@")            # the last petal, hidden over where he stands

# --- Dressing -------------------------------------------------------------------------
for x, y, char in ((28, 23, "r"), (40, 23, "r"), (50, 19, "g"), (64, 17, "g"),
                   (102, 11, "g"), (122, 11, "g"), (130, 11, "r")):
    put(x, y, char)

OUT.write_text("\n".join("".join(row) for row in grid) + "\n", encoding="utf-8", newline="\n")
print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")
