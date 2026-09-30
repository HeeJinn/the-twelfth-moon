class_name VineLadder
extends Area2D
## One climbable cell of ladder: hanging vine in the forest, a wooden ladder
## on the road. Stack them in a map column ("|") to make a ladder; Mariane's
## LadderDetector finds them on the "climbables" layer.
##
## Scene: VineLadder (Area2D, origin at the cell's bottom; layer 128)
##   Sprite2D, CollisionShape2D (the cell)

## Height of one cell, px (the map's tile size).
@export var height: float = 16.0
