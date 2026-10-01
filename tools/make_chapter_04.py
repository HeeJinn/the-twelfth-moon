"""Draws Chapter Four's map (Ember Keep) into levels/maps/chapter_04.txt.

Run from the project folder:
    python tools/make_chapter_04.py

The map is 16 px cells, 372 wide and 28 tall: the keep to column 210, its cellar
and the chasm, the undercroft, and the Grave Warden's crypt from column 330. It is easier to lay out with
coordinates than by typing rows, so this script places the ground, ledges and
everything on it, then writes the rows. Edit the numbers here and run it again.
Cell (x, y): x counts from the left, y from the top. An entity stands on the
bottom of its cell, so put it in the row just above the floor.

Mariane's reach (entities/player/player_stats.tres): a jump rises 80 px (five
tiles), she runs 110 px/s and dashes about 49 px. The keep is built with room to
spare: rises of four tiles or less, gaps of five or less, and lifts for anything
taller.

Legend (Chapter Four's own letters, see spawn_overrides in chapter_04.tres):
    #  castle stone        =  stone ledge (one-way)     |  vine ladder
    P  start               C  petal                     K  campfire   G  the stair down
    B  keep guard          E  goblin                    Y  flying eye
    V  ember vent          a  lift up    A  short lift up   d  lift down   s  lift sideways
    w  arched window       W  tall window               Q  barred window
    L  hanging lantern     h  chandelier                r  brazier      g  gold brazier
    x y z q  wall lamps    c  candles
    (  the gate thought    )  the windows thought       [  the lifts thought
    ]  the vents thought   {  the stair thought
    l  lift hint           v  vent hint
  The undercroft:
    o  floating rock       m  mouth in the floor        t  tentacle     M  Amalgam
    X  Eldritch Entity     D  the cave wall behind      b  book altar
    j k  statues           e  urn     f  tall vein column
    %  vein statue         &  blinking eyes             $  veins
    }  the undercroft thought   <  the face thought     >  the altar thought
    u  mouth hint          i  tentacle hint
  The crypt:
    N  the Grave Warden's arena (its middle; the walls of light stand 14.5 cells
       either side, and the fight there ends the chapter)
"""
from pathlib import Path

WIDTH, HEIGHT = 372, 28
OUT = Path(__file__).resolve().parent.parent / "levels" / "maps" / "chapter_04.txt"

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


# --- The ground, west to east -------------------------------------------------
block(0, 33, 22, 27)        # the gate courtyard
block(34, 87, 20, 27)       # the ember hall, two tiles higher
block(88, 111, 22, 27)      # the floor of the lift shaft
block(112, 149, 10, 27)     # the moon gallery, at the top of the shaft
block(162, 186, 10, 27)     # beyond the gap, a long landing
# The stair down: two tiles lower every four columns.
for step, (x0, x1) in enumerate([(187, 190), (191, 194), (195, 198), (199, 202)]):
    block(x0, x1, 12 + step * 2, 27)
block(203, 209, 20, 27)

# --- Ledges --------------------------------------------------------------------
ledge(12, 16, 18)           # the first petal's ledge
ledge(70, 76, 16)           # above the ember hall
ledge(94, 95, 18)           # shaft: between the lifts, flush with the lift before it
ledge(103, 104, 14)
ledge(172, 174, 8)          # the climb over the vents
ledge(177, 179, 6)

# --- Lifts (the moving platform's origin is the middle of its top surface) ------
put(91, 20, "A")            # docks a tile above the shaft floor, up three tiles to the first ledge
put(100, 17, "a")           # up from there to the second (two tiles across from the ledge)
put(109, 13, "a")           # and up to the gallery, flush with its floor
put(152, 9, "s")            # across the gap, flush with both edges

# --- Start, fire and story -------------------------------------------------------
put(3, 21, "P")
put(4, 21, "(")
for x in (8, 66, 116, 146, 168, 196):
    y = {8: 21, 66: 19, 116: 9, 146: 9, 168: 9, 196: 15}[x]
    put(x, y, "K")
put(86, 19, "l")
put(90, 19, "[")
put(46, 19, "v")
put(48, 19, "]")
put(120, 9, ")")
put(186, 9, "{")

# --- Petals: five, each a little off the path --------------------------------------
put(14, 15, "C")            # above the first ledge
put(73, 12, "C")            # above the ledge in the ember hall
put(104, 10, "C")           # above the second shaft ledge
put(154, 7, "C")            # over the gap, reached from the lift
put(178, 4, "C")            # top of the climb over the vents

# --- Keep: guards, goblins, an eye, the vents ------------------------------------
for x, y in ((26, 21), (62, 19), (124, 9), (136, 9), (170, 9)):
    put(x, y, "B")
for x, y in ((130, 9), (178, 9)):
    put(x, y, "E")
put(142, 6, "Y")
put(154, 4, "Y")
for x, y in ((50, 19), (55, 19), (80, 19), (176, 9), (180, 9), (184, 9)):
    put(x, y, "V")

# --- Dressing ---------------------------------------------------------------------
windows = [(20, 17, "w"), (40, 15, "W"), (60, 15, "Q"), (120, 7, "w"), (132, 7, "W"),
           (142, 7, "Q"), (168, 7, "w"), (194, 10, "W")]
for x, y, char in windows:
    put(x, y, char)
for x, y in ((28, 10), (126, 2), (138, 2), (166, 2)):
    put(x, y, "h")
for x, y in ((12, 13), (45, 12), (98, 8), (156, 3)):
    put(x, y, "L")
for x, y in ((18, 21), (44, 19), (70, 19), (118, 9), (158, 9), (190, 11)):
    put(x, y, "r")
for x, y, char in ((10, 16, "x"), (30, 16, "y"), (52, 14, "z"), (64, 14, "q"),
                   (122, 5, "x"), (134, 5, "y"), (146, 5, "z"), (172, 5, "q"),
                   (24, 21, "c"), (150, 9, "g")):
    put(x, y, char)

# --- The undercroft ------------------------------------------------------------------
# Down a cellar stair under the keep's foundations, across a chasm on floating rocks,
# into the moon-soaked slate beneath (chapter_04.tres switches "#" to slate from
# column 248, across the chasm, so the two stones never touch).
block(210, 214, 22, 27)     # the cellar stair, two tiles down, then two more
block(215, 230, 24, 27)
block(212, 230, 0, 9)       # the keep's foundations overhead
put(218, 23, "K")
put(222, 23, "}")
for x, y in ((233, 23), (237, 22), (241, 23), (245, 22)):
    put(x, y, "o")          # floating rocks over the chasm, bobbing a little
block(248, 371, 24, 27)     # the undercroft floor, on into the crypt
block(248, 329, 0, 9)       # and its low ceiling
put(231, 27, "D")           # the cave wall behind everything from the chasm on
put(250, 23, "K")
put(253, 23, "u")           # the mouths hint
for x in (257, 262):
    put(x, 23, "m")         # mouths in the floor
put(267, 23, "i")           # the tentacles hint
for x in (271, 275, 279):
    put(x, 23, "t")         # tentacles, rising from cracks
put(288, 23, "M")           # the Amalgam, slow and heavy
put(296, 23, "K")
put(300, 23, "<")
put(305, 23, "X")           # the Eldritch Entity, asleep in the wall
put(313, 23, ">")
put(315, 23, "b")           # the book altar
put(325, 23, "K")           # a last campfire before the crypt
for x, y, char in ((252, 14, "&"), (276, 12, "&"), (292, 15, "&"), (259, 12, "$"),
                   (284, 13, "$"), (282, 23, "j"), (310, 23, "k"), (293, 23, "e"),
                   (319, 23, "f"), (226, 23, "%")):
    put(x, y, char)

# --- The Grave Warden's crypt ----------------------------------------------------------
# A taller vault at the end of the undercroft; the fight fills one screen.
block(330, 371, 0, 6)
block(369, 371, 7, 23)      # the far wall
put(350, 23, "N")           # the arena's middle; he waits east of it
for x, y, char in ((333, 23, "f"), (366, 23, "f"), (337, 23, "j"), (363, 23, "k"),
                   (340, 23, "e"), (360, 23, "e"), (343, 23, "c"), (357, 23, "c"),
                   (345, 10, "&"), (356, 11, "&"), (350, 8, "$"), (329, 13, "$")):
    put(x, y, char)

OUT.write_text("\n".join("".join(row) for row in grid) + "\n", encoding="utf-8", newline="\n")
print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")
