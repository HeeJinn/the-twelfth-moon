extends Cutscene
## Mariane thinking out loud when she reaches a spot (a broken bridge, the
## first snow, a strange cave): one short conversation from the chapter's
## script, played once. Her controls are locked only while it's open.
##
## Scene: Thought (Area2D, origin at the ground; layer 64, mask 4)
##   CollisionShape2D  where she has the thought
##   %Camera2D         unused, disabled (the Cutscene base expects one)

@export var dialogue_id: String = ""


func _play() -> void:
	await say(dialogue_id)
